#!/usr/bin/env bash
#
# Bumps the iOS Clarity SDK binding to a target version.
#
# Usage: scripts/bump-ios.sh <new-version>
#   e.g. scripts/bump-ios.sh 4.0.0
#
# Prerequisites: macOS with Xcode and Objective Sharpie installed.
#
# What it does:
#   1. Downloads Clarity-<new>.xcframework.zip from clarity.ms and replaces the committed
#      xcframework (minus .swiftmodule and .dSYM directories: NU5123 + package size).
#   2. Regenerates ApiDefinitions.cs + StructsAndEnums.cs with Objective Sharpie.
#   3. Strips the advisory [Verify(...)] attributes and normalizes the using directives
#      (see step 4 below - this is the whole reason 3.5.3, 3.5.4 and 4.0.0 never built).
#   4. Bumps <Version> (<native>.<binding-rev>) and prepends a <PackageReleaseNotes>
#      entry with Microsoft's changelog text for the native version when it is published.
#
# It deliberately does NOT touch the wrapper's <PackageReference>: the wrapper is only
# moved onto a binding that is already live on nuget.org, which is a separate step.
#
# In-place edits go through perl so the script behaves identically on macOS (BSD sed)
# and in Git Bash (whose sed -i strips CRLF line endings).

set -euo pipefail

NEW_VERSION="${1:?usage: bump-ios.sh <new-version>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="src/Maui.MicrosoftClarity.iOS"
IOS_CSPROJ="$IOS_DIR/Maui.MicrosoftClarity.iOS.csproj"
FRAMEWORK_ZIP_URL="https://www.clarity.ms/apps/resources/ios/Clarity-${NEW_VERSION}.xcframework.zip"
FRAMEWORK_ZIP="Clarity-${NEW_VERSION}.xcframework.zip"
FRAMEWORK_DIR="Clarity.xcframework"
CHANGELOG_URL="https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog#ios-sdk-changelog"

echo "==> Bumping iOS Clarity SDK to ${NEW_VERSION}"

# --- 1. Current versions from the csproj -----------------------------------------
CURRENT_BINDING_VERSION=$(sed -n -E 's|.*<Version>([^<]+)</Version>.*|\1|p' "$IOS_CSPROJ" | head -1)
if [[ -z "$CURRENT_BINDING_VERSION" ]]; then
  echo "ERROR: no <Version> found in $IOS_CSPROJ" >&2
  exit 1
fi
CURRENT_NATIVE=$(echo "$CURRENT_BINDING_VERSION" | awk -F. 'BEGIN{OFS="."} NF>1 {NF--; print}')
echo "    current native version:  $CURRENT_NATIVE"
echo "    current binding version: $CURRENT_BINDING_VERSION"
echo "    target  native version:  $NEW_VERSION"

if [[ "$CURRENT_NATIVE" == "$NEW_VERSION" ]]; then
  REV=$(echo "$CURRENT_BINDING_VERSION" | awk -F. '{print $NF + 1}')
  PREFIX=$(echo "$CURRENT_BINDING_VERSION" | awk -F. 'BEGIN{OFS="."} {NF--; print}')
  NEW_BINDING_VERSION="${PREFIX}.${REV}"
else
  NEW_BINDING_VERSION="${NEW_VERSION}.0"
fi
echo "    new     binding version: $NEW_BINDING_VERSION"

# --- 2. Release note (before cd; the excerpt script is a sibling) -----------------
EXCERPT=$("$SCRIPT_DIR/changelog-excerpt.sh" ios "$NEW_VERSION" || true)
if [[ "$CURRENT_NATIVE" == "$NEW_VERSION" ]]; then
  NOTE="${NEW_BINDING_VERSION}: rebuilt the binding for native Clarity iOS SDK ${NEW_VERSION} (binding revision only, no native change)."
else
  NOTE="${NEW_BINDING_VERSION}: bumped native Clarity iOS SDK from ${CURRENT_NATIVE} to ${NEW_VERSION}."
fi
if [[ -n "$EXCERPT" ]]; then
  NOTE+=" Upstream: ${EXCERPT}"
fi
NOTE+=" Changelog: ${CHANGELOG_URL}"
echo "    release note: $NOTE"

# --- 3. Download and replace the xcframework -------------------------------------
cd "$IOS_DIR"
echo "==> Downloading $FRAMEWORK_ZIP_URL"
rm -f "$FRAMEWORK_ZIP"
HTTP_CODE=$(curl -sSL --retry 3 --retry-delay 2 -w "%{http_code}" -o "$FRAMEWORK_ZIP" "$FRAMEWORK_ZIP_URL")
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: HTTP $HTTP_CODE - Clarity-${NEW_VERSION}.xcframework.zip not found at clarity.ms" >&2
  rm -f "$FRAMEWORK_ZIP"
  exit 1
fi
unzip -tq "$FRAMEWORK_ZIP" > /dev/null

rm -rf "nativelib/$FRAMEWORK_DIR"
mkdir -p nativelib
unzip -q "$FRAMEWORK_ZIP" -d nativelib/
rm -f "$FRAMEWORK_ZIP"
if [[ ! -d "nativelib/$FRAMEWORK_DIR" ]]; then
  echo "ERROR: the zip did not contain $FRAMEWORK_DIR at its root" >&2
  exit 1
