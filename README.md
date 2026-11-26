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

In game: mouse to fly, LMB and RMB fire, wheel shifts power, Esc pauses (sensitivity, mouse mode
and shield choice are in the pause menu), F3 shows performance, F4 stress test, F5 invincible,
F6 reloads data files, PgUp and PgDn change level. `--level=sandbox/1` starts the endless test range.

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
