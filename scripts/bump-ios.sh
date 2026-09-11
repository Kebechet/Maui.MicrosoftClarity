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
#   2. Regenerates ApiDefinitions.cs + StructsAndEnums.cs with Objective Sharpie, strips
#      the advisory [Verify(...)] attributes and normalizes the using directives - that
#      last step is the whole reason 3.5.3, 3.5.4 and 4.0.0 never built.
#   3. Compares the framework's own MinimumOSVersion with <SupportedOSPlatformVersion>
#      and raises the csproj when the native library requires more.
#   4. Bumps <Version> (<native>.<binding-rev>) and sets <PackageReleaseNotes> to cover
#      every native release since the binding that is live on nuget.org, one line per
#      version, so releases this bump jumps over are still described somewhere. An
#      unreadable upstream source fails the run rather than guessing - the note cannot be
#      corrected once it is published.
#
# It deliberately does NOT touch the wrapper's <PackageReference>: the wrapper is only
# moved onto a binding that is already live on nuget.org, which is a separate step.
#
# Reading and rewriting files is delegated to scripts/clarity.cs, a .NET file-based app,
# so this stays shell glue and the repo keeps one language (see CLAUDE.md).

set -euo pipefail

NEW_VERSION="${1:?usage: bump-ios.sh <new-version>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="src/Maui.MicrosoftClarity.iOS"
IOS_CSPROJ="$IOS_DIR/Maui.MicrosoftClarity.iOS.csproj"
BINDING_PACKAGE_ID="Kebechet.Maui.MicrosoftClarity.iOS"
FRAMEWORK_ZIP_URL="https://www.clarity.ms/apps/resources/ios/Clarity-${NEW_VERSION}.xcframework.zip"
FRAMEWORK_ZIP="Clarity-${NEW_VERSION}.xcframework.zip"
FRAMEWORK_DIR="Clarity.xcframework"
CHANGELOG_URL="https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog#ios-sdk-changelog"

# Paths passed to clarity are repo-relative, so the subshell can cd to the root regardless
# of where the caller is: the iOS project directory contains a csproj, and `dotnet run`
# from there would try to run that project instead of the script.
clarity() { (cd "$REPO_ROOT" && dotnet run scripts/clarity.cs -- "$@"); }

echo "==> Bumping iOS Clarity SDK to ${NEW_VERSION}"

# --- 1. Current versions from the csproj -----------------------------------------
CURRENT_BINDING_VERSION=$(clarity get-version "$IOS_CSPROJ")
CURRENT_NATIVE="${CURRENT_BINDING_VERSION%.*}"

# Empty only when the package has never been published; any other failure exits non-zero
# and set -e stops here, because falling back to the csproj would quietly reintroduce the
# wrong anchor this lookup exists to replace.
LAST_PUBLISHED_NATIVE=$(clarity last-published-native "$BINDING_PACKAGE_ID")

echo "    current native version:  $CURRENT_NATIVE"
echo "    current binding version: $CURRENT_BINDING_VERSION"
echo "    last published native:   ${LAST_PUBLISHED_NATIVE:-<nothing published yet>}"
echo "    target  native version:  $NEW_VERSION"

if [[ "$CURRENT_NATIVE" == "$NEW_VERSION" ]]; then
  NEW_BINDING_VERSION="${CURRENT_BINDING_VERSION%.*}.$(( ${CURRENT_BINDING_VERSION##*.} + 1 ))"
else
  NEW_BINDING_VERSION="${NEW_VERSION}.0"
fi
echo "    new     binding version: $NEW_BINDING_VERSION"

# --- 2. Download and replace the xcframework -------------------------------------
cd "$REPO_ROOT/$IOS_DIR"
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

# --- 3. Regenerate the binding with Objective Sharpie ---------------------------------
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
  if [[ ! -f "$OUT_DIR/$f" ]]; then
    echo "ERROR: sharpie did not produce $OUT_DIR/$f" >&2
    exit 1
  fi
  mv "$OUT_DIR/$f" "$f"
done
rm -rf "$OUT_DIR"

# [Verify(...)] is advisory and fails the build if left in. Sharpie also emits
# `using Clarity;` - the Swift module name, not a .NET namespace - and omits `using UIKit;`
# although maskView:/unmaskView: take a UIView; that one line failed 3.5.3, 3.5.4 and
# 4.0.0 with CS0246, while 3.5.2 had been fixed by hand.
echo "==> Cleaning up the generated binding sources"
clarity strip-verify "$IOS_DIR/ApiDefinitions.cs"
clarity strip-verify "$IOS_DIR/StructsAndEnums.cs"
clarity normalize-usings "$IOS_DIR/ApiDefinitions.cs"

# --- 4. Minimum iOS version the framework itself requires ------------------------------
PLIST="nativelib/$FRAMEWORK_DIR/ios-arm64/Clarity.framework/Info.plist"
NATIVE_MIN_OS=$(plutil -extract MinimumOSVersion raw -o - "$PLIST" 2>/dev/null || true)
if [[ -z "$NATIVE_MIN_OS" ]]; then
  NATIVE_MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$PLIST" 2>/dev/null || true)
