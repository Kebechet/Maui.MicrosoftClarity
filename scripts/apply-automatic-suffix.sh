#!/usr/bin/env bash
#
# Appends the `-automatic` prerelease suffix to a binding's <Version> and to
# the wrapper csproj's <PackageReference> for that binding.
#
# Idempotent: running it twice leaves a single `-automatic` suffix.
#
# Usage: scripts/apply-automatic-suffix.sh <android|ios>
#
# Why a prerelease suffix?
#   NuGet treats `X.Y.Z-suffix` as prerelease, so consumers searching for
#   "latest stable" don't pick it up by default. They have to opt in via
#   `--prerelease`. This is the right semantic for "the automation shipped
#   this without a human reviewing the API surface."
#
# When this is called from automatic-bump-and-wire.yml:
#   - api-diff detected new APIs (additions > 0)  → apply -automatic
#   - wrapper failed to compile against new binding → apply -automatic
# In both cases @copilot is also pinged to do the wiring; the suffix stays
# until a human strips it as a "promotion to stable" step at merge time.

set -euo pipefail

PLATFORM="${1:?usage: apply-automatic-suffix.sh <android|ios>}"

case "$PLATFORM" in
  android)
    CSPROJ="src/Maui.MicrosoftClarity.Android/Maui.MicrosoftClarity.Android.csproj"
    PKG_ID="Kebechet.Maui.MicrosoftClarity.Android"
    ;;
  ios)
    CSPROJ="src/Maui.MicrosoftClarity.iOS/Maui.MicrosoftClarity.iOS.csproj"
    PKG_ID="Kebechet.Maui.MicrosoftClarity.iOS"
    ;;
  *)
    echo "ERROR: unknown platform '$PLATFORM' (expected 'android' or 'ios')" >&2
    exit 2
    ;;
esac

WRAPPER="src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj"

CURRENT=$(sed -n -E 's|.*<Version>([^<]+)</Version>.*|\1|p' "$CSPROJ" | head -1)
echo "==> Current binding version: $CURRENT"

if [[ "$CURRENT" == *-automatic ]]; then
  echo "    already suffixed, nothing to do"
  exit 0
fi

NEW="${CURRENT}-automatic"
echo "==> Applying -automatic suffix → $NEW"

# Escape dots in package id for sed.
PKG_RE="${PKG_ID//./\\.}"

sed -i.bak -E "s|<Version>${CURRENT//./\\.}</Version>|<Version>${NEW}</Version>|" "$CSPROJ"
rm -f "${CSPROJ}.bak"

sed -i.bak -E \
  "s|(<PackageReference Include=\"${PKG_RE}\" Version=\")${CURRENT//./\\.}(\")|\1${NEW}\2|" \
  "$WRAPPER"
rm -f "${WRAPPER}.bak"

echo "==> Done"
