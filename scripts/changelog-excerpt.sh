#!/usr/bin/env bash
#
# Prints the Microsoft Learn changelog entry for one native Clarity SDK version on a
# single line, e.g. "[Enhancement] Enhanced session upload reliability." Prints nothing
# when the entry is not published yet - Microsoft lags Maven Central / clarity.ms by days
# or weeks. Always exits 0: a missing changelog must never block a bump.
#
# Usage: scripts/changelog-excerpt.sh <android|ios> <version>

set -uo pipefail

PLATFORM="${1:?usage: changelog-excerpt.sh <android|ios> <version>}"
VERSION="${2:?usage: changelog-excerpt.sh <android|ios> <version>}"
URL="https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog"

case "$PLATFORM" in
  android) HEADING="Android SDK Changelog" ;;
  ios)     HEADING="iOS SDK Changelog" ;;
  *) echo "ERROR: unknown platform '$PLATFORM' (expected android or ios)" >&2; exit 0 ;;
esac

# Learn serves the page as static HTML, but only to browser-like user agents.
HTML=$(curl -fsSL --retry 3 --retry-delay 2 -A "Mozilla/5.0" "$URL" 2>/dev/null) || exit 0

# Flatten to one text node per line, then walk: platform section -> version block.
# A "[Tag]" line starts an item; every other line is a fragment of the current item
# (Learn splits sentences around inline <code> elements).
printf '%s' "$HTML" \
  | sed -e 's/<[^>]*>/\n/g' \
  | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | grep -v '^$' \
  | awk -v heading="$HEADING" -v ver="$VERSION" '
      function flush() {
        if (item == "") return
        gsub(/  +/, " ", item); sub(/ $/, "", item)
        printf "%s%s", (n++ ? " " : ""), item
        item = ""
      }
      index($0, heading) == 1 { section = 1; next }
      section && /SDK Changelog$/ { section = 0 }
      !section { next }
      index($0, ver " (") == 1 { block = 1; next }
      block && /^[0-9]+\.[0-9]+\.[0-9]+ \(/ { block = 0 }
      !block { next }
      /^\[[A-Za-z ]+\]$/ { flush(); item = $0 " "; next }
      { item = item (item ~ / $/ ? "" : " ") $0 }
      END { flush(); if (n) printf "\n" }
    '
exit 0
