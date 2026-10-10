using System;
using System.Linq;
using CosmicCatch.Presentation;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CosmicCatch.Editor
{
    public static class BaselineSetup
    {
        public const string EditorVersion = "6000.3.25f1";
        public const string BootScenePath = "Assets/_Game/Scenes/Boot.unity";
        public const string PipelinePath = "Assets/_Game/Settings/CosmicCatchURP.asset";
        private const string RendererPath = "Assets/_Game/Settings/CosmicCatchRenderer.asset";

        [MenuItem("Cosmic Catch/Setup/Create baseline")]
        public static void SetupMenu()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode)
                throw new InvalidOperationException("Stop Play Mode before baseline setup.");
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
                return;
            CreateBaseline();
        }

        public static void SetupBatch()
        {
            try
            {
                CreateBaseline();
                EditorApplication.Exit(0);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                EditorApplication.Exit(1);
            }
        }

        private static void CreateBaseline()
        {
            RequireEditorVersion();
            var existingPipeline = GraphicsSettings.defaultRenderPipeline;
            if (existingPipeline != null && AssetDatabase.GetAssetPath(existingPipeline) != PipelinePath)
                throw new InvalidOperationException("An unrelated render pipeline is active. Configure it manually.");

            EnsureFolder("Assets/_Game/Settings");
            EnsureFolder("Assets/_Game/Scenes");
            ConfigurePipeline();
            ConfigureProject();

            // Keep GUIDs, references and all edits on subsequent runs.
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(BootScenePath) == null)
            {
                RequireEmptyPath(BootScenePath);
                CreateBootScene();
            }

            var otherScenes = EditorBuildSettings.scenes.Where(scene => scene.path != BootScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(BootScenePath, true) }
                .Concat(otherScenes).ToArray();
            AssetDatabase.SaveAssets();
            Debug.Log("Cosmic Catch baseline configured. Open Boot.unity and press Play to verify.");
        }

        public static void RequireEditorVersion()
        {
            if (Application.unityVersion != EditorVersion)
                throw new InvalidOperationException($"Use Unity {EditorVersion}; found {Application.unityVersion}.");
        }

        private static void ConfigurePipeline()
        {
            var pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath);
            if (pipeline == null)
            {
                RequireEmptyPath(PipelinePath);
                var renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(RendererPath);
                if (renderer == null)
                {
                    RequireEmptyPath(RendererPath);
                    renderer = ScriptableObject.CreateInstance<UniversalRendererData>();
                    AssetDatabase.CreateAsset(renderer, RendererPath);
                }
                pipeline = UniversalRenderPipelineAsset.Create(renderer);
                pipeline.name = "CosmicCatchURP";
                pipeline.msaaSampleCount = 2;
                pipeline.renderScale = 1f;
                AssetDatabase.CreateAsset(pipeline, PipelinePath);
            }
            GraphicsSettings.defaultRenderPipeline = pipeline;
            // The quality override otherwise takes precedence over Graphics Settings.
            var previousQuality = QualitySettings.GetQualityLevel();
            for (var index = 0; index < QualitySettings.names.Length; index++)
            {
                QualitySettings.SetQualityLevel(index, false);
                QualitySettings.renderPipeline = pipeline;
            }
            QualitySettings.SetQualityLevel(previousQuality, false);
        }

        private static void ConfigureProject()
        {
            EditorSettings.serializationMode = SerializationMode.ForceText;
            PlayerSettings.companyName = "Cosmic Catch";
            PlayerSettings.productName = "Cosmic Catch";
            PlayerSettings.bundleVersion = "0.1.0";
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.defaultScreenWidth = 1280;
            PlayerSettings.defaultScreenHeight = 720;
            PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Standalone, ScriptingImplementation.Mono2x);
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64,
                new[] { GraphicsDeviceType.Direct3D11 });
        }

        private static void CreateBootScene()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.24f, 0.3f, 0.4f);

            var hull = GetMaterial("Hull", new Color(0.18f, 0.23f, 0.3f));
            var accent = GetMaterial("Accent", new Color(0.15f, 0.8f, 0.72f));
            var creature = GetMaterial("Creature", new Color(0.94f, 0.43f, 0.2f));
            Primitive("Station platform", PrimitiveType.Cube, new Vector3(0, -0.25f, 0),
                new Vector3(18, 0.5f, 18), hull);
            Primitive("Ship hull", PrimitiveType.Cube, new Vector3(-4, 1.2f, 3),
                new Vector3(4, 2.4f, 5), hull);
            Primitive("Ship canopy", PrimitiveType.Cube, new Vector3(-4, 2.5f, 2),
                new Vector3(2.4f, 0.9f, 2.5f), accent);
            Primitive("Cargo terminal", PrimitiveType.Cube, new Vector3(4, 0.8f, 3),
                new Vector3(1.5f, 1.6f, 1.5f), accent);
            // Silhouette only; no capture or AI is implemented in DEV-001.
            Primitive("Crab body proxy", PrimitiveType.Sphere, new Vector3(0, 0.7f, 1),
                new Vector3(1.6f, 1, 1.1f), creature);
            for (var side = -1; side <= 1; side += 2)
                for (var leg = 0; leg < 3; leg++)
                    Primitive($"Crab leg {side} {leg}", PrimitiveType.Cube,
                        new Vector3(side * 1f, 0.35f, 0.6f + leg * 0.4f),
                        new Vector3(1.1f, 0.2f, 0.18f), creature);

            var cameraObject = new GameObject("Main Camera");
            cameraObject.tag = "MainCamera";
            cameraObject.transform.position = new Vector3(9, 7, -11);
            cameraObject.transform.LookAt(new Vector3(0, 0.8f, 2));
            var camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.025f, 0.035f, 0.075f);
            cameraObject.AddComponent<UniversalAdditionalCameraData>();
            cameraObject.AddComponent<AudioListener>();
            cameraObject.AddComponent<BaselineOverlay>();

            var lightObject = new GameObject("Key Light");
            lightObject.transform.rotation = Quaternion.Euler(50, -35, 0);
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.4f;
            light.shadows = LightShadows.Soft;
            lightObject.AddComponent<UniversalAdditionalLightData>();
            RenderSettings.sun = light;
            if (!EditorSceneManager.SaveScene(scene, BootScenePath))
                throw new InvalidOperationException($"Failed to save {BootScenePath}.");
        }

        private static Material GetMaterial(string name, Color color)
        {
            EnsureFolder("Assets/_Game/Settings/Materials");
            var path = $"Assets/_Game/Settings/Materials/{name}.mat";
            var existing = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (existing != null)
                return existing;
            RequireEmptyPath(path);
            var shader = Shader.Find("Universal Render Pipeline/Lit");
            if (shader == null)
                throw new InvalidOperationException("URP/Lit shader unavailable. Finish package import first.");
            var material = new Material(shader) { name = name };
            material.SetColor("_BaseColor", color);
            AssetDatabase.CreateAsset(material, path);
            return material;
        }

        private static void Primitive(string name, PrimitiveType type, Vector3 position,
            Vector3 scale, Material material)
        {
            var item = GameObject.CreatePrimitive(type);
            item.name = name;
            item.transform.position = position;
            item.transform.localScale = scale;
            item.GetComponent<Renderer>().sharedMaterial = material;
        }

        private static void RequireEmptyPath(string path)
        {
            if (System.IO.File.Exists(path))
                throw new InvalidOperationException($"Refusing to replace an existing asset: {path}");
        }

        private static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path))
                return;
            var separator = path.LastIndexOf('/');
            var parent = path.Substring(0, separator);
            EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, path.Substring(separator + 1));
        }
    }
}
