using CosmicCatch.Player;
using NUnit.Framework;

namespace CosmicCatch.Tests.EditMode
{
    public sealed class GravityBlenderTests
    {
        private const float Epsilon = 0.0001f;

        [Test]
        public void ReachesLowGravityWithinBlendWindow()
        {
            var blender = new GravityBlender(0.3f);
            blender.Reset(9.81f);
            var current = 9.81f;
            for (var t = 0f; t < 0.3f; t += 0.05f)
                current = blender.Advance(3f, 0.05f);
            Assert.AreEqual(3f, current, Epsilon,
                "0.3 s after leaving the zone gravity must be exactly low gravity");
        }

        [Test]
        public void ReachesNormalGravityWithinBlendWindow()
        {
            var blender = new GravityBlender(0.3f);
            blender.Reset(3f);
            var current = 3f;
            for (var t = 0f; t < 0.3f; t += 0.03f)
                current = blender.Advance(9.81f, 0.03f);
            Assert.AreEqual(9.81f, current, Epsilon);
        }

        [Test]
        public void DoesNotOvershootTheTarget()
        {
            var blender = new GravityBlender(0.3f);
            blender.Reset(9.81f);
            var current = 9.81f;
            for (var i = 0; i < 10; i++)
                current = blender.Advance(3f, 0.3f); // long steps after the window
            Assert.AreEqual(3f, current, Epsilon, "blend must stop at the target, no endless flight");
        }

        [Test]
        public void PartialStepStaysBetweenEndpoints()
        {
            var blender = new GravityBlender(0.3f);
            blender.Reset(9.81f);
            var current = blender.Advance(3f, 0.15f);
            Assert.Greater(current, 3f);
            Assert.Less(current, 9.81f);
        }
    }
}
