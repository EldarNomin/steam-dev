using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace CosmicCatch.Editor
{
    public static class BuildCommands
    {
        public const string OutputPath = "Builds/Windows/CosmicCatch.exe";

        [MenuItem("Cosmic Catch/Build/Windows x64")]
        public static void BuildWindowsMenu()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode)
                throw new InvalidOperationException("Stop Play Mode before building.");
            if (EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
                BuildWindows();
        }

        public static void BuildWindowsBatch()
        {
            try
            {
                BuildWindows();
                EditorApplication.Exit(0);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                EditorApplication.Exit(1);
            }
        }

        private static void BuildWindows()
        {
            BaselineSetup.RequireEditorVersion();
            if (!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Standalone, BuildTarget.StandaloneWindows64))
                throw new InvalidOperationException("Install Windows Build Support (Mono) through Unity Hub.");
            var scenes = EditorBuildSettings.scenes.Where(scene => scene.enabled).Select(scene => scene.path).ToArray();
            if (scenes.Length == 0 || scenes[0] != BaselineSetup.BootScenePath || scenes.Any(path => !File.Exists(path)))
                throw new InvalidOperationException("Run Cosmic Catch > Setup > Create baseline; check build scene paths.");
            var pipeline = UnityEngine.Rendering.GraphicsSettings.defaultRenderPipeline;
            if (pipeline == null || AssetDatabase.GetAssetPath(pipeline) != BaselineSetup.PipelinePath)
                throw new InvalidOperationException("Baseline URP pipeline is not configured.");

            Directory.CreateDirectory(Path.GetDirectoryName(OutputPath));
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = scenes,
                locationPathName = OutputPath,
                target = BuildTarget.StandaloneWindows64,
                options = BuildOptions.None
            });
            Directory.CreateDirectory("Reports");
            var summary = report.summary;
            File.WriteAllText("Reports/windows-build.json", JsonUtility.ToJson(new BuildEvidence
            {
                editorVersion = Application.unityVersion,
                result = summary.result.ToString(),
                errors = summary.totalErrors,
                warnings = summary.totalWarnings,
                bytes = summary.totalSize,
                seconds = summary.totalTime.TotalSeconds,
                output = summary.outputPath,
                utc = DateTime.UtcNow.ToString("O")
            }, true));
            if (summary.result != BuildResult.Succeeded || !File.Exists(OutputPath))
                throw new InvalidOperationException($"Windows build failed: {summary.result}, errors: {summary.totalErrors}.");
            Debug.Log($"Windows build succeeded: {Path.GetFullPath(OutputPath)}");
        }

        [Serializable]
        private sealed class BuildEvidence
        {
            public string editorVersion;
            public string result;
            public int errors;
            public int warnings;
            public ulong bytes;
            public double seconds;
            public string output;
            public string utc;
        }
    }
}
