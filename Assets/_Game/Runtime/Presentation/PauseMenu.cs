using CosmicCatch.Player;
using CosmicCatch.Settings;
using UnityEngine;

namespace CosmicCatch.Presentation
{
    /// <summary>
    /// Esc menu with settings. While open, gameplay input is gated off by the
    /// rig and the cursor is free. Settings persist to persistentDataPath and
    /// are applied immediately and on next start.
    /// </summary>
    public sealed class PauseMenu : MonoBehaviour
    {
        private bool isOpen;
        private bool settingsOpen;
        private Rect windowRect;
        private GameSettings pending;
        private PlayerRig rig;

        public bool IsOpen => isOpen;

        private void Start()
        {
            rig = GetComponentInParent<PlayerRig>();
            windowRect = new Rect(0, 0, 380, 0);
        }

        private void Update()
        {
            if (rig == null || !rig.ConsumeMenuToggle())
                return;
            if (isOpen)
                Close();
            else
                Open();
        }

        private void Open()
        {
            isOpen = true;
            settingsOpen = false;
            pending = JsonUtility.FromJson<GameSettings>(JsonUtility.ToJson(GameSettings.Current));
            rig.SetMenuOpen(true);
        }

        private void Close()
        {
            isOpen = false;
            settingsOpen = false;
            rig.SetMenuOpen(false);
        }

        private void OnGUI()
        {
            if (!isOpen)
                return;
            windowRect.height = settingsOpen ? 240 : 170;
            windowRect.x = (Screen.width - windowRect.width) / 2f;
            windowRect.y = (Screen.height - windowRect.height) / 2f;
            GUILayout.Window(0, windowRect, DrawWindow, settingsOpen ? "Настройки" : "Меню");
        }

        private void DrawWindow(int id)
        {
            if (settingsOpen)
            {
                GUILayout.Label("Чувствительность мыши");
                pending.mouseSensitivity = GUILayout.HorizontalSlider(pending.mouseSensitivity, 0.05f, 3f);
                pending.invertY = GUILayout.Toggle(pending.invertY, "Инверсия оси Y");
                GUILayout.Label("Громкость");
                pending.masterVolume = GUILayout.HorizontalSlider(pending.masterVolume, 0f, 1f);
                if (GUILayout.Button("Сохранить"))
                {
                    GameSettings.Current.mouseSensitivity = pending.mouseSensitivity;
                    GameSettings.Current.invertY = pending.invertY;
                    GameSettings.Current.masterVolume = pending.masterVolume;
                    GameSettings.Current.Save();
                    GameSettings.Current.Apply();
                    settingsOpen = false;
                }
                if (GUILayout.Button("Назад"))
                    settingsOpen = false;
                return;
            }

            if (GUILayout.Button("Продолжить"))
                Close();
            if (GUILayout.Button("Настройки"))
                settingsOpen = true;
            if (GUILayout.Button("Выйти"))
            {
                #if UNITY_STANDALONE || UNITY_EDITOR
                Application.Quit();
                #endif
            }
        }
    }
}
