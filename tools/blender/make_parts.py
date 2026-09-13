#!/usr/bin/env python3
"""Generate the four ssok part meshes with Blender 4.5."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy


# Blender's OBJ export with -Z forward and Y up maps Blender (x, y, z) to
# Godot/OBJ (x, z, -y), so model Godot (x, y, z) at Blender (x, -z, y).
def godot_to_blender(value: tuple[float, float, float]) -> tuple[float, float, float]:
	return (value[0], -value[2], value[1])


def godot_dimensions(value: tuple[float, float, float]) -> tuple[float, float, float]:
	return (value[0], value[2], value[1])


def reset_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete(use_global=False, confirm=False)
	for datablock in bpy.data.meshes:
		if datablock.users == 0:
			bpy.data.meshes.remove(datablock)


def make_material(name: str, color: tuple[float, float, float]) -> bpy.types.Material:
	material = bpy.data.materials.get(name)
	if material is None:
		material = bpy.data.materials.new(name=name)
	material.diffuse_color = (*color, 1.0)
	material.use_nodes = True
	principled = material.node_tree.nodes.get("Principled BSDF")
	if principled is not None:
		principled.inputs["Base Color"].default_value = (*color, 1.0)
		principled.inputs["Roughness"].default_value = 0.48
	return material


def assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
	obj.data.materials.append(material)


def apply_bevel(obj: bpy.types.Object, width: float, segments: int = 3) -> None:
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	modifier = obj.modifiers.new(name="Edge bevel", type="BEVEL")
	modifier.width = width
	modifier.segments = segments
	modifier.limit_method = "ANGLE"
	bpy.ops.object.modifier_apply(modifier=modifier.name)


def add_box(
	name: str,
	location: tuple[float, float, float],
	dimensions: tuple[float, float, float],
	material: bpy.types.Material,
	bevel: float = 0.0,
) -> bpy.types.Object:
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=godot_to_blender(location))
	obj = bpy.context.object
	obj.name = name
	obj.dimensions = godot_dimensions(dimensions)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	if bevel > 0.0:
		apply_bevel(obj, bevel)
	assign_material(obj, material)
	return obj


def add_cylinder(
	name: str,
	location: tuple[float, float, float],
	radius: float,
	depth: float,
	axis: str,
	material: bpy.types.Material,
	vertices: int = 24,
	bevel: float = 0.0,
) -> bpy.types.Object:
	rotations = {
		"X": (0.0, math.pi / 2.0, 0.0),
		"Y": (0.0, 0.0, 0.0),
		"Z": (math.pi / 2.0, 0.0, 0.0),
	}
	bpy.ops.mesh.primitive_cylinder_add(
		vertices=vertices,
		radius=radius,
		depth=depth,
		end_fill_type="NGON",
		location=godot_to_blender(location),
		rotation=rotations[axis],
	)
	obj = bpy.context.object
	obj.name = name
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	if bevel > 0.0:
		apply_bevel(obj, bevel, 2)
	assign_material(obj, material)
	return obj


def subtract_cylinder(
	target: bpy.types.Object,
	location: tuple[float, float, float],
	radius: float,
	depth: float,
	axis: str,
) -> None:
	dummy = make_material("Temporary cutter", (0.0, 0.0, 0.0))
	cutter = add_cylinder("Hole cutter", location, radius, depth, axis, dummy, vertices=20)
	bpy.context.view_layer.objects.active = target
	modifier = target.modifiers.new(name="Drilled hole", type="BOOLEAN")
	modifier.operation = "DIFFERENCE"
	modifier.solver = "EXACT"
	modifier.object = cutter
	bpy.ops.object.modifier_apply(modifier=modifier.name)
	bpy.data.objects.remove(cutter, do_unlink=True)


def add_tapered_arm(material: bpy.types.Material) -> bpy.types.Object:
	outline = [(-0.005, -0.04), (0.005, -0.04), (0.0032, 0.04), (-0.0032, 0.04)]
	vertices_godot = [(x, y, z) for z in (-0.005, 0.005) for x, y in outline]
	vertices = [godot_to_blender(vertex) for vertex in vertices_godot]
	faces = [
		(0, 1, 2, 3),
		(7, 6, 5, 4),
		(0, 4, 5, 1),
		(1, 5, 6, 2),
		(2, 6, 7, 3),
		(3, 7, 4, 0),
	]
	mesh = bpy.data.meshes.new("Arm tapered mesh")
	mesh.from_pydata(vertices, [], faces)
	mesh.update()
	obj = bpy.data.objects.new("Arm body", mesh)
	bpy.context.collection.objects.link(obj)
	assign_material(obj, material)
	apply_bevel(obj, 0.0007, 3)
	return obj


def join_parts(name: str, objects: list[bpy.types.Object]) -> bpy.types.Object:
	bpy.ops.object.select_all(action="DESELECT")
	for obj in objects:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = objects[0]
	bpy.ops.object.join()
	joined = bpy.context.object
	joined.name = name
	return joined


def build_base(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	body = add_box("Base body", (0.0, 0.0, 0.0), (0.08, 0.02, 0.08), materials["BaseBody"], 0.004)
	for x in (-0.032, 0.032):
		for z in (-0.032, 0.032):
			subtract_cylinder(body, (x, 0.0, z), 0.0025, 0.024, "Y")
	feet = [
		add_cylinder("Rubber foot", (x, -0.0108, z), 0.004, 0.0016, "Y", materials["Rubber"], 20, 0.0004)
		for x in (-0.030, 0.030)
		for z in (-0.030, 0.030)
	]
	return join_parts("base", [body, *feet])


def build_servo(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	body = add_box("Servo body", (0.0, 0.0, 0.0), (0.023, 0.03, 0.012), materials["ServoBody"], 0.0015)
	flange = add_box("Servo mounting flange", (0.0, -0.009, 0.0), (0.027, 0.005, 0.016), materials["ServoBlue"], 0.001)
	hub = add_cylinder("Shaft hub", (0.0130, 0.005, 0.0), 0.0044, 0.003, "X", materials["Cream"], 32, 0.0004)
	gear = add_cylinder("Spline gear", (0.01575, 0.005, 0.0), 0.0027, 0.0025, "X", materials["Cream"], 16, 0.0002)
	connector = add_box("Signal connector", (-0.01375, 0.0, 0.0), (0.0045, 0.0065, 0.008), materials["Black"], 0.0005)
	wires = []
	for z, color in zip((-0.0024, 0.0, 0.0024), ("Brown", "Red", "Orange"), strict=True):
		wires.append(add_cylinder("Signal wire", (-0.01625, 0.0, z), 0.00065, 0.001, "X", materials[color], 12))
	return join_parts("servo", [body, flange, hub, gear, connector, *wires])


def build_arm(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	body = add_tapered_arm(materials["ArmBody"])
	for y in (-0.012, 0.008, 0.026):
		subtract_cylinder(body, (0.0, y, 0.0), 0.00125, 0.014, "Z")
	hub = add_cylinder("Horn hub", (0.0, -0.035, 0.0), 0.005, 0.01, "Z", materials["Cream"], 32, 0.0005)
	subtract_cylinder(hub, (0.0, -0.035, 0.0), 0.0014, 0.014, "Z")
	return join_parts("arm_link", [body, hub])


def build_board(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	body = add_box("Board body", (0.0, 0.0, 0.0), (0.07, 0.005, 0.05), materials["BoardBody"], 0.0015)
	chip = add_box("Controller chip", (0.008, 0.004, 0.0), (0.014, 0.003, 0.012), materials["Black"], 0.0005)
	usb = add_box("USB socket", (0.0365, 0.0035, 0.0), (0.007, 0.006, 0.014), materials["Silver"], 0.0007)
	pins = []
	for z in (-0.02, -0.01, 0.0, 0.01, 0.02):
		pins.append(add_box("Header housing", (-0.03, 0.004, z), (0.003, 0.003, 0.004), materials["Black"], 0.0003))
		pins.append(add_box("Header pin", (-0.03, 0.006, z), (0.0012, 0.004, 0.0012), materials["Gold"], 0.00015))
	return join_parts("board", [body, chip, usb, *pins])


def export_part(obj: bpy.types.Object, filepath: Path) -> None:
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.wm.obj_export(
		filepath=str(filepath),
		check_existing=False,
		export_selected_objects=True,
		forward_axis="NEGATIVE_Z",
		up_axis="Y",
		apply_modifiers=True,
		export_triangulated_mesh=True,
		export_materials=True,
		path_mode="AUTO",
	)


def parse_args() -> argparse.Namespace:
	arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--out", type=Path, required=True, help="OBJ/MTL output directory")
	return parser.parse_args(arguments)


def main() -> None:
	args = parse_args()
	output_dir = args.out.expanduser().resolve()
	output_dir.mkdir(parents=True, exist_ok=True)
	materials = {
		"BaseBody": make_material("BaseBody", (0.075, 0.085, 0.095)),
		"Rubber": make_material("Rubber", (0.018, 0.020, 0.022)),
		"ServoBody": make_material("ServoBody", (0.025, 0.18, 0.62)),
		"ServoBlue": make_material("ServoBlue", (0.035, 0.22, 0.72)),
		"Cream": make_material("Cream", (0.88, 0.84, 0.69)),
		"ArmBody": make_material("ArmBody", (0.93, 0.90, 0.78)),
		"BoardBody": make_material("BoardBody", (0.025, 0.34, 0.12)),
		"Black": make_material("Black", (0.015, 0.018, 0.020)),
		"Brown": make_material("Brown", (0.22, 0.055, 0.018)),
		"Red": make_material("Red", (0.72, 0.025, 0.018)),
		"Orange": make_material("Orange", (0.95, 0.22, 0.015)),
		"Silver": make_material("Silver", (0.58, 0.62, 0.65)),
		"Gold": make_material("Gold", (0.92, 0.57, 0.08)),
	}
	builders = {
		"base": build_base,
		"servo": build_servo,
		"arm_link": build_arm,
		"board": build_board,
	}
	for part_name, builder in builders.items():
		reset_scene()
		part = builder(materials)
		export_part(part, output_dir / f"{part_name}.obj")


if __name__ == "__main__":
	main()
