# Build Instructions: Top-Down Vertical Shooter "purge"

These are your instructions as the AI developer of this project. Read the whole document before you do anything else.

- **Local working folder:** the folder this file is in.
- **GitHub repository:** `purge`. The game is also called **purge**.
- **Owner:** the person who gave you this file. They make the final call on anything that changes the design.

---

## 0. STOP: ask questions before you start

**Do not write any code, create the repository structure, or download anything until you have asked the owner your clarifying questions and received answers.**

1. Read this whole document.
2. Write a short list of questions, grouped by topic, covering anything that is ambiguous, contradictory, or that you would otherwise have to guess. Put the most important questions first. Suggest a default answer for each one so the owner can just say "default is fine".
3. Wait for the answers. Record them in `docs/DECISIONS.md` (create it) with the date.
4. Only then start Milestone 1.

The owner has already decided the engine, the visual style, the playfield layout and what happens on death (see "Owner decisions" at the end of this file); do not ask about those again. Questions you should still ask at minimum:

- Difficulty levels wanted (default: Easy / Normal / Hard, selected at the start of a run).
- Whether the GitHub repo should be public or private, and the license (default: private, all rights reserved).
- Any placeholder-art sources the owner does or does not want used.

Also ask questions **during** the project whenever a decision would change the design or cannot easily be undone. For small implementation details, make a sensible choice, note it in `docs/DECISIONS.md`, and carry on.

---

## 1. What we are making

An **original** top-down vertical scrolling shooter in the tradition of classic PC shooters such as Tyrian: the camera looks down, the level scrolls forward, the player flies a ship with the mouse and destroys waves of enemies, then spends earned credits on upgrades between stages.

**Originality rule (mandatory):** take the *genre and mechanics* only. Do not copy names, characters, ships, weapons names, story, art, music, sounds, UI layout, or level designs from Tyrian or any other existing game. All names in this document are suggestions you may improve, but they must stay original.

### Design pillars

1. **Mouse-driven, responsive flying.** The ship must feel precise and instant at 240 Hz.
2. **Meaningful choices in the shop.** Branching upgrades with real trade-offs, not just bigger numbers.
3. **Power management in combat.** The mouse wheel shifts reactor power between shields and weapons, and that choice should matter moment to moment.
4. **Everything is data.** Upgrades, weapons, enemies, waves, levels, economy and asset references live in editable data files, so the owner can rebalance or extend the game without touching code.
5. **Looks good and runs fast.** Modern effects, readable bullets, and a locked high framerate.

---

## 2. Target hardware and performance

Develop and tune for this PC (Windows 11):

| Part | Spec |
|---|---|
| CPU | AMD Ryzen 9 5950X (16 cores) |
| GPU | AMD Radeon RX 9070 |
| RAM | 64 GB DDR4-3600 |
| Storage | NVMe SSD |
| Monitor | AOC CU34G4Z, 34" ultrawide, **3440x1440, 240 Hz**, VA panel |

Requirements:

- **Native target: 3440x1440 at a stable 240 fps** (4.16 ms frame budget) during the heaviest scenes, such as boss fights with hundreds of bullets and many particles. Measure the worst case, not the average.
- Support other resolutions and aspect ratios too (16:9 at 1080p/1440p/4K, 21:9), plus windowed, borderless fullscreen and exclusive fullscreen.
- Options: VSync on/off, framerate cap (60/120/144/165/240/uncapped), render scale, and quality presets (Low/Medium/High/Ultra) that scale effects, shadows, particle counts and post-processing.
- Gameplay simulation must be framerate independent (fixed timestep for gameplay logic, interpolated rendering), so the game behaves the same at 60 fps and 240 fps.
- The GPU is AMD: avoid NVIDIA-only features. Test with Vulkan (and DirectX 12 if the engine offers it) and pick whichever runs best; record the result in `docs/DECISIONS.md`.
- Include an on-screen debug overlay (toggle with F3) showing fps, frame time graph, entity count, bullet count and draw calls.
- Do performance work with a profiler, not guesses. Use object pooling for bullets, enemies, pickups and effects. Do not allocate per-frame garbage in hot paths. Batch or instance bullets and repeated meshes.
- Load times between stages should be short (under about 3 seconds on the target PC).

