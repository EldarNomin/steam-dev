using UnityEngine;

namespace CosmicCatch.Interaction
{
    /// <summary>
    /// DEV-002 test terminal: answers with a short line, gives nothing, starts
    /// nothing. The reply is surfaced through the station HUD.
    /// </summary>
    public sealed class Terminal : InteractionTarget
    {
        public const string Reply = "Терминал готов";

        [Tooltip("Seconds the reply stays on screen.")]
        public float replySeconds = 2f;

        /// <summary>Raised with the reply text when used.</summary>
        public event System.Action<string> Replied;

        public override string DisplayName => "Проверить терминал";

        public override void Interact(GameObject player)
        {
            Replied?.Invoke(Reply);
        }
    }
}
