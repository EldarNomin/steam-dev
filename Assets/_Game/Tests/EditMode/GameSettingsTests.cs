using CosmicCatch.Settings;
using NUnit.Framework;
using System.IO;
using UnityEngine;

namespace CosmicCatch.Tests.EditMode
{
    public sealed class GameSettingsTests
    {
        private string backup;
        private string path;
        private bool hasBackup;

        [SetUp]
        public void SetUp()
        {
            path = Path.Combine(Application.persistentDataPath, "settings.json");
            hasBackup = File.Exists(path);
            if (hasBackup)
                backup = File.ReadAllText(path);
            if (File.Exists(path))
                File.Delete(path);
        }

        [TearDown]
        public void TearDown()
        {
            if (hasBackup)
                File.WriteAllText(path, backup);
            else if (File.Exists(path))
                File.Delete(path);
        }

        [Test]
        public void SavedValuesSurviveReload()
        {
            var settings = new GameSettings { mouseSensitivity = 1.7f, invertY = true, masterVolume = 0.35f };
            settings.Save();

            GameSettings.ReloadAndApply();
            var reloaded = GameSettings.Current;
            Assert.AreEqual(1.7f, reloaded.mouseSensitivity, 0.001f);
            Assert.IsTrue(reloaded.invertY);
            Assert.AreEqual(0.35f, reloaded.masterVolume, 0.001f);
        }

        [Test]
        public void MissingFileYieldsDefaults()
        {
            var settings = GameSettings.LoadOrDefault();
            Assert.AreEqual(1f, settings.mouseSensitivity, 0.001f);
            Assert.IsFalse(settings.invertY);
            Assert.AreEqual(1f, settings.masterVolume, 0.001f);
        }
    }
}
