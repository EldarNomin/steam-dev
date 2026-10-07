# Unity project context

Evidence: repository files + real editor runs, 2026-10-07. DEV-001 verified in Unity 6000.3.25f1 (compile, Setup, idempotent GUIDs, Play Mode scene, Windows build, exe run). See [DEV-001 local result](../Development/DEV-001-LOCAL-RESULT.md).

- Root: `steam-dev`, markers: `Assets`, `Packages/manifest.json`, `ProjectSettings/ProjectVersion.txt`.
- Editor pin: 6000.3.25f1, revision e1dba0a9aba4. No upgrade is authorized by this baseline task.
- Direct manifest dependencies: URP 17.3.0, Input System 1.20.1; builtin audio/imgui/jsonserialize/physics modules 1.0.0. Transitive lock: `Packages/packages-lock.json` committed after real import (resolved by editor, URP 17.3.0).
- Active Input Handling: **Input System Package (New)** — `activeInputHandler: 1` in ProjectSettings (switched via editor serialized field, 2026-10-07).
- Assemblies: `CosmicCatch.Runtime` (all platforms, station overlay); `CosmicCatch.Editor` (Editor only, setup/build; references runtime and URP/Core runtime assemblies). BuildCommands evidence fields errors/warnings are `int` (Unity 6000.3 API).
- Scene: `Assets/_Game/Scenes/Boot.unity` exists (created by `Cosmic Catch/Setup/Create baseline`, GUID d958729a26b59c342b114589b73bdb66, verified idempotent). URP assets committed: `Assets/_Game/Settings/CosmicCatchURP.asset`, `CosmicCatchRenderer.asset`, `Materials/{Hull,Accent,Creature}.mat`; URP global settings at `Assets/UniversalRenderPipelineGlobalSettings.asset`.
- Build entry point: `CosmicCatch.Editor.BuildCommands.BuildWindowsBatch`; setup: `CosmicCatch.Editor.BaselineSetup.SetupBatch`; Windows runner: `Tools/Unity.ps1`.
- Build output: `Builds/Windows/CosmicCatch.exe` (not committed); reports/logs: `Reports` (ignored). Machine-readable build summary committed at `Docs/Evidence/DEV-001/windows-build-summary.json`.
- Persistence/network/RNG: specified only; no runtime classes or SDK integration. Do not infer they are implemented from documentation.
- Validation: [DEV-001 local result](../Development/DEV-001-LOCAL-RESULT.md) — real editor evidence. Python `Tools/validate_project.py` checks structure/syntax only.
- Local environment notes: user session runs elevated (no UAC split token); Unity GUI shows an «Administrator Privileges Detected» modal on every editor GUI start — dismissible with keyboard (Tab, Space) after SetForegroundWindow; batchmode runs are unaffected. Screenshots of Game View are taken from standalone or desktop capture.
- Source of game rules: [MVP-TZ](../MVP-TZ.md), [balance](../Data/balance.v0.1.json), [backlog](../BACKLOG.md). Keep pure economic/transaction rules separate from MonoBehaviour/RPC when implementing.
- Git policy: small feature branches and PR; do not mark M0 or merge this baseline as runtime verified without Editor evidence — evidence now exists for DEV-001 (see local result; TC-028 30-minute run still NOT RUN).
