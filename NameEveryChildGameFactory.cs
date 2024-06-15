using TenCrowns.GameCore;

namespace NameEveryChild
{
    internal class NameEveryChildGameFactory : GameFactory
    {
        public NameEveryChildGameFactory() : base()
        {
            return;
        }

        public override Character CreateCharacter()
        {
            return (Character)new NameEveryChildCharacter();
        }
    }
}