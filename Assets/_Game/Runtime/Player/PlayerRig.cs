using CosmicCatch.Interaction;
using CosmicCatch.Presentation;
using CosmicCatch.Settings;
using UnityEngine;

namespace CosmicCatch.Player
{
    /// <summary>
    /// Composition root of the local player rig: owns the input hub, wires the
    /// controller and interactor, drives cursor state and applies settings on
    /// start. Destroying it releases everything the rig created.
    /// </summary>
    public sealed class PlayerRig : MonoBehaviour
    {
        private PlayerInputHub input;

        private void Awake()
        {
            input = new PlayerInputHub();
            GetComponent<FirstPersonController>().BindInput(input);
            foreach (var interactor in GetComponentsInChildren<Interactor>())
                interactor.BindInput(input);
            GameSettings.ReloadAndApply();
            SetMenuOpen(false);
        }

        private void OnDestroy()
        {
            input?.Dispose();
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }

        private void OnApplicationFocus(bool hasFocus)
        {
            // Never relock the cursor while a menu is open; unstick held input
            // by cycling the gameplay map when focus returns.
            if (hasFocus)
                SetMenuOpen(GetComponentInChildren<PauseMenu>()?.IsOpen ?? false);
        }

        public void SetMenuOpen(bool open)
        {
            input.GameplayEnabled = !open;
            foreach (var controller in GetComponentsInChildren<FirstPersonController>())
                controller.InputAllowed = !open;
            foreach (var interactor in GetComponentsInChildren<Interactor>())
                interactor.InputAllowed = !open;
            Cursor.lockState = open ? CursorLockMode.None : CursorLockMode.Locked;
            Cursor.visible = open;
        }

        public bool ConsumeMenuToggle()
        {
            return input.ConsumeMenuToggle();
        }
    }
}
