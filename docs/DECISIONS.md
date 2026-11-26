# Decisions

Questions, answers and decisions, newest section last. Dates are ISO (YYYY-MM-DD).

## 2026-11-26: Owner decisions given in the brief

| Topic | Decision |
|---|---|
| Name | **purge** (game and GitHub repository) |
| Engine | Godot 4, the copy in `H:\temp\godot` |
| Look | 3D models on a fixed, slightly tilted top-down camera, gameplay on a 2D plane |
| Playfield | Centered vertical playfield, HUD in side panels |
| On death | Restart the stage, keep all upgrades; credits from the failed attempt are lost |

## 2026-11-26: Section 0 questions and answers

| # | Question | Owner's answer |
|---|---|---|
| 1 | How is the GitHub repo created? | Owner created it: `https://github.com/camilus123/purge` |
| 2 | Visibility and license? | Set by the owner on GitHub. The repo ships a **GPL-3.0** `LICENSE`, so the project is GPL-3.0 |
| 3 | Difficulty levels? | Easy / Normal / Hard, chosen at the start of a run |
| 4 | Placeholder art sources? | Everything generated in code first (procedural meshes, shaders, synthesized sounds). Later only CC0 packs, each logged in `assets/CREDITS.md` |
| 5 | Music? | Procedurally generated placeholder tracks until real music is supplied |
| 6 | Unlocking? | Completing a set unlocks the next for single-set play; an "unlock everything" switch lives in data |
| 7 | Language? | English only; UI text kept in a strings file so it can be translated later |
| 8 | Gamepad? | Not now; the input layer is designed so it can be added |
| 9 | Check-ins? | Report at the end of each milestone; stop after Milestone 2 for feedback on control feel |
| 10 | Testing on the owner's PC? | After Milestone 2 the owner gets a one-line launch command or a build |

## 2026-11-26: Technical decisions (Milestone 1 and 2)

- **Engine version pinned: Godot 4.7.2 stable, standard build** (`4.7.2.stable.official.ed1daf0bf`).
  It is not the .NET build, so there is no C#. Gameplay is GDScript; GDExtension is the fallback
  if profiling ever shows GDScript is too slow for the bullet manager. Export templates for 4.7.2
  are already in `H:\temp\godot`.
- **Renderer:** Forward+.
- **Fixed timestep:** gameplay simulation runs at a fixed **240 ticks per second** in
  `_physics_process`; rendering interpolates between the last two ticks. Behaviour is identical
  at any display framerate. 240 was chosen over 120 to keep mouse-to-ship latency at one 4 ms tick.
- **No engine physics for gameplay.** Bullets, enemies and collisions are a custom simulation on
  flat arrays (circle hitboxes from data, column broadphase). Bullets are drawn with one
  MultiMesh per side, updated with a single buffer upload per frame.
- **Simulation is separate from presentation.** `game/scripts/sim/` has no node or rendering
  dependencies and receives its data as dictionaries, so tests can run it headless.
- **Playfield:** 90 x 120 gameplay units. The 3D world renders into a SubViewport with a fixed
  aspect ratio of about 4:5 (derived from the camera: 30 degree vertical FOV, 10 degree tilt), shown
  centered; side panels take the rest. On 3440x1440 the playfield is about 1150x1440 pixels.
- **Data and assets are loaded loose from disk at runtime**, from `data/` and `assets/` beside the
  project (in the editor) or beside the executable (in a release build). They are not baked into the
  Godot pack. This is what makes editing and the `mods/` override folder work without a rebuild.
- **Data format:** JSON as the brief asks. Tech files are `{ "items": [ { "id": ... } ] }`.
  Schemas and the validator arrive in Milestone 3.
- **UI scaling:** `canvas_items` stretch with `expand` aspect on a 1080-high base, so the HUD scales
  with screen height and the side panels absorb any extra width.
- **Git identity:** commits use the owner's GitHub no-reply address.
- **Power model (starting formulas, all numbers in `data/tech/power_model.json`):**
  - weapon share `w = 1 - shield share`; weapon pool refills at `reactor.output * w` per second, capped by the capacitor;
  - shield recharge = `shield.recharge * shield_share * shield_recharge_share_scale * (reactor.output / reference_reactor_output)`,
    so the table values in the brief apply at a 50/50 split with the reference reactor;
  - each weapon lists `power_scaling` ranges (value at 0% and at 100% weapon share) for damage and fire rate;
  - an empty pool multiplies fire rate by `starved_fire_rate_mult` instead of stopping the weapon.
