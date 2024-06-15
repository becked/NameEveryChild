using TenCrowns.AppCore;
using TenCrowns.GameCore;
using UnityEngine;

namespace NameEveryChild
{
    public class NameEveryChild : ModEntryPointAdapter
    {
        public override void Initialize(ModSettings modSettings)
        {
            Debug.Log((object)"NameEveryChild DLL initializing.");
            base.Initialize(modSettings);
            modSettings.Factory = new NameEveryChildGameFactory();
            Debug.Log((object)"NameEveryChild DLL initialization complete.");
        }
    }
}