using CosmicCatch.Interaction;
using NUnit.Framework;

namespace CosmicCatch.Tests.EditMode
{
    public sealed class InteractionGateTests
    {
        [Test]
        public void TargetWithinTwoMetersIsAllowed()
        {
            Assert.IsTrue(InteractionGate.IsAllowed(1.99f, false));
            Assert.IsTrue(InteractionGate.IsAllowed(2f, false));
        }

        [Test]
        public void TargetBeyondTwoMetersIsRejected()
        {
            Assert.IsFalse(InteractionGate.IsAllowed(2.01f, false),
                "interaction beyond the 2 m reach must be impossible");
        }

        [Test]
        public void ObstacleBlocksInteraction()
        {
            Assert.IsFalse(InteractionGate.IsAllowed(0.5f, true),
                "a wall between player and target must block the interaction");
        }
    }
}
