using CosmicCatch.Interaction;
using CosmicCatch.Player;
using UnityEngine;

namespace CosmicCatch.Presentation
{
    /// <summary>
    /// Compact station HUD: crosshair, interaction prompt and terminal replies.
    /// Replaces the DEV-001 full-screen overlay so prompts stay readable.
    /// </summary>
    public sealed class StationHud : MonoBehaviour
    {
        [Tooltip("Interactor providing the current target.")]
        public Interactor interactor;

        private string reply;
        private float replyUntil;
        private GUIStyle promptStyle;
        private GUIStyle replyStyle;
        private GUIStyle titleStyle;

        private Terminal terminal;

        private void OnEnable()
        {
            terminal = FindFirstObjectByType<Terminal>();
            if (terminal != null)
                terminal.Replied += ShowReply;
        }

        private void OnDisable()
        {
            if (terminal != null)
                terminal.Replied -= ShowReply;
        }

        private void ShowReply(string text)
        {
            reply = text;
            replyUntil = Time.unscaledTime + (terminal != null ? terminal.replySeconds : 2f);
        }

        private void OnGUI()
        {
            if (promptStyle == null)
            {
                promptStyle = new GUIStyle(GUI.skin.box) { alignment = TextAnchor.MiddleCenter, fontSize = 18 };
                replyStyle = new GUIStyle(GUI.skin.box) { alignment = TextAnchor.MiddleCenter, fontSize = 20 };
                titleStyle = new GUIStyle(GUI.skin.label)
                {
                    fontSize = 20, fontStyle = FontStyle.Bold, normal = { textColor = new Color(0.85f, 0.98f, 0.96f) }
                };
            }

            GUI.Label(new Rect(14, 10, 260, 26), "КОСМОЛОВ", titleStyle);

            var center = new Vector2(Screen.width / 2f, Screen.height / 2f);
            GUI.Box(new Rect(center.x - 2, center.y - 2, 4, 4), GUIContent.none);

            var target = interactor != null ? interactor.CurrentTarget : null;
            if (target != null)
            {
                var prompt = $"E — {target.DisplayName}";
                var size = promptStyle.CalcSize(new GUIContent(prompt));
                var rect = new Rect(center.x - size.x / 2f, center.y + 28f, size.x, size.y);
                GUI.Box(rect, prompt, promptStyle);
            }

            if (!string.IsNullOrEmpty(reply) && Time.unscaledTime < replyUntil)
            {
                var size = replyStyle.CalcSize(new GUIContent(reply));
                var rect = new Rect(center.x - size.x / 2f, center.y - 76f, size.x, size.y);
                GUI.Box(rect, reply, replyStyle);
            }
        }
    }
}
