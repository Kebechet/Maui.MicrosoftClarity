#!/usr/bin/env bash
#
# Diffs the public API surface of the freshly-built binding DLL against the
# previously-published version on nuget.org.
#
# Usage: scripts/diff-binding-api.sh <android|ios> <previous-binding-version>
#
# Outputs (to GITHUB_OUTPUT if set, else stdout):
#   api_added_count    — number of `+` lines in the unified diff (new API)
#   api_removed_count  — number of `-` lines (removed/changed API; usually breaking)
#   diff_path          — path to the full unified diff for PR comments
#
# Approach:
#   1. Pull the previous binding nupkg from nuget.org via the v2 download endpoint.
#   2. Extract the binding DLL from `lib/<tfm>/`.
#   3. Build the current binding (assumed already built; we just locate the DLL).
#   4. Run Microsoft.DotNet.GenAPI.Tool on both to produce sorted C# stubs.
#   5. `diff -u` and count add/remove lines.
#
# Why GenAPI rather than apicompat:
#   apicompat's mandate is breaking-change detection — it only surfaces
#   removals/changes, not additions. We need to know about additions so the
#   agent can wrap them.

set -euo pipefail

PLATFORM="${1:?usage: diff-binding-api.sh <android|ios> <previous-binding-version>}"
PREVIOUS_VERSION="${2:?usage: ...}"

case "$PLATFORM" in
  android)
    PACKAGE_ID="Kebechet.Maui.MicrosoftClarity.Android"
    ASSEMBLY_NAME="Maui.MicrosoftClarity.Android.dll"
    TFM="net10.0-android"
    BUILD_OUT="src/Maui.MicrosoftClarity.Android/bin/Release/${TFM}"
    ;;
  ios)
    PACKAGE_ID="Kebechet.Maui.MicrosoftClarity.iOS"
    ASSEMBLY_NAME="Maui.MicrosoftClarity.iOS.dll"
    TFM="net10.0-ios"
    BUILD_OUT="src/Maui.MicrosoftClarity.iOS/bin/Release/${TFM}"
    ;;
  *)
    echo "ERROR: unknown platform '$PLATFORM' (expected 'android' or 'ios')" >&2
    exit 2
    ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- 1. Download previous nupkg -------------------------------------------
NUPKG_URL="https://www.nuget.org/api/v2/package/${PACKAGE_ID}/${PREVIOUS_VERSION}"
echo "==> Downloading previous nupkg: $NUPKG_URL"
if ! curl -fsSL "$NUPKG_URL" -o "$WORK/old.nupkg"; then
  echo "WARN: previous version $PREVIOUS_VERSION not found on nuget.org — treating as no diff baseline" >&2
  echo "api_added_count=0"
  echo "api_removed_count=0"
  echo "diff_path="
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "api_added_count=0"
      echo "api_removed_count=0"
      echo "diff_path="
    } >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi

unzip -q "$WORK/old.nupkg" -d "$WORK/old"

# Find the DLL inside lib/<tfm>/. The TFM in the nupkg may have a minor-version
# suffix (e.g. net10.0-android33.0); match by prefix.
TFM_DIR=$(find "$WORK/old/lib" -type d -name "${TFM}*" | head -1)
OLD_DLL=$(find "$TFM_DIR" -name "$ASSEMBLY_NAME" 2>/dev/null | head -1)
if [[ -z "$OLD_DLL" ]]; then
  echo "WARN: could not find $ASSEMBLY_NAME in previous nupkg under lib/${TFM}*; skipping diff" >&2
  echo "api_added_count=0"
  echo "api_removed_count=0"
  exit 0
fi
echo "    old DLL: $OLD_DLL"

# --- 2. Locate freshly-built DLL ------------------------------------------
NEW_DLL="$BUILD_OUT/$ASSEMBLY_NAME"
if [[ ! -f "$NEW_DLL" ]]; then
  # Fallback: the actual TFM directory may have a platform-version suffix.
  NEW_DLL=$(find "$(dirname "$BUILD_OUT")" -type f -name "$ASSEMBLY_NAME" | head -1)
fi
if [[ ! -f "$NEW_DLL" ]]; then
  echo "ERROR: could not locate freshly-built $ASSEMBLY_NAME (expected near $BUILD_OUT)" >&2
  exit 1
fi
echo "    new DLL: $NEW_DLL"

# --- 3. Install GenAPI ----------------------------------------------------
if ! command -v genapi >/dev/null 2>&1; then
  echo "==> Installing Microsoft.DotNet.GenAPI.Tool"
  dotnet tool install -g Microsoft.DotNet.GenAPI.Tool >/dev/null 2>&1 || \
    dotnet tool update  -g Microsoft.DotNet.GenAPI.Tool >/dev/null 2>&1
  export PATH="$PATH:$HOME/.dotnet/tools"
fi

# --- 4. Generate API surface dumps ----------------------------------------
echo "==> Generating API surface dumps"
genapi "$OLD_DLL" --output-path "$WORK/old-api.cs" >/dev/null 2>&1 || genapi -o "$WORK/old-api.cs" "$OLD_DLL"
genapi "$NEW_DLL" --output-path "$WORK/new-api.cs" >/dev/null 2>&1 || genapi -o "$WORK/new-api.cs" "$NEW_DLL"

# Sort lines so reordering doesn't show as diffs (GenAPI output is mostly
# alphabetical but not guaranteed).
sort -u "$WORK/old-api.cs" > "$WORK/old-api.sorted.cs"
sort -u "$WORK/new-api.cs" > "$WORK/new-api.sorted.cs"

# --- 5. Diff ---------------------------------------------------------------
DIFF_PATH="api-diff.txt"
diff -u "$WORK/old-api.sorted.cs" "$WORK/new-api.sorted.cs" > "$DIFF_PATH" || true

# Count + and - data lines (skip the +++/--- headers).
ADDED=$(grep -cE '^\+[^+]' "$DIFF_PATH" || true)
REMOVED=$(grep -cE '^-[^-]' "$DIFF_PATH" || true)

echo "==> API surface change detected"
echo "    additions (new API):           $ADDED"
echo "    removals/changes (likely break): $REMOVED"
echo "    full diff written to:          $DIFF_PATH"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "api_added_count=$ADDED"
    echo "api_removed_count=$REMOVED"
    echo "diff_path=$DIFF_PATH"
  } >> "$GITHUB_OUTPUT"
fi
