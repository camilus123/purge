# Modding purge

Everything that defines the game lives in plain files you can edit with a text editor: gameplay
numbers in `data/`, and models, sounds and looks through `data/assets.json`. Files are read from
disk when the game starts (they sit next to `purge.exe` in a build), so nothing needs rebuilding.

- Press **F6** in a debug build (`tools\run.ps1`) to reload every data and asset file without restarting.
- Run **`tools\validate.ps1`** after editing. It checks every file against its schema and checks
  that every id you refer to exists. Errors name the file and the field, for example
  `data/levels/frontier/level_01.json: waves[3].enemy: unknown enemy id 'enemy.frontier.dartt'`.
  Debug builds run the same check at startup and show the error count on the HUD.

## Where things are

| File | What it holds | Schema |
|---|---|---|
| `data/tech/weapons.json`, `shields.json`, `reactors.json`, `armor.json` | Tech items | `data/schemas/<name>.schema.json` |
| `data/tech/ship.json` | The player hull: speed, acceleration, hitbox, muzzles, model id | `ship` |
| `data/tech/power_model.json` | Reactor power split numbers and the list of damage types | `power_model` |
| `data/economy.json` | Starting credits and starting loadout | `economy` |
| `data/enemies/patterns.json` | Reusable movement and attack patterns | `patterns` |
| `data/enemies/*.json` | Enemy definitions (any number of files) | `enemies` |
| `data/levels/<set>/set.json` | A level set: name, order, list of level files | `set` |
| `data/levels/<set>/<level>.json` | One level: background, scroll speed, wave timeline | `level` |
| `data/assets.json` | Asset manifest: asset id to file or placeholder | `assets` |

The schemas are ordinary JSON Schema files; most editors (VS Code included) can use them for
autocomplete and inline checking.

## The mods folder

`mods/` sits next to the game and is never overwritten by updates.

- **Data:** a file at `mods/data/<same path>` replaces the built-in file of that path entirely
  (for example `mods/data/tech/weapons.json`). A file with a new name under `mods/data/tech/` or
  `mods/data/enemies/` is loaded in addition, so a mod can add items without copying a whole file.
  A new folder `mods/data/levels/<set>/` adds a level set.
- **Assets:** `mods/assets.json` has the same shape as `data/assets.json`; its entries replace or
  add to the built-in ones id by id. File paths in the manifest are looked up in `mods/` first,
  then in the game folder.

## Coordinates and conventions

- Playfield: 90 units wide, 120 tall. `x` runs from -45 (left) to 45, `y` from -60 (top) to 60 (bottom).
- In 3D, gameplay `x` is world `X`, gameplay `y` is world `Z`, world `Y` points up at the camera.
- 1 unit is about 1 metre. Speeds are units per second, angles are degrees, times are seconds.
- Hitboxes are circles given in data (`radius`, `hitbox_radius`), never taken from a model.

## Recipes

### Add an enemy

Add an entry to any file in `data/enemies/` (or a new file there):

```json
{ "id": "enemy.frontier.wasp", "name": "Wasp", "faction": "frontier",
  "hp": 45, "resist": { "energy": 0.0, "kinetic": 0.1, "explosive": 0.0 },
  "collision_damage": 25, "speed": 40, "radius": 2.8, "credits": 30,
  "movement": "move.zigzag", "attacks": ["atk.aimed.burst3"],
  "model": "enemy.frontier.drone" }
```

`movement` and `attacks` name patterns from `patterns.json` (up to 4 attacks, each with its own
timer). `model` names an entry in `data/assets.json`; reuse an existing one or add a new one.

### Add or change a pattern

Movement types: `straight`, `sine` (amplitude, frequency), `zigzag` (width, period),
`swoop_hold` (hold_y, hold_time, drift), `dive` (delay, dive_speed), `circle` (center_y, radius,
angular_speed, time), `path` (points as `[x offset from spawn, y]`).

Attack types: `aimed` (fan of `count` over `spread_deg`, centred on the player), `ring` (`count`
bullets all round; `rotate_deg` turns it into a spiral), `fan_down`. Any attack can fire in volleys
with `burst` and `burst_interval`. `bullet_visual` names a sprite in the manifest.

### Add a level or a level set

A level is a timeline of waves. Each wave spawns `count` enemies, the first at time `t` and x
position `x`, each next one `dt` seconds later and `dx` units further along. A wave may override
the enemy's movement.

```json
{ "name": "Harbour Run", "scroll_speed": 12,
  "background": { "type": "terrain", "theme": "frontier" },
  "scroll_changes": [ { "t": 40, "speed": 18 } ],
  "waves": [
    { "t": 3, "enemy": "enemy.frontier.drone", "count": 6, "x": -25, "dx": 10, "dt": 0.2 },
    { "t": 9, "enemy": "enemy.frontier.dart", "count": 4, "x": 20, "dt": 0.4, "movement": "move.sine.wide" } ] }
```

Add the file name to `levels` in the set's `set.json`. For a new set, make a folder under
`data/levels/` with its own `set.json` (`id`, `name`, `order`, `levels`); it is picked up
automatically and ordered by `order`. The stage ends when every wave has been destroyed or has
left. `"loop": true` with `loop_length` makes an endless level like the test range.
Start any level directly with `tools\run.ps1 --level=frontier/1`, or step through all of them with
PgUp and PgDn.

### Add a weapon, shield, reactor or armor

Copy an entry in the matching `data/tech/` file and give it a new `id`. For weapons,
`power_scaling` lists `[value at 0% weapon power, value at 100%]` for damage and fire rate.
`requires` (list of ids) and `excludes` describe the tree; the validator rejects cycles and items
that could never be bought. The shop that uses them arrives in Milestone 4; until then the starting
loadout in `data/economy.json` decides what the ship carries.

### Replace a model

1. Export the model as glTF binary (`.glb`) and put it in `assets/models/` (or `mods/assets/models/`).
2. Point the asset id at it in `data/assets.json` (or `mods/assets.json`):
   `"enemy.frontier.drone": { "file": "assets/models/drone.glb", "scale": 1.0 }`

Model conventions: Y up; player ships face **-Z** (up the screen), enemies face **+Z** (down the
screen); the pivot is the centre of the ship at deck height; size the model in metres (the player
ship is about 7 wide) or use `scale`. Emissive materials glow. Named empty nodes for engines
(`engine_*`), muzzles (`muzzle_*`) and weak points (`weak_*`) are reserved for later milestones.
Textures: PNG or KTX2 embedded in the `.glb`, 1024 or 2048 square is plenty. If the file is
missing or broken the game logs a warning and shows a magenta box instead of crashing.

### Change how bullets and effects look

Sprites in the manifest are drawn procedurally: `color` (RGB 0 to 1), `intensity` (above 1 glows),
`width`, `length` and `core` (size of the white centre, 0 to 1). Enemy bullets always get a dark
rim so they stay readable.

### Replace a sound

`"sfx.weapon.laser": { "file": "assets/audio/laser.ogg", "volume": 0.5 }`. OGG Vorbis or WAV.
Entries with `"synth"` use the built-in placeholder sounds.

## Licensing

List every third-party file in `assets/CREDITS.md` with its source and license before committing it.