---

## 3. Technology (decided by the owner)

- **Engine:** Godot 4. A copy is already on the owner's PC in `H:\temp\godot`. Use that copy: check which version it is (and whether it is the standard or the .NET/C# build) before you start, record it in `docs/DECISIONS.md`, and pin the project to that version. If it is too old or missing something you need, ask the owner before downloading another version. Reasons: free, good 2D and 3D, text-based scene and resource files that work well with Git and with AI editing, easy Windows export.
- **Language:** GDScript for most gameplay. C# (only if the copy in `H:\temp\godot` is the .NET build) or GDExtension is allowed for performance-critical systems such as the bullet manager if profiling shows it is needed.
- **Visual style (decided):** 3D models on a fixed top-down (slightly tilted) camera, gameplay on a 2D plane ("2.5D"). This makes swapping models and textures straightforward and looks good at high resolution.
- **Data files:** JSON (human-readable, easy to edit in any text editor), each type with a JSON Schema in `data/schemas/`. If you prefer a different format (for example YAML or Godot `.tres` resources), ask first and explain why.
- **Build output:** a Windows x64 executable that runs without installing anything else.

---

## 4. Repository and workflow

- Initialise the local folder as a Git repository connected to the GitHub repo `purge`. Use **Git LFS** for binary assets (models, textures, audio).
- Add a proper `.gitignore` for the engine, a `README.md` (what the game is, how to build, run and mod it), and `docs/`.
- Work in small, focused commits with clear messages. Use a branch per milestone or feature and merge to `main` when it works. `main` must always build and run.
- Keep these documents up to date:
  - `docs/DESIGN.md`: the living game design document (start from this file).
  - `docs/DECISIONS.md`: questions, answers and decisions, with dates.
  - `docs/MODDING.md`: how to edit data and replace models, textures and sounds.
  - `CHANGELOG.md`: what changed in each milestone.
- At the end of each milestone, push to GitHub and give the owner a short summary: what works, how to try it, known issues, and what is next.
- Never commit secrets, and never add assets whose license you cannot document (see section 12).

Suggested layout:

```
/game            engine project (scenes, scripts)
/data            all gameplay data (JSON)
  /schemas       JSON Schemas for every data type
  /tech          tech tree, weapons, shields, reactors, armor, specials
  /enemies       enemy definitions, movement and attack patterns
  /levels        one folder per level set, one file per level
  economy.json
  difficulty.json
  assets.json    asset manifest (ids -> files)
/assets          models, textures, audio, fonts (Git LFS)
/mods            empty; user overrides go here (see section 12)
/tools           data validator, balance helpers
/tests           automated tests
/docs
```

---

## 5. Controls

Mouse is the primary and default input. Every binding must be rebindable in the options menu.

| Input | Action |
|---|---|
| Move mouse | Move the ship |
| Left mouse button (hold) | Fire **Weapon 1** |
| Right mouse button (hold) | Fire **Weapon 2** |
| Both buttons | Fire both weapons at the same time |
| Mouse wheel up | Shift power toward **weapons** (one step per notch) |
| Mouse wheel down | Shift power toward **shields** (one step per notch) |
| Middle mouse button | Fire the **special weapon** (ammo limited) |
| Esc | Pause menu |
| F3 | Debug/performance overlay |

Details:

- **Mouse movement:** capture and hide the OS cursor during gameplay. Default mode is *relative*: mouse movement moves the ship, scaled by a sensitivity setting, limited by the ship's maximum speed and acceleration (so engine/hull upgrades can matter). Offer an *absolute* mode as an option, where the ship moves toward the cursor's position on the playfield. Use raw mouse input with no OS acceleration. The ship stays inside the playfield.
- **Wheel power split:** power is shown as a percentage split between shields and weapons, from 0/100 to 100/0, default 50/50. Default step size is 10% per notch (configurable). Show the split clearly on the HUD and give audio and visual feedback on every change. Wheel direction is invertible in options.
- Make sure the wheel and middle button work reliably together (pressing the wheel must not also scroll).
- Release the mouse when the game is paused or loses focus.
- Gamepad support is a nice-to-have for later; design the input layer so it can be added (sticks for movement, triggers for weapons, shoulder buttons for the power split).

