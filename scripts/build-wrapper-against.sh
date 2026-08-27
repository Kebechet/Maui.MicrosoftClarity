#!/usr/bin/env bash
#
# Compiles the cross-platform wrapper against a binding that is NOT on nuget.org yet:
# the freshly packed nupkg in <feed-dir>. This is the consumer-side check a bump PR must
# pass before it is called green - a native SDK that silently drops or renames an API the
# wrapper uses would otherwise only surface when the wrapper is moved onto the binding.
#
# Usage: scripts/build-wrapper-against.sh <android|ios> <feed-dir> <binding-version>
#
# The wrapper's <PackageReference> version is rewritten in place for the duration of the
# build and restored from a byte copy on exit - including when the build fails, when the
# script is interrupted, and when a command under `set -e` aborts it. The bump itself
# never carries that edit: open-bump-pr.sh commits only the binding directory and refuses
# to commit at all unless this file is byte-identical to HEAD. The old pipeline made the
# same edit without either guard, which is how two bump PRs ended up referencing a
# package that did not exist.
#
# The version rewrite goes through scripts/clarity.cs, a .NET file-based app (see
# CLAUDE.md), so the repo keeps one language and the file's BOM and CRLF survive.
#
# The feed is wired through a throwaway nuget.config rather than `--source`: when NuGet
# decides that any --source value is relative it resolves ALL of them against the project
# directory, and the nuget.org URL turns into a non-existent local path (NU1301) - which
# is what broke every wrapper build in the old pipeline.

set -euo pipefail

PLATFORM="${1:?usage: build-wrapper-against.sh <android|ios> <feed-dir> <binding-version>}"
FEED="${2:?usage: build-wrapper-against.sh <android|ios> <feed-dir> <binding-version>}"
VERSION="${3:?usage: build-wrapper-against.sh <android|ios> <feed-dir> <binding-version>}"
WRAPPER="src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj"
CONFIGURATION="${BUILD_CONFIGURATION:-Release}"

case "$PLATFORM" in
  android) TFM="net10.0-android"; PACKAGE_ID="Kebechet.Maui.MicrosoftClarity.Android" ;;
  ios)     TFM="net10.0-ios";     PACKAGE_ID="Kebechet.Maui.MicrosoftClarity.iOS" ;;
  *) echo "ERROR: unknown platform '$PLATFORM' (expected android or ios)" >&2; exit 2 ;;
esac

if ! ls "$FEED"/*.nupkg >/dev/null 2>&1; then
  echo "ERROR: no .nupkg in feed directory '$FEED'" >&2
  exit 1
fi

FEED_ABS=$(cd "$FEED" && pwd)
# Git Bash on Windows: dotnet needs a Windows path, not /c/... (only matters locally).
if command -v cygpath >/dev/null 2>&1; then
  FEED_ABS=$(cygpath -w "$FEED_ABS")
fi

CONFIG="$FEED/nuget.config"
cat > "$CONFIG" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="bump-feed" value="$FEED_ABS" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
EOF

# --- Point the wrapper at the unpublished version, and put it back no matter what -----
BACKUP=$(mktemp)
cp "$WRAPPER" "$BACKUP"
restore_wrapper() {
  local status=$?
  cp "$BACKUP" "$WRAPPER"
  rm -f "$BACKUP"
  return $status
}
trap restore_wrapper EXIT

dotnet run scripts/clarity.cs -- set-package-version "$WRAPPER" "$PACKAGE_ID" "$VERSION"

if ! grep -qF "\"$PACKAGE_ID\" Version=\"$VERSION\"" "$WRAPPER"; then
  echo "ERROR: could not point $PACKAGE_ID at $VERSION in $WRAPPER" >&2
  grep -n "$PACKAGE_ID" "$WRAPPER" >&2 || true
  exit 1
fi
echo "==> $WRAPPER temporarily references $PACKAGE_ID $VERSION"

echo "==> Restoring wrapper ($TFM) from $FEED_ABS"
dotnet restore "$WRAPPER" --configfile "$CONFIG" -p:TargetFrameworks="$TFM"

echo "==> Building wrapper ($TFM)"
dotnet build "$WRAPPER" --no-restore -c "$CONFIGURATION" \
  -p:TargetFrameworks="$TFM" -p:GeneratePackageOnBuild=false

echo "==> Wrapper compiles against $PACKAGE_ID $VERSION"
