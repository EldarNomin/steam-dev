# Cosmic Magnet — visual asset provenance

- `art/derelict.webp`, `art/magnet.webp`: original AI-generated sprites created for this project with OpenAI ImageGen on 2026-10-10. Transparent originals converted to WebP for distribution; no third-party game assets were copied. AI content must be included in the Steam disclosure when preparing release.
- `art/*.svg`: original vector artwork authored by Codex for Cosmic Magnet on 2026-10-10; repository-owned assets, no external asset-pack dependency.
- `reference/concept.png`: earlier AI-generated visual reference, not used as the playable field or UI.

## Art direction / generation prompts

Derelict: isolated horizontal abandoned industrial spacecraft, orthographic three-quarter view; weathered slate-blue and copper panels, exposed pipes, breached hull, amber portholes, cyan rim highlights; crisp hand-painted 2D game asset, transparent background, no UI/text/stars.

Magnet: isolated top-down symmetric magnetic salvage drone; four golden-orange claws, silver-blue beveled armor, black mechanism, central white-cyan reactor; crisp hand-painted 2D game asset readable at 60px, transparent background, no UI/text/scene.

- `art/skiff.svg`: оригинальная векторная графика Codex для этого проекта (2026-10-11); внешний референс/сторонний ассет не использовался. Исходник включён в репозиторий.

## Temporary Void treatment — CM-V01 (2026-10-11)

Selected PNGs in `void/` are unmodified original sprite sheets from Foozle's
Void 1.0 packs, commissioned from Baldur / distributed by Foozle. **CC0 1.0**;
commercial use, modification and redistribution allowed; attribution optional.
The original pack Readmes are included. `void/manifest.json` maps local filenames
to original archive paths and records SHA256 of the original bytes.

- Main Ship: https://foozlecc.itch.io/void-main-ship
- Nairan Fleet 2: https://foozlecc.itch.io/void-fleet-pack-2
- Environment: https://foozlecc.itch.io/void-environment-pack
- Pickups: https://foozlecc.itch.io/void-pickups-pack
- License: https://creativecommons.org/publicdomain/zero/1.0/

`void/magnet.svg`, `void/nut.svg`, `void/plate.svg` and clamp drawing are original
Codex vector/code artwork matched to the pack palette; they are not Foozle art.
The magnet and scrap silhouettes retain their existing gameplay meaning.

Void is an interim playable demo treatment chosen by Eldar. The final art target
remains detailed weathered metal, volumetric-looking salvage and atmospheric
space, as described above. Existing original art stays in the repository for that
future direction; it is not mixed into the Void field. This is not final visual
acceptance of CM-005.
