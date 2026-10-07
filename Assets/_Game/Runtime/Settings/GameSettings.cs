using System;
using System.IO;
using UnityEngine;

namespace CosmicCatch.Settings
{
    /// <summary>
    /// Player-facing settings persisted as JSON in persistentDataPath so they
    /// work in the standalone build the same way as in the Editor. No
    /// AssetDatabase/UnityEditor dependencies.
    /// </summary>
    [Serializable]
    public sealed class GameSettings
    {
        private const string FileName = "settings.json";

        [Range(0.05f, 3f)] public float mouseSensitivity = 1f;
        public bool invertY;
        [Range(0f, 1f)] public float masterVolume = 1f;

        private static GameSettings current;

        public static GameSettings Current
        {
            get
            {
                if (current == null)
                    current = LoadOrDefault();
                return current;
            }
        }

        private static string PathFor => Path.Combine(Application.persistentDataPath, FileName);

        public static GameSettings LoadOrDefault()
        {
            try
            {
                if (File.Exists(PathFor))
                {
                    var loaded = JsonUtility.FromJson<GameSettings>(File.ReadAllText(PathFor));
                    if (loaded != null)
                        return loaded;
                }
            }
            catch (Exception exception)
            {
                Debug.LogWarning($"Settings load failed, using defaults: {exception.Message}");
            }
            return new GameSettings();
        }

        public void Save()
        {
            try
            {
                Directory.CreateDirectory(Application.persistentDataPath);
                File.WriteAllText(PathFor, JsonUtility.ToJson(this, true));
            }
            catch (Exception exception)
            {
                Debug.LogWarning($"Settings save failed: {exception.Message}");
            }
        }

        /// <summary>Applies everything that has a live target (audio now, look is read on use).</summary>
        public void Apply()
        {
            AudioListener.volume = masterVolume;
        }

        public static void ReloadAndApply()
        {
            current = LoadOrDefault();
            current.Apply();
        }
    }
}
