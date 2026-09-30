# Blender part mesh generator

Tested with **Blender 5.2.1 LTS** and its bundled Python. The local installation is
`~/.local/opt/blender-5.2.1-linux-x64`, available as `blender` and in the desktop application menu.
This replaces the previous remote Blender 4.5 workflow at the user's request (2026-09-15).
Official release: <https://www.blender.org/download/>.

Run from the repository root:

```sh
blender --background --factory-startup --threads 2 --python-exit-code 1 \
  --python tools/blender/make_parts.py -- \
  --out assets/parts --blend assets/blender/ssok_parts.blend
```

The generator produces deterministic OBJ+MTL assets and an editable `.blend` part library.
The library is regenerated too; keep manual Blender edits in a separately named copy.
Each library object is marked as a Blender asset and arranged on a grid. Its
`assembly_origin` property records its location before this display-only arrangement.
The `.gdignore` in `assets/blender/` keeps native source files out of Godot imports;
the game uses generated Godot meshes/materials and does not need Blender installed.

The script models Godot `(x, y, z)` as Blender `(x, -z, y)`.
OBJ export uses `forward_axis='NEGATIVE_Z', up_axis='Y'`, restoring Godot X-right, Y-up, Z-toward-camera coordinates.

After generating:

1. `python3 tools/blender/check_obj.py assets/parts` — body bounds, polygon budget, every port touches a surface.
2. `godot --headless --path . --import` — imports the new OBJs.
3. `godot --headless --path . -s tools/godot/make_materials.gd` — generates shared PBR materials and binds them to geometry-identical mesh copies.
4. `godot --headless --path . -s tools/godot/make_part_defs.gd` — rewrites `assets/parts/*.tres` from the port spec and binds the materialized meshes.
5. `godot --headless --path . --import` — imports the generated resource metadata.
6. `godot --headless --path . --quit` — loads the main scene.
7. `godot --headless --path . -s tests/assembly_snap_check.gd` and `godot --headless --path . -s tests/run_mode_check.gd` — existing assembly and servo-arm behavior.
8. `godot --headless --path . -s tests/mesh_assets_check.gd` — imported meshes, accessory connections and powered biped regression.
9. `godot --headless --path . -s tests/material_assets_check.gd` — PBR catalog values, shared resources and exact geometry preservation.

For a rendered overview, run `godot --path . -s tools/godot/mesh_preview.gd`.
It saves images under `user://mesh_previews/`. This requires a graphical display.

## Mesh organization

- `make_parts.py`: original part geometry, axis conversion, OBJ export and optional asset library.
- `part_details.py`: casing panels, screws, ventilation, joint trim and electronic-component details.
- `part_materials.py`: shared catalog to editable Principled/Noise/Bump material nodes.
- `update_materials.py`: refreshes native materials and MTL sidecars without rebuilding geometry.
- `robot_accessories.py`: original chassis plate and right-angle servo bracket builders.
- `../godot/make_part_defs.gd`: authoritative masses and connection-port definitions.

Every part stays below 5,000 exported triangles. Existing part envelopes and port positions
are preserved: collision boxes currently come directly from the mesh AABB, so decorative
geometry must not enlarge them. Materials distinguish plastic, rubber, brushed metal, PCB
coating and indicator LEDs. The catalog and material-only workflow are documented in
[`assets/materials/README.md`](../../assets/materials/README.md). Godot uses standard PBR
with three baked micro-normal maps, without custom shaders or runtime texture generation.
Unused UV mappings are omitted so Boolean-generated UV differences do not create asset diffs.
Before export, vertices are rounded to OBJ's micrometre precision and collapsed triangle
fragments are removed. The geometry checker rejects degenerate triangles explicitly.

The chassis and bracket are original generic structural parts, not dimensionally accurate
reproductions of commercial products. Decorative vents, markings and electronic details on
existing parts are visual approximations; they do not add new electrical functionality.

Real-module dimensions (Uno, TT motor, 65 mm wheel, HC-SR04) and their sources are listed in `docs/ARCHITECTURE.md`.
