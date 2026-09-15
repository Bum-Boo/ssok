#!/usr/bin/env python3
"""Refresh the existing Blender library and OBJ material sidecars without rebuilding meshes."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from array import array
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from part_materials import configure_material, load_catalog, material_spec, mtl_block


REPO_ROOT = Path(__file__).resolve().parents[2]


def _property_value(value: object) -> object:
	if hasattr(value, "to_dict"):
		return {key: _property_value(item) for key, item in value.to_dict().items()}
	if hasattr(value, "to_list"):
		return value.to_list()
	if isinstance(value, bpy.types.ID):
		return (value.bl_rna.identifier, value.name_full)
	return value


def geometry_signature() -> str:
	"""Include placement, custom properties, topology, material slots and part asset metadata."""
	digest = hashlib.sha256()
	for obj in sorted(bpy.data.objects, key=lambda item: item.name):
		metadata = {
			"name": obj.name,
			"type": obj.type,
			"matrix": [list(row) for row in obj.matrix_world],
			"properties": {key: _property_value(value) for key, value in obj.items()},
			"materials": [slot.material.name if slot.material else None for slot in obj.material_slots],
			"asset": obj.asset_data.description if obj.asset_data else None,
			"asset_tags": sorted(tag.name for tag in obj.asset_data.tags) if obj.asset_data else [],
		}
		digest.update(json.dumps(metadata, sort_keys=True).encode())
		if obj.type != "MESH":
			continue
		mesh = obj.data
		for collection, field, width, value_type in (
			(mesh.vertices, "co", 3, "f"),
			(mesh.edges, "vertices", 2, "i"),
			(mesh.loops, "vertex_index", 1, "i"),
			(mesh.polygons, "loop_start", 1, "i"),
			(mesh.polygons, "loop_total", 1, "i"),
			(mesh.polygons, "material_index", 1, "i"),
		):
			values = array(value_type, [0]) * (len(collection) * width)
			collection.foreach_get(field, values)
			digest.update(values.tobytes())
	return digest.hexdigest()


def prepare_mtl_updates(directory: Path) -> dict[Path, str]:
	if not directory.is_dir():
		raise ValueError(f"Material sidecar directory does not exist: {directory}")
	updates: dict[Path, str] = {}
	for path in sorted(directory.glob("*.mtl")):
		names = [line.split(maxsplit=1)[1] for line in path.read_text().splitlines() if line.startswith("newmtl ")]
		if not names:
			raise ValueError(f"No materials in {path}")
		blocks = [mtl_block(name) for name in names]
		updates[path] = "# ssok PBR materials; source: assets/materials/catalog.json\n\n" + "\n\n".join(blocks) + "\n"
	if not updates:
		raise ValueError(f"No MTL sidecars found in {directory}")
	return updates


def parse_args() -> argparse.Namespace:
	arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--mtl-dir", type=Path, default=REPO_ROOT / "assets" / "parts")
	parser.add_argument("--skip-mtl", action="store_true", help="Update only the open Blender file")
	return parser.parse_args(arguments)


def main() -> None:
	args = parse_args()
	filepath = Path(bpy.data.filepath)
	if not bpy.data.filepath or filepath.suffix != ".blend" or not filepath.is_file():
		raise ValueError("Open the existing ssok_parts.blend with Blender before running this script")
	if not any(obj.get("ssok_part_id") for obj in bpy.data.objects):
		raise ValueError("The open file has no ssok part assets")
	load_catalog()
	for material in bpy.data.materials:
		material_spec(material.name)
	mtl_updates = {} if args.skip_mtl else prepare_mtl_updates(args.mtl_dir.resolve())
	before = geometry_signature()
	for material in bpy.data.materials:
		configure_material(material.name)
	if geometry_signature() != before:
		raise RuntimeError("Material refresh unexpectedly changed source geometry or placement")
	# Preserve a recoverable .blend1 even when the local Blender preference disables backups.
	bpy.context.preferences.filepaths.save_version = max(1, bpy.context.preferences.filepaths.save_version)
	bpy.ops.wm.save_as_mainfile(filepath=str(filepath), check_existing=False, compress=True)
	for path, content in mtl_updates.items():
		if path.read_text() != content:
			path.write_text(content)
	asset_count = sum(material.asset_data is not None for material in bpy.data.materials)
	print(f"Updated {asset_count} PBR material assets and {len(mtl_updates)} MTL sidecars")
	print(f"Preserved {len(bpy.data.objects)} objects; geometry/placement SHA-256: {before}")
	print(f"Saved {filepath}; previous version retained as {filepath}1")


if __name__ == "__main__":
	main()
