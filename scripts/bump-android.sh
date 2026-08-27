#!/usr/bin/env bash
#
# Bumps the Android Clarity SDK binding to a target Maven Central version.
#
# Usage: scripts/bump-android.sh <new-version>
#   e.g. scripts/bump-android.sh 3.9.0
#
# What it does:
#   1. Verifies the requested version exists on Maven Central.
#   2. Points <AndroidMavenLibrary> at it - the .NET Android SDK downloads that AAR (and
#      its POM) when the binding is built; nothing is committed to the repo.
#   3. Bumps <Version> (<native>.<binding-rev>: the revision resets to .0 when the native
#      version changes and increments otherwise).
#   4. Sets <PackageReleaseNotes> to a single entry for the version being published,
#      with Microsoft's changelog text for the native version when it is published.
#
# It deliberately does NOT touch the wrapper's <PackageReference>: the wrapper is only
# moved onto a binding that is already live on nuget.org, which is a separate step.
#
# In-place edits go through perl: Git Bash's sed -i strips CRLF line endings, so a local
# run on Windows would otherwise rewrite every line of the csproj. Runs on ubuntu, macOS
# and Windows Git Bash.

set -euo pipefail

NEW_VERSION="${1:?usage: bump-android.sh <new-version>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_CSPROJ="src/Maui.MicrosoftClarity.Android/Maui.MicrosoftClarity.Android.csproj"
POM_URL="https://repo1.maven.org/maven2/com/microsoft/clarity/clarity/${NEW_VERSION}/clarity-${NEW_VERSION}.pom"
CHANGELOG_URL="https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog#android-sdk-changelog"

echo "==> Bumping Android Clarity SDK to ${NEW_VERSION}"

# --- 1. Current versions from the csproj -----------------------------------------
CURRENT_NATIVE=$(sed -n -E \
  's|.*<AndroidMavenLibrary +Include="com\.microsoft\.clarity:clarity" +Version="([^"]+)".*|\1|p' \
  "$ANDROID_CSPROJ" | head -1)
if [[ -z "$CURRENT_NATIVE" ]]; then
  echo "ERROR: no <AndroidMavenLibrary Include=\"com.microsoft.clarity:clarity\" .../> found in $ANDROID_CSPROJ" >&2
  exit 1
fi
CURRENT_BINDING_VERSION=$(sed -n -E 's|.*<Version>([^<]+)</Version>.*|\1|p' "$ANDROID_CSPROJ" | head -1)
if [[ -z "$CURRENT_BINDING_VERSION" ]]; then
  echo "ERROR: no <Version> found in $ANDROID_CSPROJ" >&2
  exit 1
fi
echo "    current native version:  $CURRENT_NATIVE"
echo "    current binding version: $CURRENT_BINDING_VERSION"
echo "    target  native version:  $NEW_VERSION"

# --- 2. The target must exist on Maven Central -----------------------------------
# The AAR is only fetched at build time, so a typo here would otherwise surface as an
# opaque XA4234 much later. --retry (without --retry-all-errors) covers timeouts and
# 5xx but not the 404 we are actually testing for.
echo "==> Verifying $POM_URL"
if ! curl -fsSL --retry 3 --retry-delay 2 -o /dev/null "$POM_URL"; then
  echo "ERROR: com.microsoft.clarity:clarity:${NEW_VERSION} not found on Maven Central" >&2
  exit 1
fi

# --- 3. New binding version --------------------------------------------------------
if [[ "$CURRENT_NATIVE" == "$NEW_VERSION" ]]; then
  REV=$(echo "$CURRENT_BINDING_VERSION" | awk -F. '{print $NF + 1}')
  PREFIX=$(echo "$CURRENT_BINDING_VERSION" | awk -F. 'BEGIN{OFS="."} {NF--; print}')
  NEW_BINDING_VERSION="${PREFIX}.${REV}"
else
  NEW_BINDING_VERSION="${NEW_VERSION}.0"
fi
echo "    new     binding version: $NEW_BINDING_VERSION"

# --- 4. Minimum Android API the AAR itself requires ------------------------------------
# An AAR's manifest is plain XML, so this needs no aapt. A native SDK that raises its
# minSdk while the binding still claims a lower one compiles and packs cleanly and only
# breaks at deployment.
AAR_URL="https://repo1.maven.org/maven2/com/microsoft/clarity/clarity/${NEW_VERSION}/clarity-${NEW_VERSION}.aar"
AAR_TMP="$(mktemp -d)"
trap 'rm -rf "$AAR_TMP"' EXIT
if ! curl -fsSL --retry 3 --retry-delay 2 -o "$AAR_TMP/clarity.aar" "$AAR_URL"; then
  echo "ERROR: could not download $AAR_URL to read its minSdkVersion" >&2
  exit 1
