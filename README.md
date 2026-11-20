> **Current active mode: Kitty Hunt — Phase 2.** The game now includes 1,000 distinct, offline physics-verified hunting layouts with explicit mouse escape paths, growth requirements and seven mixed puzzle families. See [the Phase 2 campaign guide](docs/PHASE_2_HUNT_CAMPAIGN.md) and [Phase 1 gameplay](docs/PHASE_1_HUNT.md). Earlier rescue documentation below is historical; active hunting loads `levels/hunt/` directly.

# Kitty Rescue: Dig to Mom

**Current Android services update:** Home, daily streak rewards, shop, support popups and the native Android service bridge are implemented. See `docs/ANDROID_SERVICES.md` for current build commands, private configuration, release blockers and validation. It supersedes the older Android/export and no-services notes below. Production IDs and release signing must be supplied locally before a production AAB can be exported.

A standalone Godot 4.6+ portrait game prototype. Drag a finger through sand to excavate a route to the mother cat. Round kittens fall, roll and collide using `RigidBody2D`; no kitten follows a scripted route. Existing games in the parent directory are preserved.

**Endless update:** progression now continues beyond level 200. New levels are generated and physics-verified on demand, then saved for repeat play. Bees chase reachable kittens through excavated tunnels. Rescued kittens remain visible in a happy group behind Mom and on the win screen. See `docs/ENDLESS_LEVELS.md` for the current behavior and checks; it supersedes the original campaign-limit and generator notes below.

**Visual update:** the live gameplay now uses textured sand with sculpted tunnel shading, dimensional borders and props, larger cats, and an authored showcase level. Open `scenes/gameplay/Showcase.tscn` and press F6 to play it directly. All six authored levels passed complete rescues after the update. See `docs/VISUAL_UPDATE.md` for current implementation details, screenshots and the updated terrain rendering approach; it supersedes the initial rendering notes below.

## Play

Open `project.godot` in Godot 4.7.2 and press F5, or double-click `PLAY_KITTY_RESCUE.cmd` on this computer. The launcher uses the installed Godot executable. Mouse dragging also digs. Tap a wheel's metal hub to reverse it. The question-mark button toggles a suggested excavation route. F3 toggles chunk and velocity diagnostics.

The Play button starts the next unlocked level. Levels unlock sequentially with no 200-level cap. Levels 1â€“5 teach digging, multiple kittens, retaining supporting sand under a rock, reversing a wheel, and avoiding bees. Level 6 is the authored Sunken Garden showcase. Levels 7â€“25 are packaged generated puzzles. All 25 have completed actual physics rescues in the current regression run. Later levels and daily challenges are generated, executed in an isolated physics simulation, and cached before being offered for play.

## Implemented phases and files

**Phase 1 â€” foundation:** `project.godot`; `scenes/menus/{MainMenu,Settings,LevelSelect}.tscn`; `scripts/menus/{Menu,Backdrop}.gd`; `scripts/core/{SaveManager,AudioManager,UI}.gd`. Includes animated menu, navigation, ten selectable world pages of twenty slots, sequential locks, stars, persistent settings, volume controls, local progress, daily completion records, reset confirmation, privacy text, and quit confirmation. The daily record is a completion badge, without an additional currency reward.

**Phase 2 â€” playable prototype:** `scenes/gameplay/{Gameplay,Kitten,MotherCat,SandTerrain}.tscn`; corresponding scripts in `scripts/gameplay/`; five `levels/easy/*.json`; `assets/terrain/sand.gdshader`; `data/characters.json`. Includes live excavation along entire drag segments, circular kitten collision, configurable body properties, mother rescue area, particles, restart, pause, win/lose panels, safe-area HUD adjustment, and focus-loss pause.

Terrain is a configurable 6â€“16 pixel material grid, divided into 12Ã—12-cell chunks. Only dirty chunks rebuild their merged rectangle colliders, outside the physics callback. A small signed distance mask is recalculated and uploaded after edits for consistent cut-face lighting. The textured shader rounds and bevels the visible edges. Collision remains a conservative grid approximation; this is not a grain simulation. Walls and rock cells cannot be dug. Physics shapes do not include ears or bows.

