using CosmicCatch.Player;
using UnityEngine;

namespace CosmicCatch.Player
{
    /// <summary>
    /// Trigger volume switching the player to low gravity. Visual marker is a
    /// translucent renderer; gameplay state is only the trigger itself.
    /// </summary>
    public sealed class LowGravityZone : MonoBehaviour
    {
        private void OnTriggerEnter(Collider other)
        {
            SetZone(other, true);
        }

        private void OnTriggerExit(Collider other)
        {
            SetZone(other, false);
        }

        private static void SetZone(Collider other, bool inside)
        {
            var controller = other.GetComponentInParent<FirstPersonController>();
            if (controller != null)
                controller.inLowGravityZone = inside;
        }
    }
}
