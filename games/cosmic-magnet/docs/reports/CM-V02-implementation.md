# CM-V02 implementation and verification

Code: `bbc1fcfcfce62760f0f8d29e8bb09526ac2947ef`. Base: `a244bcc` (PR #11).

Matching relay/clamp badges, real hardware links, extraction direction chevrons and a 1.1-second rescue effect improve presentation. Numbers do not impose an order. Physics, progression, prices, cargo and rewards are unchanged. Reward/save happen before the cosmetic hull trace and completion-card reveal.

Godot 4.5.1 Linux Compatibility: import and 120-frame smoke passed. Headless suites: core 46, economy 65, save 60, hook 76 — **247/247**. Save-suite corrupt-JSON diagnostics are intentional negative fixtures. Added checks cover save-before-feedback, pause/menu freezing, overlay order, single reward, delayed card and transient reset on continue.

Real-input driver `tools/hook_playthrough.gd` completed at 1280×720 (3434 ticks, 12 shots, 12 covers, 3 releases, module/skiff recovered, 258 scrap, tow 93) and 1920×1080 (3140 ticks, 11 shots, 12 covers, 3 releases, module/skiff recovered, 213 scrap, tow 93), with zero runtime errors. The driver uses internal positions to choose inputs: these are regression runs, not human playtests or wishlist evidence.

After those captures, one UI-only fix moved PauseOverlay above the completion interceptor. The final 76-check hook suite passed; an X11 presentation fixture froze the rescue effect and successfully clicked the actual Resume button (`PAUSE_RESCUE_PROBE frozen=true real_resume_click=true`). This fixture forced completion for UI testing and is not a gameplay completion claim. Normal-route recordings precede only that layer-order fix.

Evidence: [15-second actual gameplay montage](../evidence/CM-V02/rescue-15s.mp4), [matching hardware](../evidence/CM-V02/chain.webp), [towing](../evidence/CM-V02/towing.webp), [rescue](../evidence/CM-V02/rescue.webp). Three five-second excerpts, normal speed, no audio, 960×540; source 1280×720 movie.

CI results and the new Windows artifact are recorded in the PR after the final pushed head completes. Human CM-004 remains **NOT_RUN**, no CONTINUE decision. Void remains temporary; final art and the remaining CM-005 scope are unchanged.
