#!/usr/bin/env bash
#
# Bumps the Android Clarity SDK binding to a target Maven Central version.
#
# Usage: scripts/bump-android.sh <new-version>
#   e.g. scripts/bump-android.sh 3.9.0
#
# What it does:
#   1. Downloads clarity-<new>.aar and clarity-<new>-sources.jar from Maven Central.
#   2. Replaces the existing AAR (and sources.jar if present) in src/.../Jars/.
#   3. Bumps the <Version> in the binding csproj — resets binding-revision to .0
#      when the native version actually changes.
#   4. Bumps the <PackageReference> in the wrapper csproj to match.
#
# Designed to run on a Linux/macOS GitHub Actions runner.

set -euo pipefail

NEW_VERSION="${1:?usage: bump-android.sh <new-version>}"
ANDROID_DIR="src/Maui.MicrosoftClarity.Android"
JARS_DIR="$ANDROID_DIR/Jars"
ANDROID_CSPROJ="$ANDROID_DIR/Maui.MicrosoftClarity.Android.csproj"
WRAPPER_CSPROJ="src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj"

MAVEN_BASE="https://repo1.maven.org/maven2/com/microsoft/clarity/clarity/${NEW_VERSION}"
AAR_URL="${MAVEN_BASE}/clarity-${NEW_VERSION}.aar"
SOURCES_URL="${MAVEN_BASE}/clarity-${NEW_VERSION}-sources.jar"

echo "==> Bumping Android Clarity SDK to ${NEW_VERSION}"

# --- 1. Determine current native version from existing AAR filename --------
CURRENT_AAR=$(ls "$JARS_DIR"/clarity-*.aar 2>/dev/null | head -1 || true)
if [[ -z "$CURRENT_AAR" ]]; then
  echo "ERROR: no existing clarity-*.aar found in $JARS_DIR" >&2
  exit 1
fi
CURRENT_NATIVE=$(basename "$CURRENT_AAR" .aar | sed 's/^clarity-//')
echo "    current native version: $CURRENT_NATIVE"
echo "    target  native version: $NEW_VERSION"

# --- 2. Download new artifacts ---------------------------------------------
echo "==> Downloading $AAR_URL"
curl -fsSL "$AAR_URL" -o "$JARS_DIR/clarity-${NEW_VERSION}.aar"

echo "==> Downloading $SOURCES_URL"
if curl -fsSL "$SOURCES_URL" -o "$JARS_DIR/clarity-${NEW_VERSION}-sources.jar"; then
  echo "    sources.jar downloaded"
else
  # Some Clarity releases on Maven don't ship -sources.jar; not fatal.
  echo "    WARN: no -sources.jar published for ${NEW_VERSION}, skipping"
  rm -f "$JARS_DIR/clarity-${NEW_VERSION}-sources.jar"
fi

# --- 3. Remove old artifacts (only if version actually changed) ------------
if [[ "$CURRENT_NATIVE" != "$NEW_VERSION" ]]; then
  echo "==> Removing old clarity-${CURRENT_NATIVE}.* from Jars/"
  rm -f "$JARS_DIR/clarity-${CURRENT_NATIVE}.aar"
  rm -f "$JARS_DIR/clarity-${CURRENT_NATIVE}-sources.jar"
fi

# --- 4. Update <Version> in the binding csproj -----------------------------
# Versioning rule: <native>.<binding-rev>; reset rev to .0 on native bump.
CURRENT_BINDING_VERSION=$(grep -oP '(?<=<Version>)[^<]+(?=</Version>)' "$ANDROID_CSPROJ" | head -1)
echo "    current binding version: $CURRENT_BINDING_VERSION"

if [[ "$CURRENT_NATIVE" == "$NEW_VERSION" ]]; then
  # Same native, increment last segment.
  REV=$(echo "$CURRENT_BINDING_VERSION" | awk -F. '{print $NF + 1}')
  PREFIX=$(echo "$CURRENT_BINDING_VERSION" | awk -F. 'BEGIN{OFS="."} {NF--; print}')
  NEW_BINDING_VERSION="${PREFIX}.${REV}"
else
  NEW_BINDING_VERSION="${NEW_VERSION}.0"
fi
echo "    new     binding version: $NEW_BINDING_VERSION"

sed -i.bak -E "s|<Version>[^<]+</Version>|<Version>${NEW_BINDING_VERSION}</Version>|" "$ANDROID_CSPROJ"
rm -f "${ANDROID_CSPROJ}.bak"

# --- 5. Update wrapper csproj to reference new binding version -------------
sed -i.bak -E \
  "s|(<PackageReference Include=\"Kebechet\.Maui\.MicrosoftClarity\.Android\" Version=\")[^\"]+(\")|\1${NEW_BINDING_VERSION}\2|" \
  "$WRAPPER_CSPROJ"
rm -f "${WRAPPER_CSPROJ}.bak"

echo "==> Done"
echo "    binding version: $NEW_BINDING_VERSION"
echo "    files changed:"
echo "      - $JARS_DIR/clarity-${NEW_VERSION}.aar"
echo "      - $ANDROID_CSPROJ"
echo "      - $WRAPPER_CSPROJ"

# Emit version for use by GitHub Actions.
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "native_version=${NEW_VERSION}"
    echo "binding_version=${NEW_BINDING_VERSION}"
    echo "previous_native_version=${CURRENT_NATIVE}"
  } >> "$GITHUB_OUTPUT"
fi
