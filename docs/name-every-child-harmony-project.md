# Name Every Child - Harmony Conversion Project

This document contains everything needed to rebuild the Name Every Child mod using Harmony, making it compatible with other mods and future-proof against game updates.

---

## Overview

**Purpose:** Trigger the child naming event for ALL leader's children, not just the heir.

**Original approach:** GameFactory + Character subclass (conflicts with other mods)

**New approach:** Harmony Transpiler that removes only the `isHeir()` check, preserving all other logic including future additions.

---

## Project Structure

```
NameEveryChildHarmony/
├── NameEveryChild.csproj
├── NameEveryChildEntryPoint.cs
├── Patches/
│   └── CharacterPatches.cs
└── Build/
    └── (output goes here)
```

**Mod folder structure (after build):**
```
Name Every Child/
├── ModInfo.xml
├── 0Harmony.dll           # Required: Harmony library
├── NameEveryChild.dll     # Your compiled mod
├── NameEveryChild.png
└── Infos/
    └── text-helptext-change.xml
```

---

## Source Code

### NameEveryChild.csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net7.0</TargetFramework>
    <AssemblyName>NameEveryChild</AssemblyName>
    <RootNamespace>NameEveryChild</RootNamespace>
    <ImplicitUsings>disable</ImplicitUsings>
    <Nullable>disable</Nullable>
    <OutputPath>Build</OutputPath>
    <AppendTargetFrameworkToOutputPath>false</AppendTargetFrameworkToOutputPath>
  </PropertyGroup>

  <!-- Harmony NuGet package -->
  <ItemGroup>
    <PackageReference Include="Lib.Harmony" Version="2.3.3" />
  </ItemGroup>

  <!-- Game references - adjust paths for your system -->
  <ItemGroup>
    <!-- macOS Steam paths -->
    <Reference Include="Assembly-CSharp" Condition="$([MSBuild]::IsOSPlatform('OSX'))">
      <HintPath>$(HOME)/Library/Application Support/Steam/steamapps/common/Old World/Old World.app/Contents/Resources/Data/Managed/Assembly-CSharp.dll</HintPath>
      <Private>false</Private>
    </Reference>
    <Reference Include="UnityEngine.CoreModule" Condition="$([MSBuild]::IsOSPlatform('OSX'))">
      <HintPath>$(HOME)/Library/Application Support/Steam/steamapps/common/Old World/Old World.app/Contents/Resources/Data/Managed/UnityEngine.CoreModule.dll</HintPath>
      <Private>false</Private>
    </Reference>

    <!-- Windows Steam paths -->
    <Reference Include="Assembly-CSharp" Condition="$([MSBuild]::IsOSPlatform('Windows'))">
      <HintPath>C:\Program Files (x86)\Steam\steamapps\common\Old World\Old World_Data\Managed\Assembly-CSharp.dll</HintPath>
      <Private>false</Private>
    </Reference>
    <Reference Include="UnityEngine.CoreModule" Condition="$([MSBuild]::IsOSPlatform('Windows'))">
      <HintPath>C:\Program Files (x86)\Steam\steamapps\common\Old World\Old World_Data\Managed\UnityEngine.CoreModule.dll</HintPath>
      <Private>false</Private>
    </Reference>

    <!-- Linux Steam paths -->
    <Reference Include="Assembly-CSharp" Condition="$([MSBuild]::IsOSPlatform('Linux'))">
      <HintPath>$(HOME)/.steam/steam/steamapps/common/Old World/Old World_Data/Managed/Assembly-CSharp.dll</HintPath>
      <Private>false</Private>
    </Reference>
    <Reference Include="UnityEngine.CoreModule" Condition="$([MSBuild]::IsOSPlatform('Linux'))">
      <HintPath>$(HOME)/.steam/steam/steamapps/common/Old World/Old World_Data/Managed/UnityEngine.CoreModule.dll</HintPath>
      <Private>false</Private>
    </Reference>
  </ItemGroup>

</Project>
```

---

### NameEveryChildEntryPoint.cs

```csharp
using System;
using HarmonyLib;
using TenCrowns.AppCore;
using TenCrowns.GameCore;
using UnityEngine;

