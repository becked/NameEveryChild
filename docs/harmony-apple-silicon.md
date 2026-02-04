# Harmony on Apple Silicon (M1/M2/M3 Macs)

This document describes how we got Harmony patching to work on Apple Silicon Macs for Old World modding.

## The Problem

Harmony is a .NET library for runtime method patching. On Apple Silicon Macs, older versions of Harmony fail with errors like:

```
System.Exception: mprotect returned EACCES
```

or

```
System.NotImplementedException: The method or operation is not implemented.
  at HarmonyLib.PatchFunctions.UpdateWrapper
```

This happens because:
1. Harmony relies on MonoMod for low-level memory manipulation
2. Older MonoMod versions don't support Apple Silicon's ARM64 architecture
3. macOS enforces W^X (Write XOR Execute) memory protection that older patching code can't handle

## The Solution

**Use Harmony 2.4.2 or newer.**

Harmony 2.4+ includes native ARM64/Apple Silicon support. No special patches, workarounds, or Rosetta emulation needed.

```xml
<!-- In your .csproj -->
<PackageReference Include="Lib.Harmony" Version="2.4.2" />
```

## What We Tried (and why it didn't work)

### Attempt 1: Harmony 2.3.3 (net472)
- **Error**: `NotImplementedException` in `PatchFunctions.UpdateWrapper`
- **Cause**: Harmony 2.3.x uses MonoMod.Core which has compatibility issues with Unity's Mono runtime

### Attempt 2: Harmony 2.2.2 (net472)
- **Error**: `mprotect returned EACCES`
- **Cause**: Harmony 2.2.x lacks ARM64 support entirely

### Attempt 3: Harmony 2.2.2 (net6.0 build)
- **Error**: `ReflectionTypeLoadException`
- **Cause**: Unity's Mono runtime can't load .NET 6 assemblies

### Attempt 4: Apple Silicon Harmony Patch (anatawa12)
- **Package**: [AppleSiliconHarmony](https://github.com/anatawa12/AppleSiliconHarmony)
- **Problem**: Requires calling `Patcher.Patch()` before Harmony loads, but Old World's mod loader loads all DLLs automatically in alphabetical order
- **Also**: Only works when Hardened Runtime is disabled (Old World has it enabled)

### Attempt 5: Harmony 2.4.2 (net472)
- **Result**: Works!
- Harmony 2.4+ has native ARM64 support built-in

## Additional Fix: Null Safety in Patches

Old World uses parallel processing for event evaluation. Harmony patches can be called from multiple threads, and game objects may not always be fully initialized. Add null checks and try-catch:

```csharp
[HarmonyPatch(typeof(Character), nameof(Character.isValidChooseName))]
public static class CharacterPatches
{
    static void Postfix(Character __instance, ref bool __result)
    {
        if (__result) return;

        try
        {
            var game = __instance?.game();
            if (game == null) return;

            // Your patch logic here
        }
        catch
        {
            // Silently ignore to avoid crashing the game
        }
    }
}
```

## Version Compatibility Summary

| Harmony Version | net472 (Framework) | Apple Silicon | Notes |
|-----------------|-------------------|---------------|-------|
| 2.2.x | Works on Intel | Fails | mprotect EACCES |
| 2.3.x | Problematic | Fails | MonoMod.Core issues |
| **2.4.x** | **Works** | **Works** | **Recommended** |

## References

- [Harmony GitHub](https://github.com/pardeike/Harmony)
- [Harmony Issue #424 - Apple Silicon](https://github.com/pardeike/Harmony/issues/424)
- [MonoMod Issue #90 - Apple Silicon Support](https://github.com/MonoMod/MonoMod/issues/90)
- [Harmony 2.4 Release Notes](https://github.com/pardeike/Harmony/releases/tag/v2.4.0)
