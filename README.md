# purge

An original top-down vertical scrolling shooter. Fly with the mouse, fire two weapons
with the mouse buttons, shift reactor power between shields and weapons with the wheel,
and spend credits on a branching tech tree between stages.

Built with **Godot 4.7.2** (standard build, GDScript). Windows x64.

## Run, build, test

```powershell
.	ools
un.ps1              # play from source (borderless fullscreen)
.	ools
un.ps1 --windowed   # play in a window
.	oolsuild.ps1            # export build\purge.exe with the data folder beside it
.	ools	est.ps1             # headless rule tests
.	ools
un.ps1 --bench      # stress benchmark, prints a BENCH line
```

The scripts expect Godot at `H:	emp\godot\Godot_v4.7.2-stable_win64_console.exe`; pass `-Godot <path>`
to use another copy. `--set=key=value` overrides one setting for a single run (for example
`--set=fps_cap=240`); `-Driver vulkan` on `run.ps1` switches the renderer.

The game opens on the main menu: start a campaign or a single set, buy and fit tech in the shop,
then launch the stage. In a stage: mouse to fly, LMB and RMB fire, wheel shifts power, middle
button fires the special, Esc pauses, F3 shows performance. Debug builds (`tools\run.ps1`) also
have F4 stress test, F5 invincible, F6 reload data, PgUp/PgDn change level, and F7 in the shop for
credits. Saves are in `%APPDATA%\Godot\app_userdata\purge\saves`.

Useful switches: `--level=frontier/1` (straight into a level), `--loadout=weapon.laser.t4,special.seeker.t1`
(with --level, fit any items), `--flow-test` (plays the campaign by itself and prints each step).

## Layout

| Folder | Contents |
|---|---|
| `game/` | Godot project (scenes, scripts, shaders) |
| `data/` | All gameplay data as JSON (tech, enemies, levels, economy) |
| `assets/` | Models, textures, audio (Git LFS) and `CREDITS.md` |
| `mods/` | Local overrides for data and assets |
| `tools/` | Run, build, test and validate scripts (later: balance helpers) |
| `game/tests/` | Automated tests |
| `docs/` | `DESIGN.md`, `DECISIONS.md`, `MODDING.md` |

## Documents

- [Design](docs/DESIGN.md)
- [Decisions](docs/DECISIONS.md)
- [Modding](docs/MODDING.md)
- [Changelog](CHANGELOG.md)
- [Original build brief](GAME_BUILD_INSTRUCTIONS.md)

## License

GPL-3.0, see `LICENSE`.