fi
NATIVE_MIN_OS=$(unzip -p "$AAR_TMP/clarity.aar" AndroidManifest.xml 2>/dev/null \
  | sed -n -E 's|.*android:minSdkVersion="([^"]+)".*|\1|p' | head -1)
if [[ -z "$NATIVE_MIN_OS" ]]; then
  echo "ERROR: could not read android:minSdkVersion from the AAR manifest" >&2
  exit 1
fi

echo "==> Native AAR requires API ${NATIVE_MIN_OS}"
MIN_OS_OUTPUT=$("$SCRIPT_DIR/check-min-os.sh" "$ANDROID_CSPROJ" "$NATIVE_MIN_OS")
MIN_OS_RAISED=$(printf '%s\n' "$MIN_OS_OUTPUT" | sed -n -E 's|^min_os_raised=(.*)$|\1|p')
MIN_OS_PREVIOUS=$(printf '%s\n' "$MIN_OS_OUTPUT" | sed -n -E 's|^min_os_previous=(.*)$|\1|p')

# --- 5. Release note -----------------------------------------------------------------
EXCERPT=$("$SCRIPT_DIR/changelog-excerpt.sh" android "$NEW_VERSION" || true)
if [[ "$CURRENT_NATIVE" == "$NEW_VERSION" ]]; then
  NOTE="${NEW_BINDING_VERSION}: rebuilt the binding for native Clarity Android SDK ${NEW_VERSION} (binding revision only, no native change)."
else
  NOTE="${NEW_BINDING_VERSION}: bumped native Clarity Android SDK from ${CURRENT_NATIVE} to ${NEW_VERSION}."
fi
if [[ -n "$EXCERPT" ]]; then
  NOTE+=" Upstream: ${EXCERPT}"
fi
if [[ "$MIN_OS_RAISED" == "true" ]]; then
  NOTE+=" BREAKING: the minimum supported Android API level is now ${NATIVE_MIN_OS} (was ${MIN_OS_PREVIOUS}), as required by the native SDK."
fi
NOTE+=" Changelog: ${CHANGELOG_URL}"
echo "    release note: $NOTE"

# --- 6. Edit the csproj ----------------------------------------------------------------
NEW_VERSION="$NEW_VERSION" perl -pi -e \
  's|(<AndroidMavenLibrary\s+Include="com\.microsoft\.clarity:clarity"\s+Version=")[^"]+(")|$1$ENV{NEW_VERSION}$2|' \
  "$ANDROID_CSPROJ"
NEW_BINDING_VERSION="$NEW_BINDING_VERSION" perl -pi -e \
  's|<Version>[^<]+</Version>|<Version>$ENV{NEW_BINDING_VERSION}</Version>|' \
  "$ANDROID_CSPROJ"
# Only the version being published: the notes are not a changelog of past releases.
perl "$SCRIPT_DIR/set-release-note.pl" "$ANDROID_CSPROJ" "$NOTE"

# --- 7. Read everything back: a silently missed edit would ship "3.9.0.0" containing
#        Clarity 3.8.2, which is worse than failing here. ------------------------------
WRITTEN_NATIVE=$(sed -n -E \
  's|.*<AndroidMavenLibrary +Include="com\.microsoft\.clarity:clarity" +Version="([^"]+)".*|\1|p' \
  "$ANDROID_CSPROJ" | head -1)
if [[ "$WRITTEN_NATIVE" != "$NEW_VERSION" ]]; then
  echo "ERROR: failed to update the <AndroidMavenLibrary> pin (still '${WRITTEN_NATIVE}')" >&2
  exit 1
fi
WRITTEN_BINDING=$(sed -n -E 's|.*<Version>([^<]+)</Version>.*|\1|p' "$ANDROID_CSPROJ" | head -1)
if [[ "$WRITTEN_BINDING" != "$NEW_BINDING_VERSION" ]]; then
  echo "ERROR: failed to update <Version> (still '${WRITTEN_BINDING}')" >&2
  exit 1
fi
if ! grep -qF "<PackageReleaseNotes>${NOTE}</PackageReleaseNotes>" "$ANDROID_CSPROJ"; then
  echo "ERROR: failed to write the <PackageReleaseNotes> entry" >&2
  exit 1
fi

echo "==> Done"
echo "    binding version: $NEW_BINDING_VERSION"
echo "    files changed:"
echo "      - $ANDROID_CSPROJ"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "native_version=${NEW_VERSION}"
    echo "binding_version=${NEW_BINDING_VERSION}"
    echo "previous_native_version=${CURRENT_NATIVE}"
    echo "changelog_excerpt=${EXCERPT}"
    echo "release_note=${NOTE}"
  } >> "$GITHUB_OUTPUT"
fi
