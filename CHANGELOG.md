# Changelog

## Fixes after Milestone 3 feedback (2026-11-26)
- Cursor capture is re-applied on a timer (0.2 to 4 seconds after start and after regaining focus);
  the earlier frame-counted fix finished within a few milliseconds at high framerates.
- Level changes are now obvious: a banner names the set, stage and level, and each level flies over
  its own part of the map (`map_offset` in the level background).

## Milestone 3: Data systems (2026-11-26)
- JSON Schemas for every data type in `data/schemas/`.
- Data validator (`tools\validate.ps1`, and at startup in debug builds): schema checks, id
  cross-references, duplicate ids, tech tree cycles and unreachable nodes, missing asset files.
- Reusable movement patterns (straight, sine, zigzag, swoop and hold, dive, circle, path) and
  attack patterns (aimed fan, ring, spiral, downward fan, bursts) in `data/enemies/patterns.json`.
- Two new enemies built purely from data and patterns: Dart and Sentry Platform.
- Level sets and level timelines from data, with scroll speed changes and stage clear. First real
  stage: Frontier 1 "Coastal Approach". The endless test range is now the hidden `sandbox` set.
- Asset manifest `data/assets.json` for models, sprites, sounds and shield colours, with runtime
  `.glb`, `.ogg` and `.wav` loading and a visible placeholder for anything missing.
- `mods/` override folder for data files and asset entries.
- Hot reload with F6, level select with PgUp and PgDn or `--level=<set>/<number>`.
- `docs/MODDING.md` written; 36 rule tests.

## After Milestone 2 feedback (2026-11-26)
- New low-altitude terrain background (fields, forest, river, roads, city blocks with 3D buildings),
  selected per level with `"background": { "type": "terrain" }`. The test range now uses it.
- Fixed the mouse cursor staying visible at startup.

## Milestone 2: Playable core (2026-11-26)
- Godot 4.7.2 project in `game/`, fixed 240 Hz simulation with interpolated rendering.
- Mouse flying (relative by default, absolute optional), weapon 1 on LMB, weapon 2 on RMB,
  wheel power split in 10% steps with HUD and sound feedback, Esc pause, F3 overlay.
- Reactor, weapon energy pool, shields (Bulwark, Flicker and Mirror tier 1 selectable from the
  pause menu), armor, death and stage restart.
- Pulse Laser I (energy, scales with weapon power) and Chain Gun I (kinetic, spin-up, spread, heat).
- Two enemies (Interceptor Drone, Picket Gunship) in a looping test range, all from JSON in `data/`.
- 3D placeholder models, procedural planet and starfield, glow, bullet and spark effects, screen shake.
- Centered fixed-aspect playfield with HUD side panels; scales on 16:9 and 21:9.
- Synthesized placeholder sounds.
- `--bench` stress benchmark, 23 headless rule tests, `tools/run.ps1`, `tools/build.ps1`, `tools/test.ps1`.
- Direct3D 12 chosen over Vulkan after measurement (see `docs/DECISIONS.md`).
- Known issues: stress scene does not yet hold a stable 240 fps (average is above 460); no special
  weapons, shop, damage numbers or options menu yet; rebinding is not exposed in a menu yet.

## Milestone 1: Questions and plan (2026-11-26)
- Owner questions asked and answered; recorded in `docs/DECISIONS.md`.
- `docs/DESIGN.md` (living design document and technical plan) written.
- Repository structure, `.gitignore`, Git LFS rules, README and doc stubs created.
