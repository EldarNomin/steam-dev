using System;
using UnityEngine;
using UnityEngine.InputSystem;

namespace CosmicCatch.Player
{
    /// <summary>
    /// Owns the player's Input System actions. Actions are built in code (no
    /// .inputactions asset) so DEV-006 can replace the source of movement data
    /// with an authoritative network model without touching UI or settings.
    /// Two maps: gameplay (move/look/jump/interact) and System (menu toggle).
    /// The System map stays enabled in menus so Esc keeps closing them; only
    /// the gameplay map is gated. One owner per player; disposing releases
    /// only the actions built here.
    /// </summary>
    public sealed class PlayerInputHub : IDisposable
    {
        private readonly InputActionAsset asset;
        private readonly InputActionMap gameplay;
        private readonly InputAction move;
        private readonly InputAction look;
        private readonly InputAction jump;
        private readonly InputAction interact;
        private readonly InputAction menu;

        public PlayerInputHub()
        {
            // InputActionAsset is a ScriptableObject: the plain constructor
            // throws in the player build.
            asset = ScriptableObject.CreateInstance<InputActionAsset>();
            gameplay = asset.AddActionMap("Gameplay");

            move = gameplay.AddAction("Move", InputActionType.Value);
            move.AddCompositeBinding("2DVector")
                .With("Up", "<Keyboard>/w").With("Down", "<Keyboard>/s")
                .With("Left", "<Keyboard>/a").With("Right", "<Keyboard>/d");
            move.AddCompositeBinding("2DVector")
                .With("Up", "<Keyboard>/upArrow").With("Down", "<Keyboard>/downArrow")
                .With("Left", "<Keyboard>/leftArrow").With("Right", "<Keyboard>/rightArrow");

            look = gameplay.AddAction("Look", InputActionType.Value, "<Mouse>/delta");
            jump = gameplay.AddAction("Jump", InputActionType.Button, "<Keyboard>/space");
            interact = gameplay.AddAction("Interact", InputActionType.Button, "<Keyboard>/e");

            menu = asset.AddActionMap("System").AddAction("Menu", InputActionType.Button, "<Keyboard>/escape");

            asset.Enable();
        }

        /// <summary>False while a menu owns the cursor: the gameplay map is disabled, Esc keeps working.</summary>
        public bool GameplayEnabled
        {
            set
            {
                if (value)
                    gameplay.Enable();
                else
                    gameplay.Disable();
            }
        }

        public Vector2 ReadMove()
        {
            return move.ReadValue<Vector2>();
        }

        public Vector2 ReadLook()
        {
            return look.ReadValue<Vector2>();
        }

        public bool ConsumeJump()
        {
            return jump.WasPerformedThisFrame();
        }

        public bool ConsumeInteract()
        {
            return interact.WasPerformedThisFrame();
        }

        public bool ConsumeMenuToggle()
        {
            return menu.WasPerformedThisFrame();
        }

        public void Dispose()
        {
            // Disable releases the devices; the asset itself is a ScriptableObject.
            asset.Disable();
            if (Application.isPlaying)
                UnityEngine.Object.Destroy(asset);
            else
                UnityEngine.Object.DestroyImmediate(asset);
        }
    }
}
