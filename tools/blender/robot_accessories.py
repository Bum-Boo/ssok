"""Original ssok structural accessories, sized for the existing simulator parts.

Dimensions are design choices in metres, not vendor specifications. Builders use
the shared Godot-axis helpers and return one object for texture-free OBJ export.
"""

from __future__ import annotations

from types import ModuleType

import bpy


CHASSIS_SIZE = (0.120, 0.004, 0.080)
CHASSIS_MOUNTS = ((0.0, 0.0), (-0.040, 0.0), (0.040, 0.0), (0.0, -0.025), (0.0, 0.025))
BRACKET_BASE_SIZE = (0.036, 0.004, 0.030)
BRACKET_WALL_SIZE = (0.036, 0.028, 0.003)


def _mount_ring(
	name: str,
	position: tuple[float, float, float],
	axis: str,
	materials: dict[str, bpy.types.Material],
	helpers: ModuleType,
) -> bpy.types.Object:
	ring = helpers.add_cylinder(name, position, 0.005, 0.0006, axis, materials["ServoBlue"], 24)
	helpers.subtract_cylinder(ring, position, 0.0033, 0.002, axis)
	return ring


def build_chassis_plate(materials: dict[str, bpy.types.Material], helpers: ModuleType) -> bpy.types.Object:
	metal = helpers.make_material("ChassisMetal", (0.24, 0.29, 0.34))
	body = helpers.add_box("Perforated chassis", (0.0, 0.0, 0.0), CHASSIS_SIZE, metal, 0.001)
	for x in (-0.048, -0.024, 0.024, 0.048):
		for z in (-0.025, 0.025):
			helpers.subtract_cylinder(body, (x, 0.0, z), 0.0045, 0.008, "Y")
	for x in (-0.024, 0.024):
		helpers.subtract_cylinder(body, (x, 0.0, 0.0), 0.006, 0.008, "Y")
	for x in (-0.054, 0.054):
		for z in (-0.034, 0.034):
			helpers.subtract_cylinder(body, (x, 0.0, z), 0.0018, 0.008, "Y")
	# The colored rings leave solid plate at each snap point instead of a hole.
	rings = [
		_mount_ring("Chassis mount ring", (x, 0.002, z), "Y", materials, helpers)
		for x, z in CHASSIS_MOUNTS
	]
	return helpers.join_parts("chassis_plate", [body, *rings])


def _gusset(x: float, metal: bpy.types.Material, helpers: ModuleType) -> bpy.types.Object:
	outline = ((0.002, -0.012), (0.002, 0.003), (0.024, -0.012))
	vertices = [helpers.godot_to_blender((side_x, y, z)) for side_x in (x - 0.0015, x + 0.0015) for y, z in outline]
	faces = ((0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0))
	mesh = bpy.data.meshes.new("Bracket gusset mesh")
	mesh.from_pydata(vertices, [], faces)
	mesh.update()
	obj = bpy.data.objects.new("Bracket gusset", mesh)
	bpy.context.collection.objects.link(obj)
	helpers.assign_material(obj, metal)
	helpers.apply_bevel(obj, 0.0005, 2)
	return obj


def build_servo_bracket(materials: dict[str, bpy.types.Material], helpers: ModuleType) -> bpy.types.Object:
	metal = helpers.make_material("BracketMetal", (0.30, 0.35, 0.42))
	base = helpers.add_box("Bracket shelf", (0.0, 0.0, 0.0), BRACKET_BASE_SIZE, metal, 0.0006)
	wall = helpers.add_box("Bracket back", (0.0, 0.016, -0.0135), BRACKET_WALL_SIZE, metal, 0.0006)
	for x in (-0.011, 0.011):
		for z in (-0.009, 0.009):
			helpers.subtract_cylinder(base, (x, 0.0, z), 0.0016, 0.008, "Y")
		helpers.subtract_cylinder(wall, (x, 0.020, -0.0135), 0.0035, 0.007, "Z")
		helpers.subtract_cylinder(wall, (x, 0.007, -0.0135), 0.0016, 0.007, "Z")
	gussets = [_gusset(x, metal, helpers) for x in (-0.0165, 0.0165)]
	rings = [
		_mount_ring("Shelf mount ring", (0.0, 0.002, 0.0), "Y", materials, helpers),
		_mount_ring("Rear mount ring", (0.0, 0.016, -0.015), "Z", materials, helpers),
	]
	return helpers.join_parts("servo_bracket", [base, wall, *gussets, *rings])


BUILDERS = {
	"chassis_plate": build_chassis_plate,
	"servo_bracket": build_servo_bracket,
}