fi

echo "==> Stripping .swiftmodule and .dSYM directories"
find "nativelib/$FRAMEWORK_DIR" -type d -name "*.swiftmodule" -prune -exec rm -rf {} +
find "nativelib/$FRAMEWORK_DIR" -type d -name "*.dSYM"        -prune -exec rm -rf {} +

# --- 4. Regenerate the binding with Objective Sharpie ---------------------------------
IOS_SDK=$(sharpie xcode -sdks 2>&1 | grep -i iphoneos | grep -o 'iphoneos[0-9.]*' | tail -1)
if [[ -z "$IOS_SDK" ]]; then
  echo "ERROR: could not detect an installed iphoneos SDK via 'sharpie xcode -sdks'" >&2
  exit 1
fi
echo "==> Running sharpie bind against $IOS_SDK"

OUT_DIR="ClarityBindingOutput"
HEADERS="nativelib/$FRAMEWORK_DIR/ios-arm64/Clarity.framework/Headers"
rm -rf "$OUT_DIR"
sharpie bind \
  --sdk="$IOS_SDK" \
  --output="$OUT_DIR" \
  --namespace="MicrosoftClarityiOS" \
  --scope="$HEADERS" \
  "$HEADERS/Clarity-Swift.h"

for f in ApiDefinitions.cs StructsAndEnums.cs; do
  src="$OUT_DIR/$f"
  if [[ ! -f "$src" ]]; then
    echo "ERROR: sharpie did not produce $src" >&2
    exit 1
  fi
  # [Verify(...)] attributes are advisory and fail the build if left in. Sharpie emits
  # them on their own line, indented, and inline next to other attributes.
  perl -ni -e 'print unless /^\s*\[Verify\s*\(.+\)\]\s*$/' "$src"
  perl -pi -e 's/\[Verify\s*\([^)]+\)\]\s*//g' "$src"
  mv "$src" "$f"
done
rm -rf "$OUT_DIR"

# Sharpie emits `using Clarity;` - the Swift module name, not a .NET namespace - and
# omits `using UIKit;` although maskView:/unmaskView: take a UIView. That one line is
# what failed the 3.5.3, 3.5.4 and 4.0.0 bumps with CS0246; 3.5.2 was fixed by hand.
echo "==> Normalizing using directives in ApiDefinitions.cs"
perl -ni -e 'print unless /^using Clarity;\s*$/' ApiDefinitions.cs
if ! grep -q '^using UIKit;' ApiDefinitions.cs; then
  if grep -q '^using ObjCRuntime;' ApiDefinitions.cs; then
    perl -pi -e 's/^using ObjCRuntime;$/using ObjCRuntime;\nusing UIKit;/' ApiDefinitions.cs
  elif grep -q '^using Foundation;' ApiDefinitions.cs; then
    perl -pi -e 's/^using Foundation;$/using Foundation;\nusing UIKit;/' ApiDefinitions.cs
  else
    perl -pi -e 'print "using UIKit;\n" if $. == 1' ApiDefinitions.cs
  fi
fi
if grep -q '^using Clarity;' ApiDefinitions.cs || ! grep -q '^using UIKit;' ApiDefinitions.cs; then
  echo "ERROR: using-directive normalization failed" >&2
  exit 1
fi

cd - > /dev/null

# --- 5. Edit the csproj ----------------------------------------------------------------
NEW_BINDING_VERSION="$NEW_BINDING_VERSION" perl -pi -e \
  's|<Version>[^<]+</Version>|<Version>$ENV{NEW_BINDING_VERSION}</Version>|' \
  "$IOS_CSPROJ"
# One entry per line, newest first; earlier entries stay (nuget.org shows the history).
perl "$SCRIPT_DIR/prepend-release-note.pl" "$IOS_CSPROJ" "$NOTE"

WRITTEN_BINDING=$(sed -n -E 's|.*<Version>([^<]+)</Version>.*|\1|p' "$IOS_CSPROJ" | head -1)
if [[ "$WRITTEN_BINDING" != "$NEW_BINDING_VERSION" ]]; then
  echo "ERROR: failed to update <Version> (still '${WRITTEN_BINDING}')" >&2
  exit 1
fi
if ! grep -qE "^${NEW_BINDING_VERSION//./\\.}: " "$IOS_CSPROJ"; then
  echo "ERROR: failed to prepend the <PackageReleaseNotes> entry" >&2
  exit 1
fi

echo "==> Done"
echo "    binding version: $NEW_BINDING_VERSION"
echo "    files changed:"
echo "      - $IOS_CSPROJ"
echo "      - $IOS_DIR/ApiDefinitions.cs, $IOS_DIR/StructsAndEnums.cs"
echo "      - $IOS_DIR/nativelib/$FRAMEWORK_DIR"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "native_version=${NEW_VERSION}"
    echo "binding_version=${NEW_BINDING_VERSION}"
    echo "previous_native_version=${CURRENT_NATIVE}"
    echo "changelog_excerpt=${EXCERPT}"
    echo "release_note=${NOTE}"
  } >> "$GITHUB_OUTPUT"
fi