---

## 6. Core gameplay systems

### 6.1 Flow of a run

1. Main menu: choose **Campaign** (all sets in order) or **Single Set** (any one set, five levels), choose difficulty.
2. **Shop** before the first stage, using a fixed starting amount of credits.
3. Play a stage: it scrolls forward automatically, enemies arrive in scripted waves, the stage ends with a mini-boss or boss.
4. **Results screen** that shows how well the player did and the credits earned, broken down line by line.
5. **Shop** again, then the next stage. Repeat.
   - **If the ship is destroyed**, the stage restarts from the beginning. The player keeps all upgrades they own (the loadout they entered the stage with), with armor, shields and special ammo restored to what they had at the start of the stage. Credits earned during the failed attempt are not kept.
6. After the last stage of a set (or the campaign), show an end screen with run statistics.

### 6.2 Ship systems and the power model

The ship has these systems, each upgradable through the tech tree:

- **Reactor:** produces energy per second and has a small energy buffer (capacitor).
- **Shield generator:** absorbs damage before the hull; recharges using power.
- **Armor (hull):** hit points; when it reaches zero the ship is destroyed. Armor does not regenerate during a stage (repair is bought in the shop).
- **Weapon 1 and Weapon 2:** primary weapons, unlimited use, powered by the reactor. Either slot can mount any primary weapon, energy or kinetic.
- **Special weapon:** one slot, limited ammo, ammo bought in the shop.

**Power split:** reactor output is divided by the wheel setting. The shield share drives shield recharge speed. The weapon share fills a weapon energy pool that both weapons draw from when firing.

- **Energy weapons** (lasers, particle guns, phasers) use a lot of energy per shot and scale strongly with the weapon power share (for example more damage or faster firing when weapons get more power).
- **Kinetic weapons** (railguns, chain guns, autocannons) use little energy (just to run the loader and magnetic rails), so they are less affected by the power split, but they have drawbacks such as heat build-up, spin-up time, spread or slow fire rate.
- If the weapon energy pool is empty, weapons fire at a reduced rate rather than stopping completely.
- Running both weapons at once drains the pool faster, which is the main reason to manage power.

All of these formulas and their numbers must come from data files (for example `data/tech/power_model.json`), not constants in code.

### 6.3 Damage model

- Damage types: **Energy**, **Kinetic**, **Explosive** (more can be added in data).
- Every enemy and the player have per-type resistances in data. This lets each level set favour different weapons (see section 9).
- Order of damage on the player: shield first (with branch-specific behaviour, see 7.1), then armor.
- Show clear feedback: shield hit flash, hull damage sparks, low-health warning, and enemy hit flashes and damage numbers (damage numbers can be turned off).

### 6.4 Pickups

Enemies can drop small pickups defined in data: credits, a little armor repair, shield restore, special ammo. Keep drops modest so the shop remains the main source of power.

---

## 7. Tech tree (starting content, fully data-driven)

The whole tech tree lives in data files under `data/tech/`. The owner must be able to add, remove, rename and rebalance any item and change the tree structure **without changing code**. The numbers below are starting values for balance testing, not final.

Each tech node needs at least: `id`, display name, description, category (shield, weapon, special, reactor, armor, other), branch, tier, credit cost, prerequisites (list of node ids), mutually exclusive nodes (if any), the stats it sets or modifies, and asset ids for its icon, model, projectile, effects and sounds.

Shop rules (defaults, configurable in `economy.json`):

- Buying a node requires its prerequisites. Higher tiers in a branch require the previous tier.
- Items can be sold back. Full refund if sold in the same shop visit, otherwise a percentage (default 75%).
- The player can only *equip* one item per slot (one shield, one reactor, one armor, one weapon per weapon slot, one special) but can *own* several and swap them freely in the shop.
- The shop shows the tree visually, with locked, available, owned and equipped states, and shows a stat comparison against the currently equipped item before buying.

### 7.1 Shields: three branches

