using System;
using HarmonyLib;
using TenCrowns.AppCore;
using TenCrowns.GameCore;
using UnityEngine;

namespace NameEveryChild
{
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
                Debug.Log("[NameEveryChild] Harmony patches applied");
            }
            catch (Exception ex)
            {
                Debug.LogError($"[NameEveryChild] Failed to apply patches: {ex}");
            }
        }

        public override void Shutdown()
        {
            _harmony?.UnpatchAll(HarmonyId);
            base.Shutdown();
        }
    }
}
