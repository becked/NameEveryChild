#!/bin/bash
# deploy.sh - Build and deploy mod to local mods folder
#
# Prerequisites:
#   1. .NET SDK installed
#   2. .env file with OLDWORLD_PATH and OLDWORLD_MODS_PATH set
#
# Usage: ./scripts/deploy.sh

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

if [ -z "$OLDWORLD_MODS_PATH" ]; then
    echo "Error: OLDWORLD_MODS_PATH not set in .env"
    exit 1
fi

# Build first
"$SCRIPT_DIR/build.sh"

# Deploy to mods folder
MOD_FOLDER="$OLDWORLD_MODS_PATH/Name Every Child"

echo ""
echo "=== Deploying to mods folder ==="
echo "Target: $MOD_FOLDER"

mkdir -p "$MOD_FOLDER"

cp ModInfo.xml "$MOD_FOLDER/"
cp bin/NameEveryChild.dll "$MOD_FOLDER/"
cp bin/0Harmony.dll "$MOD_FOLDER/"
cp NameEveryChild.png "$MOD_FOLDER/"


# Copy Infos folder if it exists
if [ -d "Infos" ]; then
    cp -r Infos "$MOD_FOLDER/"
fi

echo ""
echo "=== Deployment complete ==="
echo "Deployed files:"
ls -la "$MOD_FOLDER/"
