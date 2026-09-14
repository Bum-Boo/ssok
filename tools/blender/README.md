# Blender part mesh generator
Run: `blender -b -P tools/blender/make_parts.py -- --out assets/parts`
Requires Blender 4.5 and its bundled Python; output is deterministic OBJ+MTL.
The script models Godot `(x, y, z)` as Blender `(x, -z, y)`.
OBJ export uses `forward_axis='NEGATIVE_Z', up_axis='Y'`, restoring Godot X-right, Y-up, Z-toward-camera coordinates.

After generating:
1. `python3 tools/blender/check_obj.py assets/parts` — body bounds, polygon budget, every port touches a surface.
2. `godot --headless --path . --import` — imports the new OBJs.
3. `godot --headless --path . -s tools/godot/make_part_defs.gd` — rewrites `assets/parts/*.tres` from the port spec and binds the meshes.

Real-module dimensions (Uno, TT motor, 65 mm wheel, HC-SR04) and their sources are listed in `docs/ARCHITECTURE.md`.
