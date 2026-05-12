#!/usr/bin/env bash
#
# Diffs the upstream native API surface introduced by a Clarity SDK bump.
#
# Usage: scripts/diff-binding-api.sh <android|ios> <previous-binding-version>
#
# Outputs (to GITHUB_OUTPUT if set, else stdout):
#   api_added_count    — number of `+` lines in the unified diff
#   api_removed_count  — number of `-` lines (likely-breaking changes)
#   diff_path          — path to the full unified diff for PR comments
#
# Approach:
#   Compare the *inputs* the binding generator sees, not the generated C# DLL.
#     - iOS:     Clarity-Swift.h from the old vs new xcframework.
#     - Android: javap -public output of the old vs new .aar's classes.jar.
#
# Why not GenAPI / ilspycmd / apicompat:
#   - Microsoft.DotNet.GenAPI.Tool was never published to nuget.org.
#   - ApiCompat.Tool only catches breaking changes, not additions — and we
#     need additions to know when to ping @copilot to wire new APIs.
#   - ilspycmd works but produces noisier diffs and adds a tool dependency
#     just to express "did Microsoft change anything?".
#   The native-source diff is simpler, faster (no DLL build needed), and
#   produces a diff a human can actually read in the PR comment.
#
# Limitation:
#   Misses changes that come from edits to Transforms/Metadata.xml or from
#   binding-generator version upgrades. Those are rare and human-initiated;
#   the wrapper-build step still catches breakage.

set -euo pipefail

PLATFORM="${1:?usage: diff-binding-api.sh <android|ios> <previous-binding-version>}"
PREVIOUS_VERSION="${2:?usage: ...}"

# Binding versioning is <native>.<binding-rev> (e.g. 3.4.0.1 -> native 3.4.0).
PREVIOUS_NATIVE=$(echo "$PREVIOUS_VERSION" | awk -F. 'BEGIN{OFS="."} NF>1 {NF--; print}')

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DIFF_PATH="api-diff.txt"

emit_outputs() {
  local added="$1" removed="$2" path="$3"
  echo "==> Outputs"
  echo "    additions (new API):             $added"
  echo "    removals/changes (likely break): $removed"
  echo "    full diff written to:            $path"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "api_added_count=$added"
      echo "api_removed_count=$removed"
      echo "diff_path=$path"
    } >> "$GITHUB_OUTPUT"
  fi
}

# Bail cleanly if we can't derive a previous native version to compare against.
if [[ -z "$PREVIOUS_NATIVE" || "$PREVIOUS_NATIVE" == "$PREVIOUS_VERSION" ]]; then
  echo "WARN: could not derive previous native version from '$PREVIOUS_VERSION' — skipping diff" >&2
  emit_outputs 0 0 ""
  exit 0
fi

case "$PLATFORM" in
  ios)
    NEW_HEADER="src/Maui.MicrosoftClarity.iOS/nativelib/Clarity.xcframework/ios-arm64/Clarity.framework/Headers/Clarity-Swift.h"
    if [[ ! -f "$NEW_HEADER" ]]; then
      echo "WARN: new Clarity-Swift.h not at $NEW_HEADER — skipping diff" >&2
      emit_outputs 0 0 ""
      exit 0
    fi

    OLD_ZIP_URL="https://www.clarity.ms/apps/resources/ios/Clarity-${PREVIOUS_NATIVE}.xcframework.zip"
    echo "==> Downloading previous xcframework: $OLD_ZIP_URL"
    if ! curl -fsSL "$OLD_ZIP_URL" -o "$WORK/old.zip"; then
      echo "WARN: previous xcframework v${PREVIOUS_NATIVE} not available at clarity.ms — skipping diff" >&2
      emit_outputs 0 0 ""
      exit 0
    fi
    unzip -q "$WORK/old.zip" -d "$WORK/old"

    OLD_HEADER=$(find "$WORK/old" -path '*ios-arm64*' -name 'Clarity-Swift.h' | head -1)
    if [[ -z "$OLD_HEADER" || ! -f "$OLD_HEADER" ]]; then
      echo "WARN: could not locate Clarity-Swift.h in previous xcframework — skipping diff" >&2
      emit_outputs 0 0 ""
      exit 0
    fi

    cp "$OLD_HEADER" "$WORK/old-api.txt"
    cp "$NEW_HEADER" "$WORK/new-api.txt"
    ;;

  android)
    NEW_AAR=$(ls src/Maui.MicrosoftClarity.Android/Jars/clarity-*.aar 2>/dev/null | head -1 || true)
    if [[ -z "$NEW_AAR" || ! -f "$NEW_AAR" ]]; then
      echo "WARN: no .aar under src/Maui.MicrosoftClarity.Android/Jars/ — skipping diff" >&2
      emit_outputs 0 0 ""
      exit 0
    fi

    OLD_AAR_URL="https://repo1.maven.org/maven2/com/microsoft/clarity/clarity/${PREVIOUS_NATIVE}/clarity-${PREVIOUS_NATIVE}.aar"
    echo "==> Downloading previous .aar: $OLD_AAR_URL"
    if ! curl -fsSL "$OLD_AAR_URL" -o "$WORK/old.aar"; then
      echo "WARN: previous .aar v${PREVIOUS_NATIVE} not on Maven Central — skipping diff" >&2
      emit_outputs 0 0 ""
      exit 0
    fi

    if ! command -v javap >/dev/null 2>&1; then
      echo "ERROR: javap not on PATH — need a JDK to diff Android API surface" >&2
      exit 1
    fi

    # Extract classes.jar from an .aar, unpack the .class files, dump every
    # public type via javap. Output is the API surface as javap-formatted text.
    dump_aar_api() {
      local aar="$1" extract_dir="$2"
      mkdir -p "$extract_dir"
      unzip -qo "$aar" classes.jar -d "$extract_dir"
      mkdir -p "$extract_dir/classes"
      unzip -qo "$extract_dir/classes.jar" -d "$extract_dir/classes"
      # Strip "Compiled from <Source>.java" — that line varies with filename
      # and isn't part of the API surface.
      find "$extract_dir/classes" -name '*.class' -print0 \
        | xargs -0 javap -public 2>/dev/null \
        | grep -v '^Compiled from' \
        || true
    }

    dump_aar_api "$WORK/old.aar" "$WORK/old-extract" > "$WORK/old-api.txt"
    dump_aar_api "$NEW_AAR"      "$WORK/new-extract" > "$WORK/new-api.txt"
    ;;

  *)
    echo "ERROR: unknown platform '$PLATFORM' (expected 'android' or 'ios')" >&2
    exit 2
    ;;
esac

# Sort so reordering doesn't show as diffs; the count is what feeds the
# stable-vs-needs-wiring decision in automatic-bump-and-wire.yml.
sort -u "$WORK/old-api.txt" > "$WORK/old-api.sorted"
sort -u "$WORK/new-api.txt" > "$WORK/new-api.sorted"

diff -u "$WORK/old-api.sorted" "$WORK/new-api.sorted" > "$DIFF_PATH" || true

ADDED=$(grep -cE '^\+[^+]' "$DIFF_PATH" || true)
REMOVED=$(grep -cE '^-[^-]' "$DIFF_PATH" || true)

emit_outputs "$ADDED" "$REMOVED" "$DIFF_PATH"
