using System.Collections;
using System.Collections.Generic;
using System.Linq;
using CosmicCatch.Interaction;
using CosmicCatch.Player;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;

namespace CosmicCatch.Tests.Play
{
    /// <summary>
    /// Behavioral checks of the local player rig with a virtual keyboard.
    /// Measures movement, jump, gravity-zone trigger and interaction gating.
    /// Key events are queued as full KeyboardState events (public API; the
    /// package's InputTestFixture is not shipped in the released assembly).
    /// </summary>
    public sealed class PlayerRigPlayTests
    {
        private readonly HashSet<Key> held = new HashSet<Key>();
        private readonly List<GameObject> environment = new List<GameObject>();
        private Keyboard keyboard;
        private GameObject player;
        private CharacterController body;
        private FirstPersonController controller;
        private PlayerInputHub hub;
        private PlayerMovementDefinition definition;

        /// <summary>
        /// Play mode tests run in the currently open scene (Boot), whose real
        /// player, platform and terminal interfere with the fixtures. Each test
        /// therefore moves its objects into a fresh empty scene.
        /// </summary>
        private Scene testScene;

        [SetUp]
        public void SetUp()
        {
            testScene = SceneManager.CreateScene($"PlayerRigTest-{System.Guid.NewGuid().ToString("N")}");
            // New primitives are born in the active scene; make it the test
            // scene so nothing leaks in from (or registers into) Boot.
            SceneManager.SetActiveScene(testScene);
            keyboard = InputSystem.AddDevice<Keyboard>();

            environment.Add(GameObject.CreatePrimitive(PrimitiveType.Plane));

            // Created inactive so the CharacterController registers in physics
            // only after its shape and position are configured; registering the
            // default capsule at the origin causes an upward depenetration push.
            player = new GameObject("Player");
            player.SetActive(false);
            body = player.AddComponent<CharacterController>();
            body.height = 1.8f;
            body.radius = 0.35f;
            body.center = new Vector3(0f, 0.9f, 0f);
            body.minMoveDistance = 0f;
            player.transform.position = new Vector3(0f, 0.05f, 0f);

            definition = ScriptableObject.CreateInstance<PlayerMovementDefinition>();

            var view = new GameObject("View").transform;
            view.SetParent(player.transform, false);
            view.localPosition = new Vector3(0f, 1.55f, 0f);

            controller = player.AddComponent<FirstPersonController>();
            controller.view = view;
            controller.definition = definition;

            hub = new PlayerInputHub();
            controller.BindInput(hub);
            var interactor = player.AddComponent<Interactor>();
            interactor.view = view;
            interactor.BindInput(hub);
            environment.Add(player);
            player.SetActive(true);
        }

        [TearDown]
        public void TearDown()
        {
            hub.Dispose();
            environment.Clear();
            if (testScene.IsValid())
                SceneManager.UnloadSceneAsync(testScene);
            InputSystem.RemoveDevice(keyboard);
        }

        /// <summary>Queues a full keyboard state; the next input update applies it.</summary>
        private void Press(Key key)
        {
            held.Add(key);
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(held.ToArray()));
        }

