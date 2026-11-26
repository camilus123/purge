# Changelog

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
