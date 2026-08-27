#!/usr/bin/env bash
#
# Prints Microsoft's changelog entry for one native Clarity SDK version on a single line,
# e.g. "[Enhancement] Enhanced session upload reliability." Prints nothing when no entry
# is published yet. Always exits 0: a missing changelog must never block a bump.
#
# Usage: scripts/changelog-excerpt.sh <android|ios> <version>
#
# Sources, in order of preference:
#   ios      microsoft/clarity-apps GitHub releases, then Microsoft Learn. The releases
#            carry per-version notes the moment the SDK ships, while Learn lags by days
#            or weeks - iOS 4.0.0 had release notes on GitHub while Learn still stopped
#            at 3.5.4.
#   android  Microsoft Learn only. The clarity-apps releases are iOS-only (all 51 of
#            them), Maven Central carries no notes, and neither does the AAR.
#
# Set GH_TOKEN (or GITHUB_TOKEN) to authenticate the GitHub call; unauthenticated it
# shares the runner's 60-requests-per-hour IP budget.

set -uo pipefail

PLATFORM="${1:?usage: changelog-excerpt.sh <android|ios> <version>}"
VERSION="${2:?usage: changelog-excerpt.sh <android|ios> <version>}"
LEARN_URL="https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog"
RELEASES_URL="https://api.github.com/repos/microsoft/clarity-apps/releases?per_page=100"

case "$PLATFORM" in
  android) HEADING="Android SDK Changelog" ;;
  ios)     HEADING="iOS SDK Changelog" ;;
  *) echo "ERROR: unknown platform '$PLATFORM' (expected android or ios)" >&2; exit 0 ;;
esac

# XML-safe and single-line: the result is written into <PackageReleaseNotes>, and
# set-release-note.pl refuses markup rather than corrupting the csproj.
sanitize() {
  tr '\r\n' '  ' | sed -e 's/&/and/g' -e 's/[<>]//g' -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//'
}

# Not `command -v python3`: on Windows that finds the Microsoft Store stub, which prints
# an installation notice to stdout and would end up quoted as the changelog entry.
find_python() {
  local candidate
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys' >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

from_github_releases() {
  local python auth=() body
  python=$(find_python) || return 1
  if [[ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
    auth=(-H "Authorization: Bearer ${GH_TOKEN:-$GITHUB_TOKEN}")
  fi
  body=$(curl -fsSL --retry 3 --retry-delay 2 \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${auth[@]+"${auth[@]}"}" "$RELEASES_URL" 2>/dev/null) || return 1

  printf '%s' "$body" | VERSION="$VERSION" "$python" -c '
import json, os, re, sys

version = os.environ["VERSION"]
try:
    releases = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not isinstance(releases, list):
    sys.exit(1)

for release in releases:
    tag = (release.get("tag_name") or "").lstrip("v")
    name = release.get("name") or ""
    if tag != version and f"v{version}" not in name:
        continue
    items = []
    for line in (release.get("body") or "").splitlines():
        line = line.strip()
        if not line.startswith(("- ", "* ")):
            continue
        line = line[2:].replace("**", "").strip()
        if line.lower().startswith("full changelog"):
            continue
        if line:
            items.append(line if line.endswith(".") else line + ".")
    if items:
        print(" ".join(items))
    sys.exit(0)
sys.exit(1)
' || return 1
}

from_learn() {
  local html
  # Learn serves the page as static HTML, but only to browser-like user agents.
  html=$(curl -fsSL --retry 3 --retry-delay 2 -A "Mozilla/5.0" "$LEARN_URL" 2>/dev/null) || return 1

  # Flatten to one text node per line, then walk: platform section -> version block.
  # A "[Tag]" line starts an item; every other line is a fragment of the current item
  # (Learn splits sentences around inline <code> elements).
  printf '%s' "$html" \
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
}

EXCERPT=""
if [[ "$PLATFORM" == "ios" ]]; then
  EXCERPT=$(from_github_releases | sanitize || true)
fi
if [[ -z "$EXCERPT" ]]; then
  EXCERPT=$(from_learn | sanitize || true)
fi

[[ -n "$EXCERPT" ]] && printf '%s\n' "$EXCERPT"
exit 0