| Branch | Idea | Tier 1 starting values (example) | How it grows |
|---|---|---|---|
| **Bulwark** (heavy) | Large capacity, slow recharge, long delay before recharge starts after a hit | Capacity 200, recharge 8/s, delay 3.0 s | Capacity grows fastest |
| **Flicker** (light) | Small capacity, very fast recharge, short delay | Capacity 60, recharge 30/s, delay 0.6 s | Recharge speed and short delay grow fastest |
| **Mirror** (reflective) | Medium capacity. A share of absorbed damage is **reflected back at the attacker** (or the nearest enemy, if the attacker is gone) and a share **passes through to the hull** | Capacity 110, recharge 14/s, reflect 25%, bleed-through 20% | Reflect share rises, bleed-through drops |

Give each branch 4 to 5 tiers. Shield recharge speed is multiplied by the shield power share. Each branch should have a distinct look and sound (for example a solid dome, a crackling flicker, a mirrored hex pattern).

### 7.2 Primary weapons (Weapon 1 and Weapon 2)

Each weapon family should have 4 to 5 tiers. Higher tiers can change behaviour, not just numbers (more beams, wider spread, piercing, splash). Each family needs a clear role so loadout choices matter.

**Energy weapons**

| Family | Role | Behaviour |
|---|---|---|
| **Laser** | Precise single-target damage | Fast straight bolts at low tiers, continuous beam at high tiers. High energy use. |
| **Particle gun** | Area coverage | Spreads of charged particles that fan out; wider fan and more particles per tier. |
| **Phaser** | Crowd control | A beam that sweeps or arcs across the screen and pierces through several enemies. |

**Kinetic weapons**

| Family | Role | Behaviour |
|---|---|---|
| **Railgun** | Heavy hitter | Slow-firing, instant, piercing shot with a short charge-up. Great against armored targets. |
| **Chain gun** | Sustained fire | Very high fire rate with spin-up time and spread. Builds heat; overheats if fired too long. |
| **Autocannon** | Versatile | Medium-rate explosive shells with small splash damage. |

All weapon stats in data: damage, damage type, fire rate, projectile speed, spread, pierce, splash radius, energy per shot, heat per shot, spin-up, charge time, behaviour scaling with power share, projectile and effect asset ids, sounds. Weapon behaviour should be built from reusable components (projectile, beam, spread, homing, pierce, splash) so new weapons can be made in data by combining them.

### 7.3 Special weapons (middle mouse, limited ammo)

| Special | Behaviour | Ammo (example) |
|---|---|---|
| **Seeker missiles** | Volley of homing missiles that pick separate targets | 12 |
| **Swarm rockets** | Many small, weak, wandering rockets | 6 volleys |
| **Heavy torpedo** | Slow, huge-damage shot for bosses | 4 |
| **Cluster bomb** | Bursts into bomblets over an area | 5 |
| **Shockwave bomb** | Clears enemy bullets on screen and damages everything | 2 |
| **Mine layer** | Drops proximity mines behind the ship | 10 |

Each special has tiers that improve damage, ammo capacity or behaviour. Ammo is refilled in the shop for credits. Ammo capacity, restock cost and everything else is data.

### 7.4 Reactors

Tiered reactors (around 5 tiers) that increase energy output and capacitor size. Consider one branching choice at a mid tier, for example **Steady** (high constant output) versus **Surge** (lower output but a large capacitor for bursts). Reactors are the main way to support more demanding weapon and shield combinations.

### 7.5 Armor

Tiered hull plating (around 5 tiers) that increases hit points and resistances. Consider two branches: **Heavy plating** (most hit points, slightly lower ship speed) and **Reactive plating** (fewer hit points, high explosive and kinetic resistance). Hull repair is bought in the shop between stages.

### 7.6 Room to grow

The data format must allow new categories later without code changes where possible, for example engines/thrusters, side pods or drones, utility modules (magnet for pickups, targeting computer). Do not build these now unless the owner asks, but do not design them out.

---

## 8. Economy and scoring

