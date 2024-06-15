using TenCrowns.GameCore;

namespace NameEveryChild
{
    internal class NameEveryChildCharacter : Character
    {
        public override bool isValidChooseName()
        {
            if (!isLeaderChild())
            {
                return false;
            }
            if (hasName())
            {
                return false;
            }
            return true;

        }
    }
}