- **Mirror shield maths:** `bleed` share of incoming damage goes straight to the hull, the rest hits the
  shield; `reflect` share of what the shield absorbed is dealt to the attacker (nearest enemy if gone).

## 2026-11-26: Renderer backend test (Vulkan vs Direct3D 12)

Measured with the release build (`build\purge.exe -- --bench=8`) at 3440x1440 borderless on the
target PC (Ryzen 9 5950X, Radeon RX 9070), uncapped, MSAA 2x, glow on. The stress scene keeps 60
enemies alive, all firing rings, with about 500 bullets on screen.

| Scene | Driver | Average fps | 1% low fps | 99th percentile frame |
|---|---|---|---|---|
| Stress | Vulkan | 379 to 432 | 168 to 171 | 5.8 to 5.9 ms |
| Stress | Direct3D 12 | 463 to 491 | 183 to 199 | 5.0 to 5.5 ms |
| Normal play | Vulkan | 670 | 265 | 3.8 ms |
| Normal play | Direct3D 12 | 784 | 306 | 3.3 ms |

**Decision: Direct3D 12 is the default driver on Windows** (`rendering_device/driver.windows`).
Vulkan remains available with `--rendering-driver vulkan`.

Open performance item: normal play is far above 240 fps, but in the stress scene about 2 to 6% of
frames still take longer than 4.6 ms, so the "stable 240 in the heaviest scene" target is not met
yet. GPU time is under 0.5 ms and game scripts average 0.7 ms per frame, so the long frames come
from the engine's render/present step, not from gameplay code. To be profiled further (frame pacing
with a 240 cap, tick/frame alignment) before bosses arrive in Milestone 5.

## 2026-11-26: Other Milestone 2 decisions

- The HUD is built from retained nodes that only change when a value changes; drawing text every
  frame in script cost over 2 ms on redraw frames.
- Bullets upload only position and velocity; the shader orients and stretches the sprite and steps
  it back along its velocity for render interpolation.
- Tests live in `game/tests/` (they must be inside the Godot project to run); `tools/test.ps1` runs them.
- Command-line switches (`--windowed`, `--set=key=value`, `--bench`) never write to the saved settings.

## 2026-11-26: Owner feedback after Milestone 2

- Controls and the build "work good"; go-ahead to continue past Milestone 2.
- **Stage look (design change):** at least some stages fly low over the planet surface, close enough
  to see the ground. Set 1: buildings, roads, grasslands. Set 2: the same kind of world visibly
  infested (buildings, roads, forests overgrown by the swarm). Set 3: like the normal world but red,
  cracked and with flowing lava. Orbital backgrounds remain an option for other stages.
- Implemented as a level background type: `"background": { "type": "terrain" | "orbit", ... }` in the
  level file. The terrain type is a procedural ground shader plus streamed 3D buildings; a
  `corruption` value is reserved for the infested and burning variants.
- Bug fixed: the mouse cursor stayed visible at startup until the pause menu was opened and closed.
  The capture is now re-applied during the first frames and when the window regains focus.
- **Performance finding:** with the terrain background the release build runs the stress scene
  (60 enemies, about 500 bullets, 3440x1440, Direct3D 12) at about 1300 fps average with a 1% low of
  about 745 fps and no frame over 4.6 ms. The long frames seen in Milestone 2 therefore came from the
  orbital background (procedural planet and starfield shaders), not from gameplay. The orbital
  background must be made cheaper (for example by baking the planet to a texture) before it is used
  in a real stage.

## 2026-11-26: Milestone 3 decisions (data systems)

- **Schemas** are JSON Schema (draft-07 subset) in `data/schemas/`. The validator supports `type`,
  `properties`, `required`, `additionalProperties`, `items`, `enum`, `minimum`, `maximum`, `minItems`,
  `maxItems`, plus one custom keyword, `x-ref`, which says a string must be a known id of a kind
  (tech, enemy, movement, attack, damage_type, model, sprite, sound, shield_visual). Unknown fields
  are errors, so typos are caught.
- **Mods override whole data files** by relative path, and extra files in `mods/data/tech` or
  `mods/data/enemies` are merged in. Per-field patching was rejected as harder to reason about.
  Asset manifest entries are overridden one id at a time.
