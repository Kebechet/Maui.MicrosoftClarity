#!/usr/bin/env bash
#
# Compares the minimum OS version the native library declares with the binding csproj's
# <SupportedOSPlatformVersion>, and raises the csproj when the library requires more - a
# binding cannot support a lower floor than the library it wraps.
#
# Raising that floor is a breaking change for consumers, so this is reported rather than
# waved through: the workflow opens such a bump as a DRAFT pull request. Nothing here
# touches the wrapper, whose own floor is a separate, human decision.
#
# Usage: scripts/check-min-os.sh <csproj> <native-min-version>
#
# Prints key=value lines (and appends them to GITHUB_OUTPUT when set):
#   min_os_native=16.0
#   min_os_previous=14.2
#   min_os_current=16.0
#   min_os_raised=true|false

set -euo pipefail

CSPROJ="${1:?usage: check-min-os.sh <csproj> <native-min-version>}"
NATIVE_MIN="${2:?usage: check-min-os.sh <csproj> <native-min-version>}"

CURRENT=$(sed -n -E 's|.*<SupportedOSPlatformVersion>([^<]+)</SupportedOSPlatformVersion>.*|\1|p' "$CSPROJ" | head -1)
if [[ -z "$CURRENT" ]]; then
  echo "ERROR: no <SupportedOSPlatformVersion> found in $CSPROJ" >&2
  exit 1
fi

# Dotted numeric comparison, field by field: sort -V is not portable across the BSD and
# GNU userlands these scripts run in.
higher() {
  awk -v a="$1" -v b="$2" '
    BEGIN {
      n = split(a, x, "."); m = split(b, y, ".")
      for (i = 1; i <= (n > m ? n : m); i++) {
        u = (i <= n ? x[i] + 0 : 0); v = (i <= m ? y[i] + 0 : 0)
        if (u > v) { print "yes"; exit }
        if (u < v) { print "no";  exit }
      }
      print "no"
    }'
}

RAISED=false
NEW="$CURRENT"
if [[ "$(higher "$NATIVE_MIN" "$CURRENT")" == "yes" ]]; then
  NEW="$NATIVE_MIN"
  RAISED=true
  NATIVE_MIN="$NATIVE_MIN" perl -pi -e \
    's|<SupportedOSPlatformVersion>[^<]+</SupportedOSPlatformVersion>|<SupportedOSPlatformVersion>$ENV{NATIVE_MIN}</SupportedOSPlatformVersion>|' \
    "$CSPROJ"
  WRITTEN=$(sed -n -E 's|.*<SupportedOSPlatformVersion>([^<]+)</SupportedOSPlatformVersion>.*|\1|p' "$CSPROJ" | head -1)
  if [[ "$WRITTEN" != "$NEW" ]]; then
    echo "ERROR: failed to raise <SupportedOSPlatformVersion> (still '${WRITTEN}')" >&2
    exit 1
  fi
  echo "==> minimum OS raised: ${CURRENT} -> ${NEW} (required by the native library)" >&2
else
  echo "==> minimum OS unchanged: csproj ${CURRENT}, native library ${NATIVE_MIN}" >&2
fi

emit() {
  echo "$1"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "$1" >> "$GITHUB_OUTPUT"; fi
}
emit "min_os_native=${NATIVE_MIN}"
emit "min_os_previous=${CURRENT}"
emit "min_os_current=${NEW}"
emit "min_os_raised=${RAISED}"
