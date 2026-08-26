#!/usr/bin/env bash
#
# Compiles the cross-platform wrapper against a binding that is NOT on nuget.org yet:
# the freshly packed nupkg in <feed-dir>. This is the consumer-side check a bump PR must
# pass before it is called green - a native SDK that silently drops or renames an API the
# wrapper uses would otherwise only surface when the wrapper is moved onto the binding.
#
# Usage: scripts/build-wrapper-against.sh <android|ios> <feed-dir> <binding-version>
#
# The wrapper csproj is never modified: its binding PackageReference versions are the
# MSBuild properties ClarityAndroidBindingVersion / ClarityIosBindingVersion, overridden
# here as global properties. The feed is wired through a throwaway nuget.config rather
# than `--source`: when NuGet decides that any --source value is relative it resolves
# ALL of them against the project directory, and the nuget.org URL turns into a
# non-existent local path (NU1301) - which is what broke every wrapper build in the old
# pipeline.

set -euo pipefail

PLATFORM="${1:?usage: build-wrapper-against.sh <android|ios> <feed-dir> <binding-version>}"
FEED="${2:?usage: build-wrapper-against.sh <android|ios> <feed-dir> <binding-version>}"
VERSION="${3:?usage: build-wrapper-against.sh <android|ios> <feed-dir> <binding-version>}"
WRAPPER="src/Maui.MicrosoftClarity/Maui.MicrosoftClarity.csproj"
CONFIGURATION="${BUILD_CONFIGURATION:-Release}"

case "$PLATFORM" in
  android) TFM="net10.0-android"; PROP="ClarityAndroidBindingVersion" ;;
  ios)     TFM="net10.0-ios";     PROP="ClarityIosBindingVersion" ;;
  *) echo "ERROR: unknown platform '$PLATFORM' (expected android or ios)" >&2; exit 2 ;;
esac

if ! ls "$FEED"/*.nupkg >/dev/null 2>&1; then
  echo "ERROR: no .nupkg in feed directory '$FEED'" >&2
  exit 1
fi

FEED_ABS=$(cd "$FEED" && pwd)
# Git Bash on Windows: dotnet needs a Windows path, not /c/... (only matters for local runs).
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

echo "==> Restoring wrapper ($TFM) with $PROP=$VERSION from $FEED_ABS"
dotnet restore "$WRAPPER" --configfile "$CONFIG" \
  -p:TargetFrameworks="$TFM" -p:"$PROP=$VERSION"

echo "==> Building wrapper ($TFM)"
dotnet build "$WRAPPER" --no-restore -c "$CONFIGURATION" \
  -p:TargetFrameworks="$TFM" -p:"$PROP=$VERSION" -p:GeneratePackageOnBuild=false

echo "==> Wrapper compiles against $PROP=$VERSION"
