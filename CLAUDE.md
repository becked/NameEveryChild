# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Name Every Child is a mod for the game Old World (by Mohawk Games). It triggers the child naming event for ALL leader's children, not just the heir. The mod uses Harmony patching to modify `Character.isValidChooseName()` at runtime.

## Build Commands

```bash
# Set the game path environment variable first
export OldWorldPath="$HOME/Library/Application Support/Steam/steamapps/common/Old World"

# Build
dotnet build -c Release

# Output: bin/NameEveryChild.dll
```

The `OldWorldPath` environment variable must point to the Old World installation directory. The csproj handles platform-specific paths to game assemblies.

## Architecture

- **NameEveryChildEntryPoint.cs** - Mod entry point extending `ModEntryPointAdapter`. Applies Harmony patches on `Initialize()` and removes them on `Shutdown()`.
- **Patches/CharacterPatches.cs** - Harmony postfix patch on `Character.isValidChooseName()`. Extends the original method to return `true` for non-heir leader's children.

The patch strategy:
1. Let the original method run
2. If it returns `false`, check if the character is a non-heir leader's child without a name
3. If so, override to `true` to trigger the naming event

## Key Technical Notes

- **Target framework**: .NET Framework 4.7.2 (Unity's Mono runtime)
- **Harmony version**: 2.4.2+ required for Apple Silicon Mac support
- **Thread safety**: Patches must handle null checks because Old World uses parallel processing for event evaluation
- **Game assemblies**: References `TenCrowns.GameCore.dll` for game types like `Character`, `Game`

## Deployment

After building, copy these files to the mod folder:
- `bin/NameEveryChild.dll`
- `0Harmony.dll` (from NuGet packages: `~/.nuget/packages/lib.harmony/2.4.2/lib/net472/`)
- `ModInfo.xml`

Mod folder locations:
- macOS: `~/Library/Application Support/OldWorld/Mods/Name Every Child/`
- Windows: `%APPDATA%\OldWorld\Mods\Name Every Child\`

## Log Files

Check for `[NameEveryChild]` messages in:
- macOS: `~/Library/Logs/Mohawk Games/Old World/Player.log`
- Windows: `%USERPROFILE%\AppData\LocalLow\Mohawk Games\Old World\Player.log`