- **Before the first stage:** a fixed starting amount (data, for example 3,000 credits on Normal).
- **After each stage**, credits are based on how well the player did. Suggested components (all weights in `economy.json`):
  - Credits from enemies destroyed (each enemy has a credit value).
  - Percentage of enemies destroyed in the stage (bonus tiers, for example 50/75/90/100%).
  - Accuracy bonus.
  - Damage-taken bonus (bigger bonus for less hull damage; a "no hull damage" bonus).
  - Boss kill bonus and time bonus for killing the boss quickly.
  - Pickups collected and secrets found.
  - Difficulty multiplier.
- Show every component on the results screen so the player understands what earned them money.
- When playing a **single set** on its own, the player starts with a credit amount (and optionally a starting loadout) appropriate for that set's difficulty, defined per set in data, so set 2 or set 3 is playable and fair without playing the earlier sets.
- Provide a simple balance tool or spreadsheet export in `/tools` that estimates expected credits per stage against tech costs, so the progression curve can be checked.

---

## 9. Enemies (data-driven)

All enemies are defined in `data/enemies/`. The owner must be able to add new enemy types and tweak stats without code.

Each enemy definition includes: `id`, name, faction/set, hit points, resistances per damage type, collision damage, speed, size/hitbox, credit value, drop table, movement pattern id(s), attack pattern id(s), behaviour phases (for bosses), and asset ids (model, textures, death effect, sounds).

- **Movement patterns** (reusable, in data): straight, sine wave, dive at player, swoop in and hold position, circle, follow a path/spline, formation flying, stationary turret attached to terrain or a larger ship, etc.
- **Attack patterns** (reusable, in data): aimed shot, spread, ring burst, spiral, beam, homing projectile, spawn other enemies, kamikaze, area denial (mines, acid pools, fire), etc.
- **Bosses:** multi-phase with separate destructible parts (turrets, weak points), each phase defined in data with its own patterns.
- Enemy bullets must be easy to read against every background: bright, high-contrast colours and shapes that differ from the player's bullets.

### Difficulty curve

Difficulty rises across the 5 stages of a set and across the 3 sets. Difficulty settings (Easy/Normal/Hard) scale enemy health, damage, bullet speed and density, and credit rewards through `difficulty.json`.

---

## 10. Levels: 3 sets of 5 (extendable)

- Each **level set** is a folder in `data/levels/` with a `set.json` (name, theme, order, music, starting credits and loadout for single-set play) and one file per level.
- **Adding a new set or level must only require adding data and assets**, and new sets must automatically appear in the menu and in the campaign order.
- Each level file defines: name, length or duration, scroll speed (can change during the level), background layers (planet, clouds, terrain, space debris, parallax), lighting/colour mood, music, and a **timeline of waves**: what spawns, when, where, and with which patterns. Also mid-level events, the boss, and any secrets.
- **Campaign mode:** all sets in order (15 stages), upgrades and credits carry over.
- **Single-set mode:** one set of 5 stages, starting from that set's configured credits/loadout.
- Make a simple way to test a single level directly (debug level-select, start with a chosen loadout).

Each set has its own enemy faction, visual theme, music style and a final boss at stage 5. Stage 3 should have a mini-boss. All names below are suggestions; keep them original.

### Set 1: "Frontier" (classic sci-fi)

- **Setting:** orbit and upper atmosphere above lush, Earth-like planets: blue oceans, green continents, white clouds, orbital stations, asteroid fields, city lights on the night side.
- **Enemies:** a technological, mechanical faction: interceptor drones, fighters in formations, gunships, mine-layers, turrets on stations, shield-projecting support ships, carriers that launch fighters.
- **Weakness design:** mostly balanced resistances; good for learning every weapon.
- **Stages (example):** 1 Orbital approach (tutorial-like) · 2 Asteroid belt · 3 Shipyard (mini-boss: station defense platform) · 4 Atmospheric descent over an ocean world · 5 Fleet blockade (boss: a capital ship with destructible turrets).

### Set 2: "Bloom" (biological hive mind)

