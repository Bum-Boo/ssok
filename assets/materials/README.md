# ssok material library

`catalog.json` is the shared source for Blender and Godot finishes. There are 26 visible
materials plus one internal Boolean-cutter fallback. Keep material identifiers aligned with
the OBJ `usemtl` names; the cutter's Blender name contains a space, exported as an underscore.

| Finish | Use | Response |
|---|---|---|
| Satin plastic | White shell, teal trim, blue servo, yellow gearbox | Nonmetallic, fine molded grain |
| Rubber | Tires, foot grips, cable insulation | Nonmetallic, higher roughness |
| Brushed metal | Sensor cans, screws, chassis, bracket | Metallic, fine directional grain |
| PCB coating | Green/blue boards and coated traces | Nonmetallic solder mask, subtle grain |
| Smooth | Contacts, markings, indicator lens | Gold contacts are metallic; amber LED emits weakly |

Colors in the catalog are **linear RGB**, matching the existing Blender node values.
The Godot generator converts these to sRGB for `StandardMaterial3D` color properties.
This also corrects the old OBJ import's ambiguous color-space appearance. Lighting and
microtexture implementation differ between renderers; the materials are not pixel-identical.
`DetailCopper` names traces seen through solder mask, not exposed copper, so it is nonmetallic.

## Generated resources

- `*.tres`: editable `StandardMaterial3D` resources, shared across all parts.
- `textures/*_normal.res`: three deterministic, seamless 128×128 normal maps with normalized
  mipmaps; PCB coating reuses the plastic map with weaker strength.
- `../meshes/*.res`: compressed `ArrayMesh` copies with the same vertex/index buffers, surface
  order and bounds as the imported OBJs, but references to the external materials.
- `../parts/*.tres`: `PartDef` references these materialized meshes in both assembly and run mode.

Godot uses local triplanar mapping because source OBJs intentionally omit UVs. Grain follows
the moving part instead of sliding through world coordinates. Textures are baked at authoring
time, with no runtime generation, threads, custom shader or Forward+-only feature. Blender
uses editable Object-coordinate Noise/Bump nodes at metre scale, including slight roughness
variation; Godot keeps scalar roughness and uses the lightweight shared normal maps.

## Refresh after editing the catalog

Run from the repository root. These commands overwrite generated materials and meshes;
keep manual edits in separately named files or move their values into the catalog first.

```sh
blender --background assets/blender/ssok_parts.blend --threads 2 --python-exit-code 1 \
  --python tools/blender/update_materials.py
godot --headless --path . --import
godot --headless --path . -s tools/godot/make_materials.gd
godot --headless --path . -s tools/godot/make_part_defs.gd
godot --headless --path . --import
godot --headless --path . -s tests/material_assets_check.gd
godot --headless --path . -s tests/mesh_assets_check.gd
```

The Blender updater preserves mesh data, part placement and custom properties, and retains a
`.blend1` backup. OBJ files are not rewritten; MTL sidecars receive basic PBR fallback values
but cannot represent procedural nodes. For full geometry regeneration see `tools/blender/README.md`.

Render checks require a graphical display:

```sh
godot --path . -s tools/godot/material_preview.gd
godot --path . -s tools/godot/mesh_preview.gd
```

Images are saved to `user://mesh_previews/`. The studio previews include a reflection sky so
the metal response can be inspected; the application's existing sky lighting remains unchanged.