fi
if [[ -z "$NATIVE_MIN_OS" ]]; then
  echo "ERROR: could not read MinimumOSVersion from $IOS_DIR/$PLIST" >&2
  exit 1
fi

cd "$REPO_ROOT"

echo "==> Native framework requires iOS ${NATIVE_MIN_OS}"
MIN_OS_OUTPUT=$(clarity check-min-os "$IOS_CSPROJ" "$NATIVE_MIN_OS")
MIN_OS_RAISED=$(printf '%s\n' "$MIN_OS_OUTPUT" | sed -n -E 's|^min_os_raised=(.*)$|\1|p')
MIN_OS_PREVIOUS=$(printf '%s\n' "$MIN_OS_OUTPUT" | sed -n -E 's|^min_os_previous=(.*)$|\1|p')

# --- 5. Release note -----------------------------------------------------------------
# Anchored to the newest binding on nuget.org, not to the csproj: the two agree only while
# every bump gets published, and a version skipped in between has no package of its own, so
# its upstream notes appear here or nowhere.
#
# No `|| true`: an unreadable source exits non-zero and set -e stops the bump. A note is
# permanent once it reaches nuget.org, so a guess is worse than a failed run.
if [[ -n "$LAST_PUBLISHED_NATIVE" ]]; then
  NOTE_FROM="$LAST_PUBLISHED_NATIVE"
else
  NOTE_FROM="$CURRENT_NATIVE"
fi

if [[ "$NOTE_FROM" == "$NEW_VERSION" ]]; then
  EXCERPT=""
  NOTE="${NEW_BINDING_VERSION}: rebuilt the binding for native Clarity iOS SDK ${NEW_VERSION} (binding revision only, no native change)."
else
  EXCERPT=$(clarity changelog-range ios "$NOTE_FROM" "$NEW_VERSION")
  NOTE="${NEW_BINDING_VERSION}: bumped native Clarity iOS SDK from ${NOTE_FROM} to ${NEW_VERSION}."
fi
if [[ -n "$EXCERPT" ]]; then
  NOTE+=$'\n'"${EXCERPT}"
fi
if [[ "$MIN_OS_RAISED" == "true" ]]; then
  NOTE+=$'\n'"BREAKING: the minimum supported iOS version is now ${NATIVE_MIN_OS} (was ${MIN_OS_PREVIOUS}), as required by the native SDK."
fi
NOTE+=$'\n'"Changelog: ${CHANGELOG_URL}"
echo "    release note:"
printf '%s\n' "$NOTE" | sed 's/^/      /'

# Microsoft marks breaking releases in the note itself, and that claim can be broader than
# anything measurable in the artifact: 4.0.0 announced "minimum supported iOS version 16"
# while the framework and Package.swift both still declared 13.0. A release upstream calls
# breaking is never auto-merged.
#
# This scans the whole range, not just the target. A [Breaking] in a version the bump jumps
# over is still a break the consumer takes.
UPSTREAM_BREAKING=false
if printf '%s' "$EXCERPT" | grep -qi '\[breaking\]'; then
  UPSTREAM_BREAKING=true
  echo "==> upstream marked this release [Breaking]"
fi

# --- 6. Edit the csproj ----------------------------------------------------------------
clarity set-version "$IOS_CSPROJ" "$NEW_BINDING_VERSION"
clarity set-release-note "$IOS_CSPROJ" "$NOTE"

WRITTEN_BINDING=$(clarity get-version "$IOS_CSPROJ")
if [[ "$WRITTEN_BINDING" != "$NEW_BINDING_VERSION" ]]; then
  echo "ERROR: failed to update <Version> (still '${WRITTEN_BINDING}')" >&2
  exit 1
fi
if ! grep -qF "<PackageReleaseNotes>${NOTE}</PackageReleaseNotes>" "$IOS_CSPROJ"; then
  echo "ERROR: failed to write the <PackageReleaseNotes> entry" >&2
  exit 1
fi

echo "==> Done"
echo "    binding version: $NEW_BINDING_VERSION"
echo "    files changed:"
echo "      - $IOS_CSPROJ"
echo "      - $IOS_DIR/ApiDefinitions.cs, $IOS_DIR/StructsAndEnums.cs"
echo "      - $IOS_DIR/nativelib/$FRAMEWORK_DIR"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  # The note and the excerpt are multi-line from here on, and a bare `name=value` carrying
  # newlines makes the runner reject the whole output file - so those two go in heredoc form.
  {
    echo "native_version=${NEW_VERSION}"
    echo "binding_version=${NEW_BINDING_VERSION}"
    echo "previous_native_version=${CURRENT_NATIVE}"
    echo "note_from=${NOTE_FROM}"
    echo "upstream_breaking=${UPSTREAM_BREAKING}"
    echo "changelog_excerpt<<CLARITY_BUMP_EOF"
    printf '%s\n' "$EXCERPT"
    echo "CLARITY_BUMP_EOF"
    echo "release_note<<CLARITY_BUMP_EOF"
    printf '%s\n' "$NOTE"
    echo "CLARITY_BUMP_EOF"
  } >> "$GITHUB_OUTPUT"
fi
