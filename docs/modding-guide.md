# Old World C# Modding Guide

This guide explains how to create C# mods for Old World, the historical strategy game by Mohawk Games.

**Authoritative external resource**: [dales.world](https://dales.world) has excellent tutorials on Old World modding.

## Prerequisites

- **.NET SDK** (supports .NET Framework 4.7.2)
- **Old World** installed via Steam, Epic, or GOG
- **IDE** - Visual Studio, VS Code, or JetBrains Rider
- Basic C# knowledge

## Two Approaches to Modifying Game Behavior

Old World supports two approaches for modifying game logic with C#:

| Approach | Best For | Multi-Mod Compatible? |
|----------|----------|----------------------|
| **GameFactory Override** | Total conversion mods, scenarios | No - only one mod can use this |
| **Harmony Patching** | Targeted behavior changes | Yes - if mods patch different methods |

### Quick Decision Guide

- **Use GameFactory Override** if you're creating a scenario or total conversion and need to replace entire classes (Player, PlayerAI, City, etc.)
- **Use Harmony Patching** if you want to modify specific methods while remaining compatible with other mods

---

## Project Structure

A minimal Old World mod requires:

```
MyMod/
├── Source/
│   └── MyMod.cs          # Your mod entry point
├── MyMod.csproj          # Project file
├── ModInfo.xml           # Mod manifest (required)
├── 0Harmony.dll          # Only if using Harmony (copy to mod folder)
└── .env                  # Local config (gitignored)
```

## Step 1: Create the Project File

Create `MyMod.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net472</TargetFramework>
    <AssemblyName>MyMod</AssemblyName>
    <RootNamespace>MyMod</RootNamespace>
    <LangVersion>9.0</LangVersion>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
    <AppendTargetFrameworkToOutputPath>false</AppendTargetFrameworkToOutputPath>
    <OutputPath>bin/</OutputPath>
  </PropertyGroup>

  <!-- Platform-specific paths to game assemblies -->
  <PropertyGroup Condition="$([MSBuild]::IsOSPlatform('Windows'))">
    <OldWorldManagedPath>$(OldWorldPath)\OldWorld_Data\Managed</OldWorldManagedPath>
  </PropertyGroup>
  <PropertyGroup Condition="$([MSBuild]::IsOSPlatform('OSX'))">
    <OldWorldManagedPath>$(OldWorldPath)/OldWorld.app/Contents/Resources/Data/Managed</OldWorldManagedPath>
  </PropertyGroup>
  <PropertyGroup Condition="$([MSBuild]::IsOSPlatform('Linux'))">
    <OldWorldManagedPath>$(OldWorldPath)/OldWorld_Data/Managed</OldWorldManagedPath>
  </PropertyGroup>

  <ItemGroup>
    <Compile Include="Source/**/*.cs" />
  </ItemGroup>

  <!-- Reference Old World assemblies -->
  <ItemGroup>
    <Reference Include="TenCrowns.GameCore">
      <HintPath>$(OldWorldManagedPath)/TenCrowns.GameCore.dll</HintPath>
      <Private>false</Private>
    </Reference>
    <Reference Include="UnityEngine">
      <HintPath>$(OldWorldManagedPath)/UnityEngine.dll</HintPath>
      <Private>false</Private>
    </Reference>
    <Reference Include="UnityEngine.CoreModule">
      <HintPath>$(OldWorldManagedPath)/UnityEngine.CoreModule.dll</HintPath>
      <Private>false</Private>
    </Reference>
    <Reference Include="Mohawk.SystemCore">
      <HintPath>$(OldWorldManagedPath)/Mohawk.SystemCore.dll</HintPath>
      <Private>false</Private>
    </Reference>
  </ItemGroup>

  <!-- Add Harmony if using it -->
  <ItemGroup Condition="Exists('lib/0Harmony.dll')">
    <Reference Include="0Harmony">
      <HintPath>lib/0Harmony.dll</HintPath>
      <Private>true</Private>
    </Reference>
  </ItemGroup>

</Project>
```

**Important**: The `OldWorldPath` environment variable must be set when building. See the build section below.

## Step 2: Create ModInfo.xml

Every mod needs a `ModInfo.xml` manifest:

```xml
<?xml version="1.0"?>
<ModInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <displayName>My Awesome Mod</displayName>
  <description>Description of what your mod does.</description>
  <author>YourName</author>
  <modversion>1.0.0</modversion>
  <modbuild>1.0.81098</modbuild>
  <tags>GameInfo</tags>
  <singlePlayer>true</singlePlayer>
  <multiplayer>false</multiplayer>
  <scenario>false</scenario>
  <scenarioToggle>false</scenarioToggle>
  <blocksMods>false</blocksMods>
  <modDependencies />
  <modIncompatibilities />
  <modWhitelist />
  <gameContentRequired>NONE</gameContentRequired>
</ModInfo>
```

### Key Fields

| Field | Description |
|-------|-------------|
| `displayName` | Shown in the Mod Manager |
| `description` | Supports Steam BBCode formatting |
| `modversion` | Semantic version (e.g., 1.0.0) |
| `modbuild` | Game version this was built for |
| `singlePlayer` | Enable for single-player games |
| `multiplayer` | Enable for multiplayer (requires careful design) |
| `blocksMods` | If true, prevents other mods from loading |

---

## Approach 1: GameFactory Override (Exclusive)

The GameFactory pattern lets you replace entire game classes. This is how official scenarios (like Greece3) work.

**Limitation**: Only ONE mod can use this approach at a time.

### How It Works

1. Create a custom `GameFactory` that overrides creation methods
2. Create custom classes that inherit from base game classes
3. The game uses your factory to instantiate all objects

### Example: Custom PlayerAI

```csharp
using TenCrowns.GameCore;

namespace MyMod
{
    // Custom GameFactory
    public class MyModGameFactory : GameFactory
    {
        public override Player.PlayerAI CreatePlayerAI()
        {
            return new MyModPlayerAI();
        }

        // Override other creation methods as needed:
        // CreatePlayer(), CreateCity(), CreateUnit(), CreateUnitAI(), etc.
    }

    // Custom PlayerAI with overridden behavior
    public class MyModPlayerAI : Player.PlayerAI
    {
        public override int getWarOfferPercent(PlayerType eOtherPlayer,
            bool bDeclare = true, bool bPreparedOnly = false, bool bCurrentPlayer = true)
        {
            // Your custom logic here
            int basePercent = base.getWarOfferPercent(eOtherPlayer, bDeclare, bPreparedOnly, bCurrentPlayer);

            // Example: boost AI-vs-AI war chance
            Player pOtherPlayer = game.player(eOtherPlayer);
            if (!pOtherPlayer.isHuman() && basePercent > 0 && bDeclare)
            {
                basePercent = basePercent * 3 / 2;  // +50%
            }

            return infos.utils().range(basePercent, 0, 100);
        }
    }
}
```

### Registering Your Factory

In your mod entry point, set the factory on ModSettings:

```csharp
public override void Initialize(ModSettings modSettings)
{
    base.Initialize(modSettings);
    modSettings.Factory = new MyModGameFactory();
}
```

### Available Factory Methods

| Method | Creates |
|--------|---------|
| `CreateGame()` | Game instance |
| `CreatePlayer()` | Player instance |
| `CreatePlayerAI()` | Player.PlayerAI instance |
| `CreateCity()` | City instance |
| `CreateUnit()` | Unit instance |
| `CreateUnitAI()` | Unit.UnitAI instance |
| `CreateTile()` | Tile instance |
| `CreateClientUI()` | ClientUI instance |
| `CreateInfoHelpers()` | InfoHelpers instance |
| `CreateHelpText()` | HelpText instance |

See `Reference/Source/Mods/Greece3/` for a complete example.

---

## Approach 2: Harmony Patching (Recommended for Compatibility)

Harmony is a third-party .NET library that patches methods at runtime without replacing entire classes. Multiple Harmony mods can coexist if they patch different methods.

**Reference**: See [dales.world/HarmonyDLLs.html](https://dales.world/HarmonyDLLs.html) for detailed tutorial.

### Setup

1. Download Harmony from [GitHub](https://github.com/pardeike/Harmony) or NuGet
2. Copy `0Harmony.dll` to your mod folder
3. Reference it in your project

### Basic Structure

```csharp
using HarmonyLib;
using TenCrowns.AppCore;
using TenCrowns.GameCore;
using UnityEngine;

namespace MyMod
{
    public class MyMod : ModEntryPointAdapter
    {
        private Harmony _harmony;

        public override void Initialize(ModSettings modSettings)
        {
            base.Initialize(modSettings);

            // Create Harmony instance with unique ID
            _harmony = new Harmony("yourname.mymod.patch");

            // Apply all patches in this assembly
            _harmony.PatchAll();

            Debug.Log("[MyMod] Harmony patches applied");
        }

        public override void Shutdown()
        {
            // Remove patches on shutdown
            _harmony?.UnpatchSelf();
            base.Shutdown();
        }

        public override bool CallOnGUI() => false;
    }
}
```

### Patch Types

#### Prefix - Runs BEFORE the original method

```csharp
[HarmonyPatch(typeof(Player.PlayerAI), nameof(Player.PlayerAI.getWarOfferPercent))]
public class WarOfferPatch
{
    // Return false to skip the original method entirely
    // __instance is the object the method is called on
    static bool Prefix(Player.PlayerAI __instance, PlayerType eOtherPlayer, ref int __result)
    {
        // Example: Force 100% war chance against specific nation
        if (__instance.game.player(eOtherPlayer).getNation() == NationType.ROME)
        {
            __result = 100;
            return false;  // Skip original method
        }
        return true;  // Run original method
    }
}
```

#### Postfix - Runs AFTER the original method

```csharp
[HarmonyPatch(typeof(Player.PlayerAI), nameof(Player.PlayerAI.getWarOfferPercent))]
public class WarOfferPatch
{
    // __result is the return value (use ref to modify it)
    static void Postfix(Player.PlayerAI __instance, PlayerType eOtherPlayer,
        bool bDeclare, ref int __result)
    {
        // Only modify AI-vs-AI, not AI-vs-human
        Player pOtherPlayer = __instance.game.player(eOtherPlayer);
        if (pOtherPlayer.isHuman())
            return;

        // Undo declaration penalty for AI targets
        if (__result > 0 && bDeclare)
        {
            __result = __result * 3 / 2;
            __result = Math.Min(__result, 100);
        }
    }
}
```

### Patching Methods with Parameters

Specify parameter types to patch overloaded methods:

```csharp
[HarmonyPatch(typeof(Player.PlayerAI),
    nameof(Player.PlayerAI.getWarOfferPercent),
    new Type[] { typeof(PlayerType), typeof(bool), typeof(bool), typeof(bool) })]
public class WarOfferPlayerPatch
{
    static void Postfix(ref int __result) { /* ... */ }
}

// Different overload for tribes
[HarmonyPatch(typeof(Player.PlayerAI),
    nameof(Player.PlayerAI.getWarOfferPercent),
    new Type[] { typeof(TribeType) })]
public class WarOfferTribePatch
{
    static void Postfix(ref int __result) { /* ... */ }
}
```

### Harmony Limitations

- Only ONE mod can patch any specific method - conflicts occur otherwise
- Patches are applied at runtime, so errors may not appear until the method is called
- Debugging can be tricky - use liberal logging

---

## Step 3: Create the Entry Point

Your mod must extend `ModEntryPointAdapter`. Create `Source/MyMod.cs`:

```csharp
using System;
using TenCrowns.AppCore;
using TenCrowns.GameCore;
using UnityEngine;

namespace MyMod
{
    public class MyMod : ModEntryPointAdapter
    {
        public override void Initialize(ModSettings modSettings)
        {
            base.Initialize(modSettings);
            Debug.Log("[MyMod] Initialized!");
        }

        public override void Shutdown()
        {
            Debug.Log("[MyMod] Shutting down");
            base.Shutdown();
        }

        public override void OnGameServerReady()
        {
            Debug.Log("[MyMod] Game started or loaded");
        }

        public override void OnNewTurnServer()
        {
            Debug.Log("[MyMod] New turn started");
        }

        public override void OnClientUpdate()
        {
            // Called every frame - use sparingly!
        }

        public override bool CallOnGUI()
        {
            return false; // Return true if you need OnGUI callbacks
        }
    }
}
```

## Available Lifecycle Hooks

| Method | When Called | Use Case |
|--------|-------------|----------|
| `Initialize()` | Mod loaded | Setup, Harmony patches, factory registration |
| `Shutdown()` | Mod unloaded | Cleanup, unpatch Harmony |
| `OnGameServerReady()` | Game starts/loads | Initialize game-dependent state |
| `OnNewTurnServer()` | Turn ends | React to game state changes |
| `OnClientUpdate()` | Every frame | Continuous processing (use sparingly) |
| `OnGUI()` | GUI render (if enabled) | Custom UI |

---

## Accessing Game Data

### The Assembly-CSharp Constraint

**Critical**: Old World explicitly blocks mods from directly referencing `Assembly-CSharp.dll`. This means you cannot access `AppMain.gApp.Client.Game` directly.

**Solution**: Use runtime reflection to access these types.

```csharp
using System;
using System.Reflection;
using TenCrowns.GameCore;
using UnityEngine;

public partial class MyMod : ModEntryPointAdapter
{
    private static Type _appMainType;
    private static FieldInfo _gAppField;
    private static PropertyInfo _clientProperty;
    private static PropertyInfo _gameProperty;
    private static bool _reflectionInitialized;

    private void InitializeReflection()
    {
        if (_reflectionInitialized) return;

        foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
        {
            if (assembly.GetName().Name == "Assembly-CSharp")
            {
                _appMainType = assembly.GetType("AppMain");
                break;
            }
        }

        if (_appMainType != null)
        {
            _gAppField = _appMainType.GetField("gApp",
                BindingFlags.Public | BindingFlags.Static);
            _clientProperty = _appMainType.GetProperty("Client",
                BindingFlags.Public | BindingFlags.Instance);

            if (_clientProperty != null)
            {
                var clientType = _clientProperty.PropertyType;
                _gameProperty = clientType.GetProperty("Game",
                    BindingFlags.Public | BindingFlags.Instance);
            }
        }

        _reflectionInitialized = true;
    }

    private Game GetGame()
    {
        InitializeReflection();

        var appMain = _gAppField?.GetValue(null);
        if (appMain == null) return null;

        var client = _clientProperty?.GetValue(appMain);
        if (client == null) return null;

        return _gameProperty?.GetValue(client) as Game;
    }
}
```

### Working with Game Types

Once you have a `Game` instance, you can access game data through `TenCrowns.GameCore`:

```csharp
public override void OnNewTurnServer()
{
    Game game = GetGame();
    if (game == null) return;

    // Basic game info
    int turn = game.getTurn();
    int year = game.getYear();

    // Access game data definitions
    Infos infos = game.infos();

    // Iterate players
    foreach (Player player in game.getPlayers())
    {
        if (player == null) continue;

        // Get nation name (use mzType for string identifiers)
        string nation = infos.nation(player.getNation()).mzType;  // "NATION_ROME"

        // Get resources
        int food = player.getYieldStockpileWhole(infos.Globals.YIELD_FOOD);
        int gold = player.getYieldStockpileWhole(infos.Globals.YIELD_MONEY);

        Debug.Log($"[MyMod] {nation}: Food={food}, Gold={gold}");
    }
}
```

### String Identifiers with mzType

Game enums return numeric values when using `.ToString()`. To get human-readable identifiers, use the `mzType` field on Info objects:

```csharp
Infos infos = game.infos();

// Get yield name
YieldType yieldType = infos.Globals.YIELD_FOOD;
string yieldName = infos.yield(yieldType).mzType;  // "YIELD_FOOD"

// Get nation name
NationType nation = player.getNation();
string nationName = infos.nation(nation).mzType;  // "NATION_ROME"
```

---

## Building Your Mod

### Environment Setup

Create a `.env` file (don't commit this):

```bash
# macOS
OLDWORLD_PATH="$HOME/Library/Application Support/Steam/steamapps/common/Old World"
OLDWORLD_MODS_PATH="$HOME/Library/Application Support/OldWorld/Mods"

# Windows
OLDWORLD_PATH="C:\Program Files (x86)\Steam\steamapps\common\Old World"
OLDWORLD_MODS_PATH="%USERPROFILE%\Documents\My Games\OldWorld\Mods"

# Linux
OLDWORLD_PATH="$HOME/.steam/steam/steamapps/common/Old World"
OLDWORLD_MODS_PATH="$HOME/.local/share/OldWorld/Mods"
```

### Build Script (macOS/Linux)

Create `deploy.sh`:

```bash
#!/bin/bash
set -e

source .env

MOD_DIR="$OLDWORLD_MODS_PATH/MyMod"

echo "Building..."
export OldWorldPath="$OLDWORLD_PATH"
dotnet build -c Release

echo "Deploying..."
mkdir -p "$MOD_DIR"
cp ModInfo.xml "$MOD_DIR/"
cp bin/MyMod.dll "$MOD_DIR/"

# Copy Harmony if using it
if [ -f "lib/0Harmony.dll" ]; then
    cp lib/0Harmony.dll "$MOD_DIR/"
fi

echo "Done! Enable the mod in Old World's Mod Manager."
```

### Build Script (Windows PowerShell)

Create `deploy.ps1`:

```powershell
$ErrorActionPreference = "Stop"

# Load .env
Get-Content .env | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $name = $matches[1]
        $value = $matches[2] -replace '^"(.*)"$', '$1'
        $value = [Environment]::ExpandEnvironmentVariables($value)
        Set-Item -Path "Env:$name" -Value $value
    }
}

$ModDir = "$env:OLDWORLD_MODS_PATH\MyMod"

Write-Host "Building..."
$env:OldWorldPath = $env:OLDWORLD_PATH
dotnet build -c Release

Write-Host "Deploying..."
New-Item -ItemType Directory -Force -Path $ModDir | Out-Null
Copy-Item ModInfo.xml $ModDir
Copy-Item bin\MyMod.dll $ModDir

# Copy Harmony if using it
if (Test-Path "lib\0Harmony.dll") {
    Copy-Item lib\0Harmony.dll $ModDir
}

Write-Host "Done!"
```

---

## Testing Your Mod

### Manual Testing

1. Run `./deploy.sh` (or `.\deploy.ps1` on Windows)
2. Launch Old World
3. Go to **Mod Manager** and enable your mod
4. Start or load a game
5. Check the game log for your debug messages

### Log Location

- **Windows**: `%USERPROFILE%\AppData\LocalLow\Mohawk Games\Old World\Player.log`
- **macOS**: `~/Library/Logs/Mohawk Games/Old World/Player.log`
- **Linux**: `~/.config/unity3d/Mohawk Games/Old World/Player.log`

### Headless Mode Testing

Old World supports headless mode for automated testing:

```bash
# macOS
"/path/to/Old World/OldWorld.app/Contents/MacOS/OldWorld" \
    -batchmode -nographics \
    "/path/to/save.zip" \
    -turns 2

# Windows
"C:\path\to\Old World\OldWorld.exe" ^
    -batchmode -nographics ^
    "C:\path\to\save.zip" ^
    -turns 2
```

---

## Common Patterns

### Null Safety

Always check for null when accessing game objects:

```csharp
Game game = GetGame();
if (game == null) return;

// Skip null entries in arrays
foreach (Player player in game.getPlayers())
{
    if (player == null) continue;
    // process player...
}
```

### Caching for Performance

Cache reflection results and frequently accessed data:

```csharp
private static bool _reflectionInitialized;
private static volatile Game _cachedGame;
private Infos _cachedInfos;
```

---

## Tips and Gotchas

1. **Never reference Assembly-CSharp directly** - Use reflection as shown above

2. **Game may be null** - During menus, loading screens, or between sessions

3. **Use mzType for strings** - Enum `.ToString()` returns numbers

4. **Shutdown doesn't mean stopped** - Servers/threads you start may persist

5. **GameFactory is exclusive** - Only one mod can override it

6. **Harmony patches stack** - But only one mod per method

7. **Check the game source** - `Reference/Source/` contains decompiled code for reference

8. **Test compatibility** - If using Harmony, test with other popular mods

---

## Further Resources

- **[dales.world](https://dales.world)** - Authoritative Old World modding tutorials
  - [Putting It All Together](https://dales.world/PuttingAllTogether.html) - GameFactory approach
  - [Harmony DLLs](https://dales.world/HarmonyDLLs.html) - Harmony patching guide
- **Old World Discord** - Official modding support channel
- **Reference Source** - `Reference/Source/` in game folder contains decompiled code
- **Example Mods** - `Reference/Source/Mods/Greece3/` shows complete scenario mod