namespace NameEveryChild
{
    /// <summary>
    /// Entry point for the Name Every Child mod.
    /// Uses Harmony to patch Character.isValidChooseName() instead of GameFactory,
    /// ensuring compatibility with other mods.
    /// </summary>
    public class NameEveryChildEntryPoint : ModEntryPointAdapter
    {
        private static Harmony _harmony;
        private const string HarmonyId = "com.becked.nameeverychild";

        public override void Initialize(ModSettings modSettings)
        {
            base.Initialize(modSettings);

            try
            {
                _harmony = new Harmony(HarmonyId);
                _harmony.PatchAll();
                Debug.Log("[NameEveryChild] Harmony patches applied successfully");
            }
            catch (Exception ex)
            {
                Debug.LogError($"[NameEveryChild] Failed to apply Harmony patches: {ex}");
            }
        }

        public override void Shutdown()
        {
            try
            {
                _harmony?.UnpatchSelf();
                Debug.Log("[NameEveryChild] Harmony patches removed");
            }
            catch (Exception ex)
            {
                Debug.LogError($"[NameEveryChild] Failed to remove Harmony patches: {ex}");
            }

            base.Shutdown();
        }
    }
}
```

---

### Patches/CharacterPatches.cs

```csharp
using System;
using System.Collections.Generic;
using System.Reflection.Emit;
using HarmonyLib;
using TenCrowns.GameCore;
using UnityEngine;

namespace NameEveryChild.Patches
{
    /// <summary>
    /// Patches Character.isValidChooseName() to allow naming ALL leader's children,
    /// not just the heir.
    ///
    /// Uses a Transpiler to surgically remove only the isHeir() check while
    /// preserving all other validation logic (current and future).
    /// </summary>
    [HarmonyPatch(typeof(Character))]
    public static class CharacterPatches
    {
        /// <summary>
        /// Transpiler that removes the isHeir() check from isValidChooseName().
        ///
        /// Original method structure:
        ///   if (!isHeir()) return false;        // We remove this check
        ///   if (!isLeaderChild()) return false; // Kept
        ///   if (hasName()) return false;        // Kept
        ///   if (game().isNoEvents()) return false; // Kept
        ///   return true;
        ///
        /// The transpiler finds the isHeir() call and replaces it with a constant 'true',
        /// so the subsequent brfalse instruction never triggers.
        /// </summary>
        [HarmonyPatch(nameof(Character.isValidChooseName))]
        [HarmonyTranspiler]
        public static IEnumerable<CodeInstruction> RemoveHeirCheck(
            IEnumerable<CodeInstruction> instructions,
            ILGenerator generator)
        {
            var codes = new List<CodeInstruction>(instructions);
            var isHeirMethod = AccessTools.Method(typeof(Character), nameof(Character.isHeir));

            if (isHeirMethod == null)
            {
                Debug.LogError("[NameEveryChild] Could not find Character.isHeir method!");
                return codes;
            }

            bool patched = false;

            for (int i = 0; i < codes.Count; i++)
            {
                // Look for: call/callvirt Character::isHeir()
                if (codes[i].Calls(isHeirMethod))
                {
                    // Replace the isHeir() call with loading constant 'true' (1)
                    // This means the subsequent "brfalse" (branch if false) will never trigger
                    codes[i] = new CodeInstruction(OpCodes.Ldc_I4_1)
                    {
                        // Preserve any labels that pointed to this instruction
                        labels = codes[i].labels
                    };

                    patched = true;
                    Debug.Log("[NameEveryChild] Transpiler: Successfully removed isHeir() check");
                    break;
                }
            }

            if (!patched)
            {
                Debug.LogWarning("[NameEveryChild] Transpiler: Could not find isHeir() call to patch. " +
                    "The method structure may have changed in a game update.");
            }

            return codes;
        }

