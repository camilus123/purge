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

## Renderer backend test (Vulkan vs Direct3D 12)

*(Filled in at the end of Milestone 2 with measured numbers.)*
