#!/bin/bash
# build.sh - Build the mod
#
# Prerequisites:
#   1. .NET SDK installed
#   2. .env file with OLDWORLD_PATH set
#
# Usage: ./scripts/build.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Load .env
if [ -f ".env" ]; then
    source ".env"
else
    echo "Error: .env file not found"
    echo "Copy .env.example to .env and configure it"
    exit 1
fi

if [ -z "$OLDWORLD_PATH" ]; then
    echo "Error: OLDWORLD_PATH not set in .env"
    exit 1
fi

echo "=== Building NameEveryChild ==="
echo "Game path: $OLDWORLD_PATH"

export OldWorldPath="$OLDWORLD_PATH"
dotnet build -c Release

# Copy 0Harmony.dll from NuGet cache
HARMONY_DLL=$(find ~/.nuget/packages/lib.harmony/2.4.2 -name "0Harmony.dll" -path "*net472*" | head -1)
if [ -n "$HARMONY_DLL" ]; then
    cp "$HARMONY_DLL" bin/
    echo "Copied 0Harmony.dll to bin/"
else
    echo "WARNING: 0Harmony.dll not found in NuGet cache!"
fi

echo ""
echo "=== Build complete ==="
echo "Output: bin/NameEveryChild.dll"
ls -la bin/*.dll