- **Setting:** above Earth-like planets that are being infested: organic growth spreading across continents, purple and sickly green creep, spore clouds in the atmosphere, living bio-structures in orbit.
- **Enemies:** an original insectoid/biological swarm with a hive mind: fast swarming critters in huge numbers, acid spitters, armored beetle-like tanks, spore pods that burst into smaller enemies, regenerating tissue walls, flying brood carriers, synapse creatures that make nearby enemies stronger (kill them first).
- **Weakness design:** low kinetic resistance and weak to explosive splash, but some enemies regenerate, so sustained damage matters. Swarms reward area weapons.
- **Stages (example):** 1 First contact over a still-healthy world · 2 Spreading infestation · 3 Spore storm (mini-boss: brood carrier) · 4 Inside a living orbital hive · 5 The heart of the swarm (boss: a giant hive-mind organism with several phases).

### Set 3: "Pyre" (demonic technology)

- **Setting:** planets that are a mix of Earth and hell: half green and blue, half cracked, burning and covered in lava; rifts in the sky; demonic iron fortresses in orbit; ash storms.
- **Enemies:** an original demonic faction fused with technology: flesh-and-steel imps with jetpacks, horned gunships, hellfire turrets, cybernetic hulks with heavy armor, portal-casters that summon enemies mid-wave, chained war-engines.
- **Weakness design:** high kinetic and explosive resistance on the heavy units, so energy weapons and railguns shine; lots of fire-based area denial.
- **Stages (example):** 1 The first rift · 2 Burning continents · 3 Iron citadel (mini-boss: a fortress gate guardian) · 4 Through the rift into the hellscape · 5 The throne world (boss: a towering techno-demon lord, final boss of the campaign).

---

## 11. Graphics, audio and feel

**Graphics target: a modern, polished look**, not retro pixel art (unless the owner says otherwise).

- Top-down camera with a slight perspective tilt; gameplay on a flat plane.
- Rich, multi-layer parallax backgrounds: rotating planets with atmosphere glow and moving clouds (a planet shader with procedural textures is a good start), space dust, distant ships, terrain where the level goes low.
- PBR or stylized lighting on ships, emissive materials for engines and weapons, bloom, HDR glow on lasers and explosions.
- Particles for engines, impacts, explosions, debris, shield hits, smoke. Screen shake and hit-stop that can be reduced or turned off in options.
- Strong readability: the player ship, enemy bullets and pickups must always be visible above effects. Add an optional colour-blind friendly bullet palette.
- **Playfield layout (decided):** a centered vertical playfield, with the HUD and decorative frame in the side areas of the ultrawide screen. The playfield must have a fixed gameplay aspect ratio so it plays the same on every monitor; only the side panels grow or shrink.
- HUD: armor bar, shield bar, power split gauge, weapon pool/heat, special ammo, credits, score, boss health bar. HUD scales correctly on 21:9 and 16:9.
- **Placeholder art:** start with simple but clean placeholder models and procedural effects so gameplay can be built first. Plan for final art later.
- **Audio:** distinct weapon sounds per family, impacts, explosions, shield sounds, UI sounds, low-health alarm, and music per set (calm shop music, action music for stages, boss music). Separate volume sliders for master, music, effects and UI.

---

## 12. Swappable models, textures and sounds (modding)

The owner wants to replace models and textures in the future. Build for that from day one:

- **No hard-coded asset paths in code or data.** Everything refers to an **asset id** (for example `ship.player.default`, `proj.laser.t1`, `enemy.hive.spitter.model`). `data/assets.json` maps ids to actual files.
- **Override folder:** at startup the game also loads `mods/` (next to the executable) and any asset or data file there with the same id or path overrides the built-in one. This works for models, textures, sounds, music and data files.
- Use common formats: glTF 2.0 (`.glb`) for models, PNG/KTX2 for textures, OGG for audio.
- Document the required model conventions in `docs/MODDING.md`: scale, forward direction, pivot, where engine, muzzle and weak-point markers go (named empty nodes), texture sizes and material slots.
- Hitboxes are defined in data, not taken from the model mesh, so a new model cannot break gameplay.
- Missing asset: log a warning and fall back to a visible placeholder instead of crashing.
- Track every third-party asset's source and license in `assets/CREDITS.md`. Only use assets that are licensed for this use (for example CC0). Ask the owner before adding anything with attribution or non-commercial requirements.

---

## 13. Menus, options and saving

