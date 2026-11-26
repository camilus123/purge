# purge

An original top-down vertical scrolling shooter. Fly with the mouse, fire two weapons
with the mouse buttons, shift reactor power between shields and weapons with the wheel,
and spend credits on a branching tech tree between stages.

Built with **Godot 4.7.2** (standard build, GDScript). Windows x64.

## Run from source

```powershell
& "H:\temp\godot\Godot_v4.7.2-stable_win64.exe" --path game
```

Open the editor with `--path game -e`. Extra switches go after `--`, for example
`--path game -- --windowed`.

## Layout

| Folder | Contents |
|---|---|
| `game/` | Godot project (scenes, scripts, shaders) |
| `data/` | All gameplay data as JSON (tech, enemies, levels, economy) |
| `assets/` | Models, textures, audio (Git LFS) and `CREDITS.md` |
| `mods/` | Local overrides for data and assets |
| `tools/` | Data validator and balance helpers |
| `tests/` | Automated tests |
| `docs/` | `DESIGN.md`, `DECISIONS.md`, `MODDING.md` |

## Documents

- [Design](docs/DESIGN.md)
- [Decisions](docs/DECISIONS.md)
- [Modding](docs/MODDING.md)
- [Changelog](CHANGELOG.md)
- [Original build brief](GAME_BUILD_INSTRUCTIONS.md)

## License

GPL-3.0, see `LICENSE`.