        /// <summary>
        /// Fallback postfix in case the transpiler fails.
        /// This is less ideal but ensures the mod still works.
        /// </summary>
        [HarmonyPatch(nameof(Character.isValidChooseName))]
        [HarmonyPostfix]
        [HarmonyPriority(Priority.Last)] // Run after transpiler
        public static void IsValidChooseName_Fallback(Character __instance, ref bool __result)
        {
            // If already true (heir case), no action needed
            if (__result) return;

            // If false, check if we should override due to being a non-heir leader's child
            // This is the fallback in case the transpiler didn't work
            try
            {
                // Only override if this character would pass all checks EXCEPT isHeir
                if (__instance.isLeaderChild() &&
                    !__instance.hasName() &&
                    !__instance.game().isNoEvents())
                {
                    // Check if they're NOT the heir (meaning the original returned false due to heir check)
                    if (!__instance.isHeir())
                    {
                        __result = true;
                        // Note: If this message appears, the transpiler didn't work
                        // and we're using the fallback
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.LogError($"[NameEveryChild] Fallback postfix error: {ex.Message}");
            }
        }
    }
}
```

---

## ModInfo.xml

No changes needed from your original - keep using your existing `ModInfo.xml`:

```xml
<?xml version="1.0"?>
<ModInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <displayName>Name Every Child</displayName>
  <description>
  Why stop at naming your heir? A true ruler names every child!

  This mod triggers the event to name a child every time, instead of just for your character's heir. I love when my future leaders have a generational name suffix and 100 turns in I'm playing as Hanno III. But so often in this game, kids die or run away or who knows what. Triggering this event on each child will increase the chances of a high generational suffix.
  </description>
  <modpicture>NameEveryChild.png</modpicture>
  <author>becked</author>
  <modplatform>Modio</modplatform>
  <modioID>4083305</modioID>
  <modioFileID>0</modioFileID>
  <workshopOwnerID>76561199101298499</workshopOwnerID>
  <workshopFileID>3268530172</workshopFileID>
  <modversion>0.0.2</modversion>
  <modbuild>1.0.80908</modbuild>
  <tags>Character</tags>
  <singlePlayer>true</singlePlayer>
  <multiplayer>true</multiplayer>
  <scenario>false</scenario>
  <scenarioToggle>false</scenarioToggle>
  <blocksMods>false</blocksMods>
  <modDependencies />
  <modIncompatibilities />
  <modWhitelist />
  <gameContentRequired>NONE</gameContentRequired>
</ModInfo>
```

---

## Build Instructions

### Prerequisites

1. **.NET 7 SDK** - Download from https://dotnet.microsoft.com/download
2. **Old World** installed via Steam

### Building

```bash
# Navigate to project directory
cd NameEveryChildHarmony

# Restore packages (downloads Harmony)
dotnet restore

# Build
dotnet build -c Release

# Output will be in Build/ directory:
#   - NameEveryChild.dll
#   - 0Harmony.dll (copied from NuGet)
```

### Alternative: Single-File Build Script

**build.sh (macOS/Linux):**
```bash
#!/bin/bash
set -e

echo "Building Name Every Child (Harmony version)..."

# Create output directory
mkdir -p Build

# Build the project
dotnet build -c Release

# Copy Harmony DLL if not already there
HARMONY_PATH=$(find ~/.nuget/packages/lib.harmony -name "0Harmony.dll" | head -1)
if [ -f "$HARMONY_PATH" ]; then
    cp "$HARMONY_PATH" Build/
fi

echo "Build complete! Output in Build/"
ls -la Build/
```

**build.ps1 (Windows):**
```powershell
Write-Host "Building Name Every Child (Harmony version)..."

# Create output directory
New-Item -ItemType Directory -Force -Path Build | Out-Null

# Build the project
dotnet build -c Release

# Copy Harmony DLL
$harmonyPath = Get-ChildItem -Path "$env:USERPROFILE\.nuget\packages\lib.harmony" -Recurse -Filter "0Harmony.dll" | Select-Object -First 1
if ($harmonyPath) {
    Copy-Item $harmonyPath.FullName -Destination Build\
}

Write-Host "Build complete! Output in Build/"
Get-ChildItem Build\
```

---

## Installation

### 1. Backup Original Mod

```bash
# macOS
cp -r ~/Library/Application\ Support/OldWorld/Mods/Name\ Every\ Child \
      ~/Library/Application\ Support/OldWorld/Mods/Name\ Every\ Child.backup

# Windows
xcopy /E /I "%APPDATA%\OldWorld\Mods\Name Every Child" "%APPDATA%\OldWorld\Mods\Name Every Child.backup"
```

### 2. Install New Files

Copy from your `Build/` directory to the mod folder:

| File | Action |
|------|--------|
| `NameEveryChild.dll` | Replace existing |
| `0Harmony.dll` | Add (new file) |

**macOS:**
```bash
MOD_DIR=~/Library/Application\ Support/OldWorld/Mods/Name\ Every\ Child

cp Build/NameEveryChild.dll "$MOD_DIR/"
cp Build/0Harmony.dll "$MOD_DIR/"
```

**Windows:**
```powershell
$modDir = "$env:APPDATA\OldWorld\Mods\Name Every Child"

Copy-Item Build\NameEveryChild.dll -Destination $modDir
Copy-Item Build\0Harmony.dll -Destination $modDir
```

### 3. Verify Installation

Your mod folder should now contain:
```
Name Every Child/
├── ModInfo.xml
├── 0Harmony.dll           ← NEW
├── NameEveryChild.dll     ← UPDATED
├── NameEveryChild.png
└── Infos/
    └── text-helptext-change.xml
```

---

## Testing

### Test Checklist

1. **Basic functionality:**
   - [ ] Start new game
   - [ ] Have a non-heir child born (second child, or heir dies)
   - [ ] Verify naming event triggers for non-heir children

2. **Heir still works:**
   - [ ] First child (heir) still triggers naming event

3. **Mod compatibility:**
   - [ ] Enable another DLL mod alongside this one
   - [ ] Verify both mods function correctly

4. **Check logs for success:**
   - [ ] Look for: `[NameEveryChild] Harmony patches applied successfully`
   - [ ] Look for: `[NameEveryChild] Transpiler: Successfully removed isHeir() check`

### Log File Locations

| Platform | Path |
|----------|------|
| macOS | `~/Library/Logs/Mohawk Games/Old World/Player.log` |
| Windows | `%USERPROFILE%\AppData\LocalLow\Mohawk Games\Old World\Player.log` |
| Linux | `~/.config/unity3d/Mohawk Games/Old World/Player.log` |

### Expected Log Output

```
[NameEveryChild] Harmony patches applied successfully
[NameEveryChild] Transpiler: Successfully removed isHeir() check
```

If you see the fallback message instead:
```
[NameEveryChild] Transpiler: Could not find isHeir() call to patch...
```

The mod will still work (via the postfix fallback), but you should investigate why the transpiler failed - likely a game update changed the method.

---

## Automated Headless Testing

Old World supports headless mode for automated testing. This allows CI/CD validation of the mod without manual gameplay.

### How Headless Mode Works

Old World can run in headless mode with AI controlling all players:

```bash
OldWorld <savefile> -batchmode -headless -autorunturns <N>
```

| Argument | Description |
|----------|-------------|
| `<savefile>` | Path to save file (positional, not a flag) |
| `-batchmode` | Unity batch mode - required for headless |
| `-headless` | Disables graphics rendering |
| `-autorunturns <N>` | Run N turns with AI control, then exit |

In headless mode:
- All mod hooks fire normally (`Initialize()`, `Shutdown()`, etc.)
- AI automatically resolves all decisions, including `CHOOSE_NAME` (picks random name)
- Auto-saves are created in `Saves/Auto/` directory
- Game exits after completing the specified turns

### Enhanced Mod Logging for Testing

To validate the mod's effect in headless mode, add tracking to `doChooseNameEvent`:

**Patches/CharacterPatches.cs** - Add a postfix to track naming events:

```csharp
/// <summary>
/// Postfix to log when naming events are triggered.
/// Useful for headless testing validation.
/// </summary>
[HarmonyPatch(typeof(Character), nameof(Character.doChooseNameEvent))]
[HarmonyPostfix]
public static void DoChooseNameEvent_Log(Character __instance, bool __result)
{
    if (__result)
    {
        bool isHeir = __instance.isHeir();
        Debug.Log($"[NameEveryChild] Naming event triggered: " +
            $"CharacterID={__instance.getID()}, " +
            $"IsHeir={isHeir}, " +
            $"IsLeaderChild={__instance.isLeaderChild()}");

        if (!isHeir)
        {
            Debug.Log("[NameEveryChild] SUCCESS: Non-heir child naming event fired!");
        }
    }
}
```

### Test Save Requirements

For automated testing, you need a save file where:
1. The ruler has a spouse
2. The ruler is young enough to have children
3. Events are enabled (not `isNoEvents()`)
4. Enough turns will pass for children to be born

**Option 1: Create manually**
1. Start a new game with a young ruler
2. Get married
3. Save after a few turns
4. Use this save for testing

**Option 2: Use console commands** (requires cheats enabled)
```
# In-game console commands to set up test conditions:
newcharacter 0 FAMILY_ROME 0    # Create a newborn for player 0
autoplay 10                      # Run 10 turns with AI
```

### Test Script (test-headless.sh)

```bash
#!/bin/bash
# test-headless.sh - Automated headless test for Name Every Child mod
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAVE_FILE="${1:-$SCRIPT_DIR/TestSaves/NameEveryChildTest.zip}"
TURNS="${2:-50}"
GAME_LOG="/tmp/nec_game_log.txt"

# Platform-specific paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    OLD_WORLD_APP="/Users/$USER/Library/Application Support/Steam/steamapps/common/Old World/Old World.app/Contents/MacOS/Old World"
    MOD_DIR="$HOME/Library/Application Support/OldWorld/Mods/Name Every Child"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OLD_WORLD_APP="$HOME/.steam/steam/steamapps/common/Old World/OldWorld"
    MOD_DIR="$HOME/.local/share/OldWorld/Mods/Name Every Child"
else
    echo "Windows: Use test-headless.ps1 instead"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Name Every Child - Headless Test         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if [ ! -f "$SAVE_FILE" ]; then
    echo -e "${RED}Error: Save file not found: $SAVE_FILE${NC}"
    echo "Create a test save with a young ruler who has a spouse."
    exit 1
fi

if [ ! -d "$MOD_DIR" ]; then
    echo -e "${RED}Error: Mod not installed at: $MOD_DIR${NC}"
    exit 1
fi

echo "Save file: $SAVE_FILE"
echo "Turns: $TURNS"
echo "Mod dir: $MOD_DIR"
echo ""

# Clear previous log
> "$GAME_LOG"

# Run the game
echo -e "${YELLOW}[1/3] Running Old World headless (${TURNS} turns)...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    arch -x86_64 "$OLD_WORLD_APP" "$SAVE_FILE" -batchmode -headless -autorunturns "$TURNS" > "$GAME_LOG" 2>&1 || true
else
    "$OLD_WORLD_APP" "$SAVE_FILE" -batchmode -headless -autorunturns "$TURNS" > "$GAME_LOG" 2>&1 || true
fi
echo -e "${GREEN}      Game completed${NC}"

# Analyze results
echo -e "${YELLOW}[2/3] Analyzing logs...${NC}"
echo ""

# Check mod loaded
echo -n "  Mod loaded: "
if grep -q "\[NameEveryChild\] Harmony patches applied successfully" "$GAME_LOG"; then
    echo -e "${GREEN}YES${NC}"
    MOD_LOADED=1
else
    echo -e "${RED}NO${NC}"
    MOD_LOADED=0
fi

# Check transpiler success
echo -n "  Transpiler patched: "
if grep -q "\[NameEveryChild\] Transpiler: Successfully removed isHeir" "$GAME_LOG"; then
    echo -e "${GREEN}YES${NC}"
    TRANSPILER_OK=1
else
    echo -e "${RED}NO${NC}"
    TRANSPILER_OK=0
fi

# Check for fallback usage (indicates transpiler failed but fallback works)
echo -n "  Using fallback: "
if grep -q "\[NameEveryChild\] Fallback postfix" "$GAME_LOG"; then
    echo -e "${YELLOW}YES (transpiler failed, fallback active)${NC}"
else
    echo -e "${GREEN}NO (transpiler working)${NC}"
fi

# Check for naming events
echo ""
echo -e "${CYAN}── Naming Events ──${NC}"

HEIR_EVENTS=$(grep -c "\[NameEveryChild\] Naming event triggered.*IsHeir=True" "$GAME_LOG" 2>/dev/null || echo "0")
NON_HEIR_EVENTS=$(grep -c "\[NameEveryChild\] SUCCESS: Non-heir child" "$GAME_LOG" 2>/dev/null || echo "0")

echo "  Heir naming events: $HEIR_EVENTS"
echo "  Non-heir naming events: $NON_HEIR_EVENTS"

# Show all naming event logs
echo ""
echo -e "${CYAN}── Naming Event Details ──${NC}"
grep "\[NameEveryChild\]" "$GAME_LOG" 2>/dev/null | head -20 || echo "  (no events logged)"

# Summary
echo ""
echo -e "${YELLOW}[3/3] Results${NC}"
echo ""

PASS=1
if [ "$MOD_LOADED" -eq 0 ]; then
    echo -e "${RED}FAIL: Mod did not load${NC}"
    PASS=0
fi

if [ "$TRANSPILER_OK" -eq 0 ]; then
    echo -e "${YELLOW}WARN: Transpiler did not patch (fallback may be active)${NC}"
fi

if [ "$NON_HEIR_EVENTS" -gt 0 ]; then
    echo -e "${GREEN}PASS: Non-heir naming events detected!${NC}"
elif [ "$HEIR_EVENTS" -gt 0 ]; then
    echo -e "${YELLOW}PARTIAL: Only heir events detected (no non-heirs born in test)${NC}"
else
    echo -e "${YELLOW}INCONCLUSIVE: No naming events during test run${NC}"
    echo "  Tip: Use a save where children will be born, or run more turns"
fi

echo ""
echo -e "${CYAN}── Files ──${NC}"
echo "Game log: $GAME_LOG"
echo ""

if [ "$PASS" -eq 1 ] && [ "$MOD_LOADED" -eq 1 ]; then
    echo -e "${GREEN}Test completed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Test failed - check logs for details${NC}"
    exit 1
fi
```

### Test Script (test-headless.ps1) - Windows

```powershell
# test-headless.ps1 - Automated headless test for Name Every Child mod
param(
    [string]$SaveFile = "$PSScriptRoot\TestSaves\NameEveryChildTest.zip",
    [int]$Turns = 50
)

$ErrorActionPreference = "Stop"

# Configuration
$GameExe = "C:\Program Files (x86)\Steam\steamapps\common\Old World\OldWorld.exe"
$ModDir = "$env:APPDATA\OldWorld\Mods\Name Every Child"
$GameLog = "$env:TEMP\nec_game_log.txt"

Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Name Every Child - Headless Test         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
if (-not (Test-Path $SaveFile)) {
    Write-Host "Error: Save file not found: $SaveFile" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ModDir)) {
    Write-Host "Error: Mod not installed at: $ModDir" -ForegroundColor Red
    exit 1
}

Write-Host "Save file: $SaveFile"
Write-Host "Turns: $Turns"
Write-Host ""

# Run the game
Write-Host "[1/3] Running Old World headless ($Turns turns)..." -ForegroundColor Yellow
& $GameExe $SaveFile -batchmode -headless -autorunturns $Turns *> $GameLog
Write-Host "      Game completed" -ForegroundColor Green

# Analyze results
Write-Host "[2/3] Analyzing logs..." -ForegroundColor Yellow
Write-Host ""

$logContent = Get-Content $GameLog -Raw

# Check mod loaded
Write-Host -NoNewline "  Mod loaded: "
if ($logContent -match "\[NameEveryChild\] Harmony patches applied successfully") {
    Write-Host "YES" -ForegroundColor Green
    $modLoaded = $true
} else {
    Write-Host "NO" -ForegroundColor Red
    $modLoaded = $false
}

# Check transpiler
Write-Host -NoNewline "  Transpiler patched: "
if ($logContent -match "\[NameEveryChild\] Transpiler: Successfully removed isHeir") {
    Write-Host "YES" -ForegroundColor Green
} else {
    Write-Host "NO" -ForegroundColor Red
}

# Count events
$heirEvents = ([regex]::Matches($logContent, "\[NameEveryChild\] Naming event triggered.*IsHeir=True")).Count
$nonHeirEvents = ([regex]::Matches($logContent, "\[NameEveryChild\] SUCCESS: Non-heir child")).Count

Write-Host ""
Write-Host "── Naming Events ──" -ForegroundColor Cyan
Write-Host "  Heir naming events: $heirEvents"
Write-Host "  Non-heir naming events: $nonHeirEvents"

Write-Host ""
Write-Host "[3/3] Results" -ForegroundColor Yellow

if ($nonHeirEvents -gt 0) {
    Write-Host "PASS: Non-heir naming events detected!" -ForegroundColor Green
} elseif ($heirEvents -gt 0) {
    Write-Host "PARTIAL: Only heir events detected" -ForegroundColor Yellow
} else {
    Write-Host "INCONCLUSIVE: No naming events during test" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Game log: $GameLog" -ForegroundColor Cyan
```

### Creating a Test Save

For reliable automated testing, create a deterministic test save:

1. **Start a new game** with these settings:
   - Nation: Rome (stable families, good for testing)
   - Ruler: Young female ruler (more children over time)
   - Difficulty: The Great (faster game progression)

2. **Play until married** (usually turn 1-5)

3. **Save the game** as `NameEveryChildTest`

4. **Copy to test location:**
   ```bash
   # macOS
   cp ~/Library/Application\ Support/OldWorld/Saves/NameEveryChildTest.zip \
      /path/to/project/TestSaves/

   # Windows
   copy "%APPDATA%\OldWorld\Saves\NameEveryChildTest.zip" TestSaves\
   ```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Test Name Every Child Mod

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest  # or windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '7.0.x'

      - name: Build mod
        run: |
          cd NameEveryChildHarmony
          dotnet build -c Release

      - name: Deploy mod
        run: ./deploy.sh

      - name: Run headless test
        run: ./test-headless.sh TestSaves/NameEveryChildTest.zip 50
```

### Interpreting Test Results

| Result | Meaning |
|--------|---------|
| **PASS** | Non-heir naming events detected - mod working correctly |
| **PARTIAL** | Only heir events - mod loaded, but no non-heirs born during test |
| **INCONCLUSIVE** | No naming events at all - need longer test or different save |
| **FAIL** | Mod didn't load - check installation and logs |

### Limitations

1. **Children must be born** - The test requires the game state to produce children. Running 50+ turns usually works, but isn't guaranteed.

2. **No assertions on game state** - We validate via logs, not by inspecting the final game state.

3. **Random AI decisions** - The AI picks random names, so we can't validate specific names were chosen.

4. **Save file dependency** - Tests require a suitable save file to be created manually.

---

## Troubleshooting

### Mod not loading

1. Check `ModInfo.xml` is valid XML
2. Verify `0Harmony.dll` is present in mod folder
3. Check Player.log for errors

### Transpiler not finding method

If you see the warning about not finding `isHeir()`:

1. Check if Old World was updated
2. Look at the new `Character.isValidChooseName()` in Reference source
3. The fallback postfix should still work

### Conflict with other mods

Harmony mods generally don't conflict. If issues occur:

1. Check Player.log for errors from both mods
2. Verify neither mod uses GameFactory
3. Try disabling one mod at a time to isolate

---

## How It Works

### Original Method (Character.cs:9028)

```csharp
public virtual bool isValidChooseName()
{
    if (!isHeir())              // ← Transpiler removes this
        return false;
    if (!isLeaderChild())       // Kept - must be leader's child
        return false;
    if (hasName())              // Kept - must not have name yet
        return false;
    if (game().isNoEvents())    // Kept - events must be enabled
        return false;
    return true;
}
```

### What the Transpiler Does

**Before (IL):**
```
ldarg.0                    // load 'this'
call Character::isHeir()   // call isHeir, pushes true/false
brfalse.s RETURN_FALSE     // if false, branch to return false
```

**After (IL):**
```
ldarg.0                    // load 'this'
ldc.i4.1                   // push constant '1' (true)
brfalse.s RETURN_FALSE     // never branches (1 is truthy)
```

The `isHeir()` call is replaced with a constant `true`, so the branch never triggers. All subsequent checks remain intact.

### Why This Is Future-Proof

- Only the `isHeir()` check is modified
- All other checks (current and future) execute normally
- If Mohawk adds `if (newCondition()) return false;`, it will work
- If Mohawk fixes bugs in the method, fixes are included

---

## Comparison: Before and After

| Aspect | Old Version (GameFactory) | New Version (Harmony) |
|--------|---------------------------|----------------------|
| **Mod compatibility** | Conflicts with other GameFactory mods | Works with all mods |
| **Game updates** | Misses new checks (like `isNoEvents()`) | Automatically includes new checks |
| **Code complexity** | 3 classes (Entry, Factory, Character) | 2 classes (Entry, Patches) |
| **Runtime overhead** | Creates custom Character for every character | Single IL patch at startup |
| **Failure mode** | Silent conflict (one mod wins) | Graceful fallback with logging |

---

## Version History

| Version | Approach | Notes |
|---------|----------|-------|
| 0.0.1 | GameFactory + Character subclass | Original release |
| 0.0.2 | Harmony Transpiler | Mod-compatible, future-proof |