- **Menus:** main menu, mode and set select, difficulty select, shop/tech tree, loadout, results screen, pause menu, options, credits.
- **Options:** display (resolution, window mode, VSync, fps cap, render scale, quality preset, individual effect toggles), audio volumes, controls (rebinding, mouse sensitivity, relative/absolute mode, invert wheel, power step size), gameplay (screen shake, damage numbers, colour-blind palette).
- **Saving:** autosave after every shop visit. Several save slots. Save files are human-readable JSON in the user's app data folder and have a version number so old saves can be migrated when the data changes.
- Unlocking: completing a set unlocks the next set for single-set play (configurable; the owner may prefer everything unlocked).

---

## 14. Code quality, tools and tests

- Keep data, gameplay logic and presentation separate. Gameplay rules read from the data, never the other way around.
- **Data validator** (`/tools`, also runs at game startup in debug builds): checks every data file against its schema, checks that all referenced ids (prerequisites, patterns, assets) exist, and that the tech tree has no cycles or unreachable nodes. Clear error messages with file and field.
- **Hot reload** of data files in debug builds so balance changes can be tested without restarting.
- **Debug menu** (debug builds only): invincibility, infinite credits, jump to any level, spawn any enemy, unlock all tech, show hitboxes, slow motion.
- **Automated tests** for the rules that are easy to break: damage and resistance maths, shield branch behaviour (reflect and bleed-through), power split, credit calculation, shop buy/sell/prerequisite rules, save/load round trip, and data validation.
- Comment non-obvious code. Keep functions small and names clear.

---

## 15. Milestones

Work through these in order. At the end of each one, push to GitHub, update `CHANGELOG.md`, and report to the owner (what works, how to try it, known problems, next steps). Ask for feedback before moving past Milestone 2, since the feel of the controls is the foundation of everything else.

1. **Questions and plan.** Ask your questions (section 0). Write `docs/DESIGN.md` and a short technical plan. Set up the repository.
2. **Playable core.** Ship with mouse control, both weapons on LMB/RMB, the wheel power split, shields and armor, a basic enemy, scrolling background, debug overlay. Running at 240 fps at 3440x1440.
3. **Data systems.** Data loading, schemas, validator, asset manifest and mod override folder, enemy movement and attack patterns, level timeline from data.
4. **Shop and tech tree.** Full starting tech tree from section 7, shop UI, credits and results screen, save/load.
5. **Set 1 complete.** All 5 stages, mini-boss and boss, set 1 enemies, art pass on placeholders, audio.
6. **Set 2 complete.**
7. **Set 3 complete.** Campaign and single-set modes both working end to end.
8. **Polish and performance.** Balance pass using the balance tool, effects and readability pass, options menu complete, profiling on the target PC, Windows release build, `README.md` and `docs/MODDING.md` finished.

---

## 16. Definition of done

The project is done when:

- A Windows build runs at a stable 240 fps at 3440x1440 on the target PC in the heaviest scenes on the High preset.
- All controls in section 5 work and can be rebound.
- Campaign (15 stages) and each set on its own (5 stages) can be played start to finish, with the shop before the first stage and after every stage.
- The tech tree, weapons, specials, enemies, levels, economy and difficulty are all defined in data files, validated, and documented, and a new enemy, weapon, tech node, level and level set can each be added without code changes (prove it by doing one of each as a test and documenting the steps in `docs/MODDING.md`).
- Models, textures and sounds can be replaced through the asset manifest or the `mods/` folder.
- Nothing in the game is copied from Tyrian or any other existing game.
- Tests and the data validator pass.

---

## Owner decisions

*(Answers here take priority over the defaults above. Anything not answered here is still a question to ask in section 0.)*

- Game name: **purge** (the GitHub repository is also named `purge`).
- Engine: **Godot 4**, using the copy in `H:\temp\godot`.
- Look: **3D models** on a top-down camera.
- Playfield layout: **centered** playfield with HUD side panels on the ultrawide screen.
- On ship destruction: **restart the stage and keep all upgrades.**
- Difficulty levels: *(not answered yet, ask)*
- Repo visibility / license: *(not answered yet, ask)*
- Other:
