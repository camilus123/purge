# Modding purge

*(Stub. Filled in as the data systems land in Milestone 3.)*

- All gameplay numbers live in JSON under `data/`. Edit them with any text editor.
- Files are loaded loose from disk at startup (next to the executable in a release build),
  so no rebuild is needed after a change.
- Assets are referred to by **asset id**; `data/assets.json` maps ids to files (Milestone 3).
- Files placed in `mods/` override built-in files with the same relative path or asset id (Milestone 3).

## Coordinate conventions (already in force)

- Playfield: 90 units wide, 120 units tall. `x` grows to the right, `y` grows down the screen.
- In 3D: gameplay `x` is world `X`, gameplay `y` is world `Z`, world `Y` is up toward the camera.
- Player models face **-Z** (up the screen); enemy models face **+Z** (down the screen).
- 1 unit is about 1 metre; the player ship is about 7 units wide.
- Hitboxes are circles defined in data (`radius`), never taken from the mesh.
