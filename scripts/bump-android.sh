#!/usr/bin/env bash
#
# Bumps the Android Clarity SDK binding to a target Maven Central version.
#
# Usage: scripts/bump-android.sh <new-version>
#   e.g. scripts/bump-android.sh 3.9.0
#
# What it does:
#   1. Verifies the requested version exists on Maven Central.
#   2. Bumps the <AndroidMavenLibrary> version in the binding csproj — the .NET
#      Android SDK downloads that AAR (and its POM) at build time; nothing is
#      committed to the repo.
#   3. Bumps the <Version> in the binding csproj — resets binding-revision to .0
#      when the native version actually changes.
#   4. Bumps the <PackageReference> in the wrapper csproj to match.
#
# Designed to run on a Linux/macOS GitHub Actions runner.

set -euo pipefail

NEW_VERSION="${1:?usage: bump-android.sh <new-version>}"
ANDROID_DIR="src/Maui.MicrosoftClarity.Android"
ANDROID_CSPROJ="$ANDROID_DIR/Maui.MicrosoftClarity.Android.csproj"
WRAPPER_CSPROJ="src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj"

MAVEN_BASE="https://repo1.maven.org/maven2/com/microsoft/clarity/clarity/${NEW_VERSION}"
POM_URL="${MAVEN_BASE}/clarity-${NEW_VERSION}.pom"

echo "==> Bumping Android Clarity SDK to ${NEW_VERSION}"

# --- 1. Determine current native version from the csproj -------------------
CURRENT_NATIVE=$(sed -n -E \
  's|.*<AndroidMavenLibrary +Include="com\.microsoft\.clarity:clarity" +Version="([^"]+)".*|\1|p' \
  "$ANDROID_CSPROJ" | head -1)
if [[ -z "$CURRENT_NATIVE" ]]; then
  echo "ERROR: no <AndroidMavenLibrary Include=\"com.microsoft.clarity:clarity\" .../> found in $ANDROID_CSPROJ" >&2
  exit 1
fi
echo "    current native version: $CURRENT_NATIVE"
echo "    target  native version: $NEW_VERSION"

# --- 2. Confirm the target exists on Maven Central --------------------------
# The AAR is only fetched at build time, so a typo here would otherwise surface
# as an opaque XA4234 much later in the pipeline.
echo "==> Verifying $POM_URL"
# --retry (without --retry-all-errors) covers timeouts/429/5xx but not the 404 we are
# actually testing for, so a missing version still fails on the first attempt.
if ! curl -fsSL --retry 3 --retry-delay 2 -o /dev/null "$POM_URL"; then
  echo "ERROR: com.microsoft.clarity:clarity:${NEW_VERSION} not found on Maven Central" >&2
  exit 1
fi

# --- 3. Point AndroidMavenLibrary at the new version ------------------------
sed -i.bak -E \
  "s|(<AndroidMavenLibrary +Include=\"com\.microsoft\.clarity:clarity\" +Version=\")[^\"]+(\")|\1${NEW_VERSION}\2|" \
  "$ANDROID_CSPROJ"
rm -f "${ANDROID_CSPROJ}.bak"

# Read the pin back. If this write ever silently misses while the read in step 1
# still matches, the steps below would bump the NuGet version and the wrapper
# reference while leaving the native pin behind — i.e. ship "3.9.0.0" containing
# Clarity 3.8.2.
WRITTEN_NATIVE=$(sed -n -E \
  's|.*<AndroidMavenLibrary +Include="com\.microsoft\.clarity:clarity" +Version="([^"]+)".*|\1|p' \
  "$ANDROID_CSPROJ" | head -1)
if [[ "$WRITTEN_NATIVE" != "$NEW_VERSION" ]]; then
  echo "ERROR: failed to update the <AndroidMavenLibrary> pin (still '${WRITTEN_NATIVE}')" >&2
  exit 1
fi

# --- 4. Update <Version> in the binding csproj ------------------------------
# Versioning rule: <native>.<binding-rev>; reset rev to .0 on native bump.
CURRENT_BINDING_VERSION=$(sed -n -E 's|.*<Version>([^<]+)</Version>.*|\1|p' "$ANDROID_CSPROJ" | head -1)
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
