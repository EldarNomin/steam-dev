using UnityEngine;

namespace CosmicCatch.Player
{
    /// <summary>
    /// Pure gravity blending: linear interpolation from the value the gravity
    /// had when the target changed, reaching the new target exactly after the
    /// configured window (balance: gravityBlendSeconds).
    /// </summary>
    public sealed class GravityBlender
    {
        private readonly float blendSeconds;
        private float from;
        private float to;
        private float current;
        private float elapsed;

        public GravityBlender(float blendSeconds)
        {
            this.blendSeconds = Mathf.Max(0.0001f, blendSeconds);
        }

        public float Current => current;

        public void Reset(float gravity)
        {
            from = to = current = gravity;
            elapsed = 0f;
        }

        /// <summary>Advances the blend by dt; hits the target exactly when the window elapses.</summary>
        public float Advance(float targetGravity, float dt)
        {
            if (!Mathf.Approximately(targetGravity, to))
            {
                from = current;
                to = targetGravity;
                elapsed = 0f;
            }
            elapsed += dt;
            current = Mathf.Lerp(from, to, Mathf.Clamp01(elapsed / blendSeconds));
            return current;
        }
    }
}
