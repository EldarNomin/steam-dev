using UnityEngine;

namespace CosmicCatch.Player
{
    /// <summary>Pure input shaping shared by local and future networked play.</summary>
    public static class MoveNormalizer
    {
        /// <summary>Clamps the move vector to unit length so diagonals are not faster.</summary>
        public static Vector2 Normalize(Vector2 move)
        {
            var magnitude = move.magnitude;
            if (magnitude <= 1f)
                return move;
            return magnitude > 0f ? move / magnitude : Vector2.zero;
        }
    }
}
