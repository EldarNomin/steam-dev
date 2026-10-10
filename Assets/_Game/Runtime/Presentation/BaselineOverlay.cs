using UnityEngine;

namespace CosmicCatch.Presentation
{
    // Temporary station screen until the gameplay HUD is implemented.
    public sealed class BaselineOverlay : MonoBehaviour
    {
        private GUIStyle titleStyle;
        private GUIStyle bodyStyle;

        private void OnGUI()
        {
            if (titleStyle == null)
            {
                titleStyle = new GUIStyle(GUI.skin.label)
                {
                    fontSize = 36,
                    fontStyle = FontStyle.Bold,
                    wordWrap = true
                };
                bodyStyle = new GUIStyle(GUI.skin.label)
                {
                    fontSize = 18,
                    wordWrap = true
                };
            }

            var scale = Mathf.Min(Screen.width / 1280f, Screen.height / 720f);
            var previousMatrix = GUI.matrix;
            GUI.matrix = Matrix4x4.TRS(Vector3.zero, Quaternion.identity, Vector3.one * scale);
            GUI.Box(new Rect(28, 28, 480, 170), GUIContent.none);
            GUI.Label(new Rect(48, 40, 440, 52), "КОСМОЛОВ", titleStyle);
            GUI.Label(new Rect(48, 100, 430, 54),
                "Станция готовится к первому вылету.", bodyStyle);
            if (GUI.Button(new Rect(48, 157, 160, 28), "Выйти"))
                Application.Quit();
            GUI.matrix = previousMatrix;
        }
    }
}
