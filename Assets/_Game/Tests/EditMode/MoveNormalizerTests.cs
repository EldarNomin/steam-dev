using CosmicCatch.Player;
using NUnit.Framework;
using UnityEngine;

namespace CosmicCatch.Tests.EditMode
{
    public sealed class MoveNormalizerTests
    {
        [Test]
        public void DiagonalIsNotFasterThanStraight()
        {
            var result = MoveNormalizer.Normalize(new Vector2(1f, 1f));
            Assert.LessOrEqual(result.magnitude, 1f + 0.0001f,
                "diagonal input must be clamped to unit length");
            Assert.AreEqual(0.7071f, result.x, 0.001f);
            Assert.AreEqual(0.7071f, result.y, 0.001f);
        }

        [Test]
        public void ShortInputIsPreserved()
        {
            var input = new Vector2(0.3f, 0f);
            Assert.AreEqual(input, MoveNormalizer.Normalize(input),
                "partial input below unit length must be kept as-is");
        }

        [Test]
        public void ZeroStaysZero()
        {
            Assert.AreEqual(Vector2.zero, MoveNormalizer.Normalize(Vector2.zero));
        }

        [Test]
        public void SingleAxisIsNotRescaled()
        {
            var result = MoveNormalizer.Normalize(new Vector2(0f, 1f));
            Assert.AreEqual(new Vector2(0f, 1f), result);
        }
    }
}
