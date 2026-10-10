using CosmicCatch.Player;
using UnityEngine;

namespace CosmicCatch.Interaction
{
    /// <summary>
    /// Casts from the player camera each frame while gameplay input is allowed,
    /// tracks the single eligible target and fires exactly one Interact call
    /// per press. Obstacles between the player and the target block it.
    /// </summary>
    public sealed class Interactor : MonoBehaviour
    {
        [Tooltip("Camera the look direction is taken from.")]
        public Transform view;

        [Tooltip("Current eligible target and its distance, for HUD prompts.")]
        public InteractionTarget CurrentTarget { get; private set; }

        public float CurrentDistance { get; private set; }

        public bool InputAllowed { private get; set; } = true;

        private PlayerInputHub input;
        private int layerMask = ~0;

        /// <summary>Injected by the rig owner together with the controller.</summary>
        public void BindInput(PlayerInputHub playerInput)
        {
            input = playerInput;
        }

        public void IgnoreLayer(int layer)
        {
            layerMask &= ~(1 << layer);
        }

        private void Update()
        {
            if (view == null)
                return;
            CurrentTarget = FindTarget();

            if (InputAllowed && input != null && CurrentTarget != null && input.ConsumeInteract())
                CurrentTarget.Interact(gameObject);
        }

        private InteractionTarget FindTarget()
        {
            var ray = new Ray(view.position, view.forward);
            if (!Physics.Raycast(ray, out var hit, InteractionGate.MaxDistance + 1f, layerMask,
                QueryTriggerInteraction.Ignore))
                return null;

            // A collider that is not an InteractionTarget counts as an obstacle.
            var target = hit.collider.GetComponentInParent<InteractionTarget>();
            if (target == null)
                return null;
            CurrentDistance = hit.distance;
            return InteractionGate.IsAllowed(hit.distance, false) ? target : null;
        }
    }
}
