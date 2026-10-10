using UnityEngine;

namespace CosmicCatch.Interaction
{
    /// <summary>
    /// A world object the player can interact with. Terminal now, cargo
    /// containers and creatures later; keep implementations small.
    /// </summary>
    public abstract class InteractionTarget : MonoBehaviour
    {
        /// <summary>Verb shown in the prompt after "E — ".</summary>
        public abstract string DisplayName { get; }

        /// <summary>Performs one interaction. Called once per press when allowed.</summary>
        public abstract void Interact(GameObject player);
    }
}
