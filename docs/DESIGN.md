# purge: design document

Living document. The original brief is `GAME_BUILD_INSTRUCTIONS.md`; its tables of starting
content (tech tree, enemies, level sets) remain the reference until they exist as data files, at
which point the data files are the truth. Decisions and their reasons are in `DECISIONS.md`.

## 1. The game

An original top-down vertical scrolling shooter. The level scrolls forward on its own, the player
flies one ship with the mouse, destroys scripted waves, and spends credits on upgrades between
stages. Only the genre and mechanics come from classic PC shooters; every name, ship, weapon,
sound, layout and level is our own.

### Pillars

1. **Mouse-driven, responsive flying**, precise at 240 Hz.
2. **Meaningful shop choices**: branching upgrades with real trade-offs.
3. **Power management in combat**: the wheel shifts reactor power between shields and weapons.
4. **Everything is data**: JSON files the owner can edit without touching code.
5. **Looks good and runs fast**: modern effects, readable bullets, stable 240 fps at 3440x1440.

## 2. Flow of a run

Main menu (Campaign or Single Set, difficulty Easy/Normal/Hard) -> shop with starting credits ->
stage (auto-scroll, scripted waves, mini-boss or boss) -> results with a line-by-line credit
breakdown -> shop -> next stage. On death the stage restarts with the loadout, armor, shields and
special ammo the player entered it with; credits from the failed attempt are dropped. A set is 5
stages; the campaign is every set in order (15 stages at launch).

## 3. Controls

| Input | Action |
|---|---|
| Mouse | Move the ship (relative by default, absolute optional) |
| LMB / RMB (hold) | Fire weapon 1 / weapon 2 |
| Wheel up / down | Shift power toward weapons / shields, 10% per notch by default |
| MMB | Special weapon |
| Esc | Pause (releases the mouse) |
| F3 | Debug overlay |

All bindings are actions in the input map and will be rebindable in the options menu.
In relative mode the mouse moves an invisible aim point; the ship chases that point, limited by
its maximum speed and acceleration, so engine and hull upgrades can change how it handles.

## 4. Ship systems

- **Reactor**: energy per second plus a capacitor (the weapon energy pool size).
- **Shield**: absorbs damage first; recharges after a delay, faster with more shield power.
  Three branches: Bulwark (big, slow), Flicker (small, fast), Mirror (reflects and bleeds).
- **Armor**: hit points and per-type resistances; never regenerates in a stage.
- **Weapon 1 / Weapon 2**: any primary weapon in either slot. Energy weapons (laser, particle gun,
  phaser) cost a lot of energy and scale strongly with weapon power. Kinetic weapons (railgun,
  chain gun, autocannon) cost little energy but have heat, spin-up, spread or slow fire.
- **Special**: one slot, limited ammo bought in the shop.

Damage types are Energy, Kinetic and Explosive; every enemy and armor has a resistance per type.
The formulas are listed in `DECISIONS.md` and their numbers live in `data/tech/power_model.json`.

## 5. Content plan

- **Tech tree** (Milestone 4): 3 shield branches, 6 weapon families, 6 specials, reactors with a
  Steady/Surge split, armor with a Heavy/Reactive split; 4 to 5 tiers each.
- **Set 1 "Frontier"**: mechanical faction above Earth-like worlds; balanced resistances.
- **Set 2 "Bloom"**: biological swarm; weak to kinetic and splash, some enemies regenerate.
- **Set 3 "Pyre"**: demonic technology; heavy units resist kinetic and explosive, fire area denial.
- **Stage backdrops:** most stages fly low over the surface so the ground is readable: towns, roads
  and grassland in set 1; the same world overgrown and infested in set 2; scorched, cracked and
  lava-streaked in set 3. Some stages (orbital approach, fleet blockade) stay in orbit.
- Stage 3 of each set has a mini-boss, stage 5 a multi-phase boss with destructible parts.

## 6. Technical plan

### Architecture

```
game/scripts/
  core/      settings, data loading, input actions (autoloads)
  sim/       fixed-step gameplay: player, weapons, bullet pools, enemies, spawner. No nodes.
  view/      3D presentation: camera, background, models, bullet MultiMeshes, effects
  ui/        HUD panels, debug overlay, pause menu (later: menus, shop)
```

- `main.gd` owns the loop: it feeds input into the simulation every physics tick (240 Hz) and the
  view draws an interpolated picture of the last two ticks every rendered frame.
- The simulation reports what happened through a flat event buffer (hits, explosions, shots); the
  view and audio read it. Nothing in `sim/` calls into presentation.
- Pools everywhere in hot paths: bullets are struct-of-arrays with swap-remove, enemies and enemy
  models are reused, effects are a fixed-size array.

### Rendering

- The world renders into a SubViewport sized `playfield pixels * render scale`, displayed centered.
- Perspective camera, 30 degree FOV, 10 degree tilt, so background layers get real parallax.
- HDR glow, emissive engines and bullets. Enemy bullets use a solid bright shape with a dark rim so
  they read on any background; player bullets are additive streaks.
- Background: procedural starfield and nebula shader plus a procedural planet (continents, clouds,
  atmosphere rim) that drifts with the scroll.

### Performance plan

- Budget 4.16 ms per frame. A `--bench` switch runs a fixed stress scene (many enemies, hundreds
  of bullets) and prints average fps, 1% low and worst frame, so every milestone has a number.
- F3 overlay: fps, frame-time graph, entity and bullet counts, draw calls, simulation time.

### Data and modding

- JSON under `data/`, loaded loose at runtime; a schema per type and a validator in Milestone 3.
- Assets by id through `data/assets.json`; `mods/` overrides by id or path; missing assets fall
  back to a visible placeholder.

### Testing

- Headless test runner (`tests/`) for damage and resistance maths, shield branches, the power
  split, credits, shop rules, save round trip and data validation, growing with each milestone.

## 7. Milestones

1. Questions and plan (done 2026-11-26)
2. Playable core
3. Data systems
4. Shop and tech tree
5. Set 1 complete
6. Set 2 complete
7. Set 3 complete
8. Polish and performance