**Obstacle groundwork:** `scripts/obstacles/{Obstacle,RockVisual}.gd`; eleven `scenes/obstacles/*.tscn`. Includes physical rotating cross paddles, falling rocks, sinusoidal bee patrols, spikes, cycling plants, permanent pressure switches and gates, directional fans, portal cooldowns, buoyancy/current regions, and moving platforms. These systems have focused automated checks. They do not yet constitute a polished advanced-level campaign: timed gates, arbitrary patrol paths, and moving/hidden spikes need further work.

**Art and generation groundwork:** `assets/cats/{kittens,mother}.png`; `assets/obstacles/props.png`; `scripts/generation/{LevelGenerator,LevelValidator,SolutionTester}.gd`; `scripts/gameplay/LevelLoader.gd`; `levels/medium/*.json`; `tests/`. Original generated transparent sprite atlases have dimensional fur, shaded materials, and highlights. This is a 2D game with 3D-like raster art, not a 3D mesh renderer. Source prompts are recorded in `docs/ASSET_PROMPTS.md`.

## Verification

Run with Godot 4.7.2:

```powershell
godot --headless --path . res://tests/Runner.tscn --fixed-fps 60 --log-file tests.log
godot --headless --path . res://tests/Generate.tscn --fixed-fps 60 --log-file generated.log
godot --path . res://tests/Preview.tscn --fixed-fps 60 --log-file preview.log
```

Replace `godot` with the full path to your executable when it is not on PATH. In a restricted environment set APPDATA and LOCALAPPDATA to test directories inside this project so tests do not touch real player saves. Create `levels/medium/` and `docs/` if absent before running the generation or screenshot tools.

`Runner` checks 200 candidate schemas, deterministic generation, invalid JSON structure, unsupported versions, duplicate IDs, corruption recovery, settings persistence, progress persistence and unlocking, menu scene construction, terrain support, real touch-handler excavation, complete physics rescues, exact terrain restart, and ten obstacle behaviors. It writes `tests/verification.json`. `Generate` executes proposed dig actions through the gameplay input handler and runs real physics; only successful candidates are exported with verification metadata. Its results are in `tests/generated-verification.json`. Verification means the tested intended solution succeeded, not that every possible player action succeeds.

The campaign now has 1,000 explicit JSON recipes in `levels/campaign/`, indexed by `manifest.json`. Levels 1–29 preserve authored maps. Later recipes specify ordered screen puzzles, obstacle settings, kitten counts, digging widths and objectives across ten difficulty tiers and up to five screens. Failed physics checks retry with the same planned mechanics and screen count, widening digging and slowing machinery rather than removing the challenge. New levels are verified in actual physics and cached before play; recipe edits invalidate cached proofs. After level 1,000, expert variants continue without a fixed final level. Daily Challenges use their separate seeded generator. See [the campaign guide](docs/CAMPAIGN_1000.md) for progression, editing and the exact validation scope.

## Android

`export_presets.cfg` defines an offline, immersive portrait Android debug export for ARM64 and x86_64, with no advertising or purchase SDK. It excludes tests and documentation. Install matching Godot export templates, configure Java and Android SDK paths in Editor Settings, then use **Project â†’ Export â†’ Android â†’ Export Project** or:

```powershell
godot --headless --path . --export-debug Android build/kitty-rescue-debug.apk
```

The build attempt in this session failed. The sandbox denies access to `C:/AndroidSdk`; the isolated test profile also lacks export templates and Java configuration. The installed machine-wide templates are visible in the normal profile, but SDK access is still required. No working APK or Android device run is claimed. A native editor export outside these restrictions, followed by touch, safe-area, suspend/resume and performance testing on a physical device, is required.

## Remaining production work

This delivers the requested foundation and functioning sand-rescue prototype, with obstacle and generation groundwork. It is not the complete production game described in the master specification. Remaining work includes father-cat art/objectives, full expression/blink/ear animation sets, final environment and UI artwork, richer audio, separate reusable result-screen scenes, interactive finger tutorial polish, localization tables, optional cloud-save interface, comprehensive nested-save validation/recovery, proper difficulty/world mechanics, advanced generation and search, and device profiling. Undo is intentionally absent because no complete physics snapshot system exists. No advertisements, purchases, external analytics or login have been added.

The five initial levels can be cleared with a continuous downward dig. Challenge design and art polish should be assessed through playtesting before expanding the campaign. Desktop screenshots are in `docs/menu.png`, `docs/level4.png`, and `docs/digging.png`.