- **Patterns are separate objects referenced by id**; an enemy has one movement pattern and up to
  four attack patterns, and a level wave may override the movement.
- **A stage ends** when all waves have spawned and no enemy is left. Until the results screen and
  shop exist (Milestone 4) the game rolls on to the next level of the set after 3.5 seconds.
- **Models load at runtime** from `.glb` through the asset manifest; sounds from `.ogg` or `.wav`.
  Built-in looks are named placeholders in the same manifest, so real art replaces them one id at a time.
- The validator runs at startup in debug builds only; release builds skip it to keep loading fast.
- Hot reload (F6) is available in debug builds only and restarts the current level.

## 2026-11-26: Startup cursor ring

- Symptom (owner's PC): a blue ring stayed at the screen centre from launch until the pause menu
  was opened and closed. It is the Windows launch-feedback cursor. Godot polls messages instead of
  blocking on them, so Windows never ends that feedback early, and because a captured pointer never
  moves, nothing refreshes the stale image. Hiding an already hidden pointer is a no-op.
- Fix: during play the pointer image is transparent, and once a second the mouse mode is switched to
  visible and back to captured in the same frame, which forces a real pointer change.

## 2026-11-26: Start menu instead of cursor workarounds (owner's suggestion)

- Four timed attempts to hide the Windows launch ring from code all failed on the owner's PC; hiding
  only worked when it followed a real key press or click (the pause menu). The timed workarounds
  were removed.
- The game now opens on a start menu (the pause menu with a Start button), so play always begins from
  a click or key press. Benchmark and demo runs skip it. This menu grows into the main menu in Milestone 4.

## 2026-11-26: Milestone 4 decisions (shop and tech tree)

- **Tech tree size:** 80 items. Shields: Bulwark, Flicker, Mirror (5 tiers each). Weapons: Pulse Laser
  (bolts, twin bolts, then a beam), Scatter Emitter (particle fan), Arc Phaser (sweeping piercing beam),
  Coil Rail (charged instant line), Chain Gun, Flak Cannon (explosive splash), 5 tiers each.
  Specials: Seeker Pod, Hornet Swarm, Breaker Torpedo, Cluster Bomb, Shockwave Bomb, Mine Layer
  (3 tiers each). Reactors: Fission Cell I-II, then Steady (Lattice) or Surge (Surge Bank) for tiers
  3-5. Armor: Standard, then Heavy or Reactive for tiers 2-5. Steady/Surge and Heavy/Reactive are
  mutually exclusive (`excludes`, which works in both directions).
- **Start of a run:** 3,000 credits (x difficulty), owning Fission Cell I, Standard Plating and Pulse
  Laser I. No shield, no second weapon and no special: the first shop visit is a real choice.
- **Ammo counts uses.** A Seeker Pod use fires a volley of 3-5 missiles; buying a special fills it.
- **Selling:** blocked for items another owned item is built on, and for the equipped reactor or
  armor (the ship needs one of each). Buying the next tier of the equipped branch equips it.
- **Hull damage carries between stages** and is repaired in the shop (3 credits per point, partial
  repairs allowed). A death restarts the stage with the armor and ammo the stage began with.
- **Stage results** use `economy.json` "results": kill credits, kill-percentage tiers, accuracy
  (scaled above 20%), hull bonus (full bonus with no hull damage), boss kill and boss time bonus
  (levels mark boss waves with `"boss": true` and set `boss_par_time`), then the difficulty multiplier.
  Pickups and secrets have their lines ready but arrive with the level content in Milestone 5.
- **Accuracy** counts each primary-weapon projectile once (pierce hits do not inflate it); beams count
  one shot per 0.1 s of firing; specials are not counted.
- **Saves:** three slots, JSON in the user folder, version 1, saved when entering the shop and when
  launching a stage. Quitting mid-stage resumes at the shop before that stage. Loading a save starts
  a new shop visit, so same-visit full refunds do not survive a reload.
- **Unlocks:** completing a set is remembered in `user://profile.json`; single-set play offers a set once
  the one before it is completed, all sets in debug builds or when `unlock_all_sets` is true.
- **Every way into play still starts from a click** (Launch in the shop), keeping the cursor fix.
- **Quick play** (`--level`, the debug "Test range" button, benchmarks) skips the shop and saving.
