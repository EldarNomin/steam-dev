using System;
using System.Linq;
using CosmicCatch.Interaction;
using CosmicCatch.Player;
using CosmicCatch.Presentation;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace CosmicCatch.Editor
{
    /// <summary>
    /// Adds the DEV-002 player rig to the existing Boot scene. Keeps every
    /// existing object, material and reference; the DEV-001 camera moves under
    /// the player, its full-screen overlay is replaced by the compact HUD.
    /// </summary>
    public static class PlayerRigSetup
    {
        public const string DefinitionPath = "Assets/_Game/Settings/PlayerMovement.asset";

        [MenuItem("Cosmic Catch/Setup/Add DEV-002 player rig")]
        public static void SetupMenu()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode)
                throw new InvalidOperationException("Stop Play Mode before setup.");
            Apply();
        }

        public static void ApplyBatch()
        {
            try
            {
                Apply();
                EditorApplication.Exit(0);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                EditorApplication.Exit(1);
            }
        }

        private static void Apply()
        {
            BaselineSetup.RequireEditorVersion();
            var scene = EditorSceneManager.OpenScene(BaselineSetup.BootScenePath, OpenSceneMode.Single);

            var definition = AssetDatabase.LoadAssetAtPath<PlayerMovementDefinition>(DefinitionPath);
            if (definition == null)
            {
                if (System.IO.File.Exists(DefinitionPath))
                    throw new InvalidOperationException($"Refusing to replace {DefinitionPath}.");
                // Numbers mirror Docs/Data/balance.v0.1.json "movement"; update
                // this initializer together with the balance file.
                definition = ScriptableObject.CreateInstance<PlayerMovementDefinition>();
                AssetDatabase.CreateAsset(definition, DefinitionPath);
            }

            EnsureLayer("Player", 6);
            var playerLayer = LayerMask.NameToLayer("Player");

            var camera = UnityEngine.Object.FindFirstObjectByType<Camera>();
            if (camera == null)
                throw new InvalidOperationException("Boot scene has no camera; run baseline setup first.");

            var playerTransform = GameObject.Find("Player")?.transform;
            if (playerTransform == null)
            {
                var player = new GameObject("Player")
                {
                    layer = playerLayer,
                    tag = "Player"
                };
                playerTransform = player.transform;
                playerTransform.position = definition.spawnPoint;
                var body = player.AddComponent<CharacterController>();
                body.height = 1.8f;
                body.radius = 0.35f;
                body.center = new Vector3(0f, 0.9f, 0f);

                camera.transform.SetParent(playerTransform, true);
                camera.transform.localPosition = new Vector3(0f, 1.55f, 0f);
                camera.transform.localRotation = Quaternion.identity;

                var controller = player.AddComponent<FirstPersonController>();
                controller.definition = definition;
                controller.view = camera.transform;

                var interactor = player.AddComponent<Interactor>();
                interactor.view = camera.transform;
                interactor.IgnoreLayer(playerLayer);

                player.AddComponent<PlayerRig>();
            }

            // Replace the DEV-01 full-screen overlay with the compact HUD on the camera.
            var overlay = camera.GetComponent<BaselineOverlay>();
            if (overlay != null)
                UnityEngine.Object.DestroyImmediate(overlay);
            if (camera.GetComponent<StationHud>() == null)
            {
                var hud = camera.gameObject.AddComponent<StationHud>();
                hud.interactor = UnityEngine.Object.FindFirstObjectByType<Interactor>();
            }
            if (camera.GetComponent<PauseMenu>() == null)
                camera.gameObject.AddComponent<PauseMenu>();

            EnsureTerminal();
            EnsureLowGravityZone(definition);
            EnsureZoneMarkerMaterial();

            EditorSceneManager.SaveScene(scene);
            AssetDatabase.SaveAssets();
            Debug.Log("DEV-002 player rig is in place. Enter Play Mode and walk.");
        }

        private static void EnsureTerminal()
        {
            if (UnityEngine.Object.FindFirstObjectByType<Terminal>() != null)
                return;
            var cargo = GameObject.Find("Cargo terminal");
            if (cargo == null)
                throw new InvalidOperationException("Boot scene has no Cargo terminal; run baseline setup first.");
            cargo.AddComponent<Terminal>();
        }

        private static void EnsureLowGravityZone(PlayerMovementDefinition definition)
        {
            var existing = GameObject.Find("LowGravityZone (тест)");
            if (existing != null)
                return;
            var zone = new GameObject("LowGravityZone (тест)");
            zone.transform.position = new Vector3(-5f, 1.5f, -5f);
            var volume = zone.AddComponent<BoxCollider>();
            volume.isTrigger = true;
            volume.size = new Vector3(5f, 3f, 5f);
            zone.AddComponent<LowGravityZone>();

            var marker = GameObject.CreatePrimitive(PrimitiveType.Cube);
            marker.name = "LowGravityMarker";
            marker.transform.SetParent(zone.transform, false);
            marker.transform.localPosition = Vector3.zero;
            marker.transform.localScale = new Vector3(5f, 0.05f, 5f);
            var collider = marker.GetComponent<Collider>();
            if (collider != null)
                UnityEngine.Object.DestroyImmediate(collider);
            var renderer = marker.GetComponent<Renderer>();
            renderer.sharedMaterial = AssetDatabase.LoadAssetAtPath<Material>(
                "Assets/_Game/Settings/Materials/LowGravityMarker.mat");
        }

        private static void EnsureZoneMarkerMaterial()
        {
            const string path = "Assets/_Game/Settings/Materials/LowGravityMarker.mat";
            if (AssetDatabase.LoadAssetAtPath<Material>(path) != null)
                return;
            if (System.IO.File.Exists(path))
                throw new InvalidOperationException($"Refusing to replace {path}.");
            var shader = Shader.Find("Universal Render Pipeline/Unlit");
            if (shader == null)
                throw new InvalidOperationException("URP/Unlit shader unavailable.");
            var material = new Material(shader) { name = "LowGravityMarker" };
            material.SetColor("_BaseColor", new Color(0.45f, 0.85f, 1f, 0.35f));
            material.SetFloat("_Surface", 1f); // Transparent
            material.SetOverrideTag("RenderType", "Transparent");
            material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            material.SetInt("_ZWrite", 0);
            material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
            AssetDatabase.CreateAsset(material, path);
        }

        private static void EnsureLayer(string name, int index)
        {
            var tags = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/TagManager.asset")[0]);
            var layers = tags.FindProperty("layers");
            var slot = layers.GetArrayElementAtIndex(index);
            if (string.IsNullOrEmpty(slot.stringValue))
                slot.stringValue = name;
            else if (slot.stringValue != name)
                throw new InvalidOperationException($"Layer {index} is taken by '{slot.stringValue}'.");
            tags.ApplyModifiedProperties();
        }
    }
}
