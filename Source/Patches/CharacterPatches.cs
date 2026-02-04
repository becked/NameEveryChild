using HarmonyLib;
using TenCrowns.GameCore;

namespace NameEveryChild.Patches
{
    [HarmonyPatch(typeof(Character), nameof(Character.isValidChooseName))]
    public static class CharacterPatches
    {
        static void Postfix(Character __instance, ref bool __result)
        {
            // If already true (heir case), nothing to do
            if (__result) return;

            try
            {
                // Null safety for threading contexts
                var game = __instance?.game();
                if (game == null) return;

                // Allow naming for non-heir leader's children
                // Replicates all original checks except isHeir()
                if (__instance.isLeaderChild() &&
                    !__instance.hasName() &&
                    !game.isNoEvents())
                {
                    __result = true;
                }
            }
            catch
            {
                // Silently ignore exceptions in patch to avoid crashing game
            }
        }
    }
}