        private void Release(Key key)
        {
            held.Remove(key);
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(held.ToArray()));
        }

        private void ReleaseNow(Key key)
        {
            held.Remove(key);
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(held.ToArray()));
            InputSystem.Update();
        }

        /// <summary>Press whose performed phase is asserted inside this frame.</summary>
        private void PressNow(Key key)
        {
            held.Add(key);
            InputSystem.QueueStateEvent(keyboard, new KeyboardState(held.ToArray()));
            InputSystem.Update();
        }

        /// <summary>Teleports the controller through body.Move so trigger pairs update properly.</summary>
        private void MovePlayerTo(Vector3 position)
        {
            body.Move(position - player.transform.position);
            player.transform.position = position;
        }

        private IEnumerator SettleOnGround()
        {
            yield return new WaitForFixedUpdate();
            yield return new WaitForFixedUpdate();
        }

        [UnityTest]
        public IEnumerator WalkSpeedMatchesBalance()
        {
            yield return SettleOnGround();
            var start = player.transform.position;
            Press(Key.W);
            yield return new WaitForSeconds(1f);
            Release(Key.W);
            var travelled = Vector3.Distance(start, player.transform.position);
            Assert.AreEqual(definition.speed, travelled, definition.speed * 0.1f,
                $"one second of W must cover ~{definition.speed} m, got {travelled:F2}");
        }

        [UnityTest]
        public IEnumerator DiagonalWalkIsNotFaster()
        {
            yield return SettleOnGround();
            var start = player.transform.position;
            Press(Key.W);
            Press(Key.D);
            yield return new WaitForSeconds(1f);
            Release(Key.D);
            Release(Key.W);
            var travelled = Vector3.Distance(start, player.transform.position);
            Assert.AreEqual(definition.speed, travelled, definition.speed * 0.1f,
                $"diagonal must stay {definition.speed} m/s, got {travelled:F2}");
        }

        [UnityTest]
        public IEnumerator JumpApexIsAboutJumpHeightAndDoubleJumpDoesNothing()
        {
            yield return SettleOnGround();
            var startY = player.transform.position.y;
            Press(Key.Space);
            yield return null;
            Release(Key.Space);
            yield return null;

            var apex = startY;
            var frames = 0;
            var landedAgain = false;
            // At unlimited frame rates one second of flight is many frames.
            while (frames++ < 3000)
            {
                yield return null;
                apex = Mathf.Max(apex, player.transform.position.y);
                if (frames > 30 && player.transform.position.y <= startY + 0.05f)
                {
                    landedAgain = true;
                    break;
                }
            }
            Assert.AreEqual(definition.jumpHeight, apex - startY, 0.15f,
                $"jump apex must be ~{definition.jumpHeight} m, got {apex - startY:F2}");
            Assert.IsTrue(landedAgain, "player must land again after the jump");

            // Second jump while airborne must not lift the player further.
            Press(Key.Space);
            yield return null;
            Release(Key.Space);
            yield return null;
            var maxHeight = player.transform.position.y;
            for (var i = 0; i < 30; i++)
            {
                yield return null;
                maxHeight = Mathf.Max(maxHeight, player.transform.position.y);
            }
            Assert.LessOrEqual(maxHeight, apex + 0.05f,
                "pressing jump mid-air must not add height (no double jump)");
        }

        [UnityTest]
        public IEnumerator LowGravityZoneFlagFollowsTrigger()
        {
            var zoneObject = new GameObject("Zone");
            zoneObject.transform.position = new Vector3(6f, 1f, 6f);
            var volume = zoneObject.AddComponent<BoxCollider>();
            volume.isTrigger = true;
            volume.size = new Vector3(4f, 3f, 4f);
            zoneObject.AddComponent<LowGravityZone>();
            environment.Add(zoneObject);

            yield return SettleOnGround();
            MovePlayerTo(new Vector3(6f, 0.05f, 6f));
            yield return new WaitForFixedUpdate();
            yield return new WaitForFixedUpdate();
            Assert.IsTrue(controller.inLowGravityZone, "entering the zone must switch to low gravity");

            MovePlayerTo(new Vector3(0f, 0.05f, 0f));
            yield return new WaitForFixedUpdate();
            yield return new WaitForFixedUpdate();
            yield return new WaitForFixedUpdate();
            Assert.IsFalse(controller.inLowGravityZone, "leaving the zone must restore gravity");
        }

        [UnityTest]
        public IEnumerator MenuGatingStopsMovementAndEscKeepsWorking()
        {
            yield return SettleOnGround();

            // Regression for the review issue: the menu action must survive
            // gameplay gating, otherwise Esc cannot close the menu.
            hub.GameplayEnabled = false;
            Assert.IsFalse(hub.ConsumeMenuToggle(), "no toggle before pressing Esc");
            PressNow(Key.Escape);
            var registered = hub.ConsumeMenuToggle();
            ReleaseNow(Key.Escape);
            Assert.IsTrue(registered, "Esc must still register while gameplay is gated");

            var start = player.transform.position;
            Press(Key.W);
            yield return new WaitForSeconds(0.3f);
            Release(Key.W);
            Assert.AreEqual(0f, Vector3.Distance(start, player.transform.position), 0.01f,
                "movement must be blocked while the menu is open");

            hub.GameplayEnabled = true;
            Press(Key.W);
            yield return new WaitForSeconds(0.3f);
            Release(Key.W);
            Assert.Greater(Vector3.Distance(start, player.transform.position), 0.5f,
                "movement must resume after the menu closes");
        }
    }
}
