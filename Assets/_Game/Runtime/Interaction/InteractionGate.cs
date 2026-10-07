using UnityEngine;

namespace CosmicCatch.Interaction
{
    /// <summary>
    /// Pure reach/occlusion decision for interaction, testable without physics:
    /// distance gate plus an explicit "blocked" flag produced by the caller's
    /// raycast (a wall between the player and the target sets it).
    /// </summary>
    public static class InteractionGate
    {
        public const float MaxDistance = 2f;

        public static bool IsAllowed(float distance, bool blockedByObstacle)
        {
            return !blockedByObstacle && distance <= MaxDistance;
        }
    }
}
