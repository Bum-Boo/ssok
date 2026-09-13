# Blender part mesh generator
Run: `blender -b -P tools/blender/make_parts.py -- --out assets/parts`
Requires Blender 4.5 and its bundled Python; output is deterministic OBJ+MTL.
The script models Godot `(x, y, z)` as Blender `(x, -z, y)`.
OBJ export uses `forward_axis='NEGATIVE_Z', up_axis='Y'`, restoring Godot X-right, Y-up, Z-toward-camera coordinates.
