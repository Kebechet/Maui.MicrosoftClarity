#!/usr/bin/env bash
#
# Bumps the iOS Clarity SDK binding to a target version.
#
# Usage: scripts/bump-ios.sh <new-version>
#   e.g. scripts/bump-ios.sh 3.5.0
#
# Prerequisites: must run on macOS with Objective Sharpie installed
# (matches the existing generate-ios-bindings.yml setup).
#
# What it does:
#   1. Downloads Clarity-<new>.xcframework.zip and extracts it into the iOS project.
#   2. Strips .swiftmodule and .dSYM directories (avoids NU5123 + Windows long-path warnings).
#   3. Runs Objective Sharpie to regenerate ApiDefinitions.cs + StructsAndEnums.cs.
#   4. Strips [Verify(...)] attributes — they're advisory and break the build if left in.
#   5. Bumps <Version> in the binding csproj and the wrapper's <PackageReference>.

set -euo pipefail

NEW_VERSION="${1:?usage: bump-ios.sh <new-version>}"
IOS_DIR="src/Maui.MicrosoftClarity.iOS"
IOS_CSPROJ="$IOS_DIR/Maui.MicrosoftClarity.iOS.csproj"
WRAPPER_CSPROJ="src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj"

FRAMEWORK_ZIP_URL="https://www.clarity.ms/apps/resources/ios/Clarity-${NEW_VERSION}.xcframework.zip"
FRAMEWORK_ZIP="Clarity-${NEW_VERSION}.xcframework.zip"
FRAMEWORK_DIR="Clarity.xcframework"

echo "==> Bumping iOS Clarity SDK to ${NEW_VERSION}"

# --- 1. Detect current native version from existing csproj <Version> -------
CURRENT_BINDING_VERSION=$(sed -n -E 's|.*<Version>([^<]+)</Version>.*|\1|p' "$IOS_CSPROJ" | head -1)
CURRENT_NATIVE=$(echo "$CURRENT_BINDING_VERSION" | awk -F. 'BEGIN{OFS="."} {NF--; print}')
echo "    current native version: $CURRENT_NATIVE"
echo "    target  native version: $NEW_VERSION"

# --- 2. Download xcframework ----------------------------------------------
cd "$IOS_DIR"
echo "==> Downloading $FRAMEWORK_ZIP_URL"
rm -f "$FRAMEWORK_ZIP"
HTTP_CODE=$(curl -L -w "%{http_code}" -o "$FRAMEWORK_ZIP" "$FRAMEWORK_ZIP_URL")
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: HTTP $HTTP_CODE — Clarity-${NEW_VERSION}.xcframework.zip not found at clarity.ms" >&2
  exit 1
fi
unzip -t "$FRAMEWORK_ZIP" > /dev/null

# --- 3. Replace xcframework -----------------------------------------------
rm -rf "nativelib/$FRAMEWORK_DIR"
mkdir -p nativelib
unzip -q "$FRAMEWORK_ZIP" -d nativelib/
rm -f "$FRAMEWORK_ZIP"

echo "==> Stripping .swiftmodule and .dSYM directories"
find "nativelib/$FRAMEWORK_DIR" -type d -name "*.swiftmodule" -exec rm -rf {} + 2>/dev/null || true
find "nativelib/$FRAMEWORK_DIR" -type d -name "*.dSYM"        -exec rm -rf {} + 2>/dev/null || true

# --- 4. Regenerate bindings with Objective Sharpie -------------------------
IOS_SDK=$(sharpie xcode -sdks 2>&1 | grep -i iphoneos | grep -o 'iphoneos[0-9.]*' | tail -1)
if [[ -z "$IOS_SDK" ]]; then
  echo "ERROR: could not detect installed iphoneos SDK" >&2
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

# --- 5. Strip [Verify(...)] attributes and copy generated files into project
# Per the iOS README, Verify attrs are advisory and must be removed before build.
for f in ApiDefinitions.cs StructsAndEnums.cs; do
  src="$OUT_DIR/$f"
  if [[ ! -f "$src" ]]; then
    echo "ERROR: sharpie did not produce $src" >&2
    exit 1
  fi
  sed -i.bak -E '/^\[Verify\(.+\)\]$/d; s/\[Verify\([^)]+\)\] *//g' "$src"
  rm -f "${src}.bak"
  mv "$src" "$f"
done
rm -rf "$OUT_DIR"

cd - > /dev/null

# --- 6. Update <Version> in the binding csproj -----------------------------
if [[ "$CURRENT_NATIVE" == "$NEW_VERSION" ]]; then
  REV=$(echo "$CURRENT_BINDING_VERSION" | awk -F. '{print $NF + 1}')
  PREFIX=$(echo "$CURRENT_BINDING_VERSION" | awk -F. 'BEGIN{OFS="."} {NF--; print}')
  NEW_BINDING_VERSION="${PREFIX}.${REV}"
else
  NEW_BINDING_VERSION="${NEW_VERSION}.0"
fi
echo "    new binding version: $NEW_BINDING_VERSION"

sed -i.bak -E "s|<Version>[^<]+</Version>|<Version>${NEW_BINDING_VERSION}</Version>|" "$IOS_CSPROJ"
rm -f "${IOS_CSPROJ}.bak"

# --- 7. Update wrapper csproj reference -----------------------------------
sed -i.bak -E \
  "s|(<PackageReference Include=\"Kebechet\.Maui\.MicrosoftClarity\.iOS\" Version=\")[^\"]+(\")|\1${NEW_BINDING_VERSION}\2|" \
  "$WRAPPER_CSPROJ"
rm -f "${WRAPPER_CSPROJ}.bak"

echo "==> Done"
echo "    binding version: $NEW_BINDING_VERSION"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "native_version=${NEW_VERSION}"
    echo "binding_version=${NEW_BINDING_VERSION}"
    echo "previous_native_version=${CURRENT_NATIVE}"
  } >> "$GITHUB_OUTPUT"
fi
