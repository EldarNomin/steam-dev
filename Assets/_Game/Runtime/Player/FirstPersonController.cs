using CosmicCatch.Settings;
using UnityEngine;

namespace CosmicCatch.Player
{
    /// <summary>
    /// First-person solo controller on CharacterController. Reading input is
    /// isolated in PlayerInputHub so a network model can replace it later.
    /// </summary>
    [RequireComponent(typeof(CharacterController))]
    public sealed class FirstPersonController : MonoBehaviour
    {
        [Tooltip("Camera rotated by pitch; usually a child of this object.")]
        public Transform view;

        [Tooltip("Definition generated from the approved balance file.")]
        public PlayerMovementDefinition definition;

        [Tooltip("Set by LowGravityZone triggers; queried each fixed step.")]
        public bool inLowGravityZone;

        private PlayerInputHub input;
        private CharacterController body;
        private GravityBlender blender;
        private float pitch;
        private float verticalVelocity;

        public bool InputAllowed { private get; set; } = true;

        private void Awake()
        {
            body = GetComponent<CharacterController>();
            // At very high frame rates the per-frame gravity step can fall
            // below the default 0.001 threshold and the controller stops
            // settling onto the ground.
            body.minMoveDistance = 0f;
            if (definition != null)
                blender = new GravityBlender(definition.gravityBlendSeconds);
        }

        /// <summary>The hub is injected by the rig owner; this controller never builds input itself.</summary>
        public void BindInput(PlayerInputHub playerInput)
        {
            input = playerInput;
        }

        /// <summary>Sets the initial look pitch in degrees (negative = looking down).</summary>
        public void SetStartPitch(float degrees)
        {
            pitch = Mathf.Clamp(degrees, -89f, 89f);
            if (view != null)
                view.localRotation = Quaternion.Euler(pitch, 0f, 0f);
        }

        private void Start()
        {
            if (blender == null && definition != null)
                blender = new GravityBlender(definition.gravityBlendSeconds);
            if (blender != null && definition != null)
                blender.Reset(definition.gravity);
            // Keep the editor-authored spawn pitch until the mouse moves.
            if (view != null)
            {
                var euler = view.localEulerAngles.x;
                pitch = euler > 180f ? euler - 360f : euler;
            }
        }

        private void Update()
        {
            if (input == null || definition == null)
                return;

            if (InputAllowed)
            {
                Look(input.ReadLook());
                Move(input.ReadMove(), input.ConsumeJump());
                return;
            }
            // Menus own the cursor; stop walking but keep physics settling.
            Move(Vector2.zero, false);
        }

        private void Look(Vector2 delta)
        {
            var settings = GameSettings.Current;
            var scale = settings.mouseSensitivity * 0.1f;
            transform.Rotate(0f, delta.x * scale, 0f);
            pitch -= delta.y * scale * (settings.invertY ? -1f : 1f);
            pitch = Mathf.Clamp(pitch, -89f, 89f);
            if (view != null)
                view.localRotation = Quaternion.Euler(pitch, 0f, 0f);
        }

        private void Move(Vector2 moveInput, bool jumpPressed)
        {
            var gravityTarget = inLowGravityZone ? definition.lowGravity : definition.gravity;
            if (blender == null)
                blender = new GravityBlender(definition.gravityBlendSeconds);
            var gravity = blender.Advance(gravityTarget, Time.deltaTime);

            if (body.isGrounded && verticalVelocity < 0f)
                verticalVelocity = -2f;

            if (jumpPressed && body.isGrounded)
                verticalVelocity = Mathf.Sqrt(2f * gravity * definition.jumpHeight);

            if (!body.isGrounded)
                verticalVelocity -= gravity * Time.deltaTime;

            var direction = MoveNormalizer.Normalize(moveInput);
            var horizontal = (transform.right * direction.x + transform.forward * direction.y)
                * definition.speed;
            var motion = (horizontal + Vector3.up * verticalVelocity) * Time.deltaTime;
            body.Move(motion);

            var extent = definition.playAreaHalfExtent;
            var position = transform.position;
            var clamped = new Vector3(
                Mathf.Clamp(position.x, -extent, extent),
                position.y,
                Mathf.Clamp(position.z, -extent, extent));
            if (clamped != position)
                body.Move(clamped - position);

            if (position.y < definition.killY)
            {
                body.enabled = false;
                transform.position = definition.spawnPoint;
                body.enabled = true;
            }
        }
    }
}
