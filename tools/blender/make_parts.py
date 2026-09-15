#!/usr/bin/env python3
"""Generate detailed ssok robot meshes and an optional Blender asset library with Blender 5.2.1."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path
from types import SimpleNamespace

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from part_details import cleanup_export_mesh, decorate
from part_materials import configure_material
from robot_accessories import BUILDERS as ACCESSORY_BUILDERS


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
	return configure_material(name, color)


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
	# Outward winding keeps drilled holes and shallow surface recesses inside the arm.
	mesh.from_pydata(vertices, [], [tuple(reversed(face)) for face in faces])
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
	if len(objects) > 1:
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


# Real-module dimensions (metres). Sources: Arduino A000066 datasheet §5 (PCB 66.04 x 50.80,
# 0.16" D7/D8 gap, PWM 3/5/6/9/10/11), Adafruit/DFRobot TT motor (70 x 22 x 18, dual 5.4 mm
# D-shaft), DigiKey 65 mm wheel (OD 65, 26 mm wide), HC-SR04 datasheet (45 x 20 PCB, 2.54 mm
# header); HC-SR04 transducer size/spacing is estimated from photos.
UNO_PCB = (0.06604, 0.0016, 0.0508)
UNO_TOP = UNO_PCB[1] / 2.0
UNO_PITCH = 0.00254
UNO_HEADER_HEIGHT = 0.0085
UNO_DIGITAL_Z = 0.0229
UNO_D0_X = 0.0292
UNO_D8_X = UNO_D0_X - 7 * UNO_PITCH - 0.00406


def uno_digital_pin_x(pin: int) -> float:
	if pin <= 7:
		return UNO_D0_X - pin * UNO_PITCH
	return UNO_D8_X - (pin - 8) * UNO_PITCH


def build_arduino_uno(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	body = add_box("Uno PCB", (0.0, 0.0, 0.0), UNO_PCB, materials["UnoBlue"], 0.0004)
	for x, z in ((-0.01778, 0.02286), (-0.01905, -0.02286), (0.03048, -0.01778), (0.03048, 0.01016)):
		subtract_cylinder(body, (x, 0.0, z), 0.0016, 0.004, "Y")
	header_y = UNO_TOP + UNO_HEADER_HEIGHT / 2.0
	# Digital headers: SCL..D8 (10 pins) and D7..D0 (8 pins) with the 0.16" gap between them.
	upper_x0 = uno_digital_pin_x(13) - 4 * UNO_PITCH - UNO_PITCH / 2.0
	upper_x1 = uno_digital_pin_x(8) + UNO_PITCH / 2.0
	lower_x0 = uno_digital_pin_x(7) - UNO_PITCH / 2.0
	lower_x1 = uno_digital_pin_x(0) + UNO_PITCH / 2.0
	headers = [
		add_box("Digital header 8-13", ((upper_x0 + upper_x1) / 2.0, header_y, UNO_DIGITAL_Z),
			(upper_x1 - upper_x0, UNO_HEADER_HEIGHT, UNO_PITCH), materials["Black"], 0.0003),
		add_box("Digital header 0-7", ((lower_x0 + lower_x1) / 2.0, header_y, UNO_DIGITAL_Z),
			(lower_x1 - lower_x0, UNO_HEADER_HEIGHT, UNO_PITCH), materials["Black"], 0.0003),
		add_box("Power header", (-0.00535, header_y, -UNO_DIGITAL_Z), (0.0203, UNO_HEADER_HEIGHT, UNO_PITCH), materials["Black"], 0.0003),
		add_box("Analog header", (0.0153, header_y, -UNO_DIGITAL_Z), (0.0152, UNO_HEADER_HEIGHT, UNO_PITCH), materials["Black"], 0.0003),
	]
	sockets = []
	for pin in range(14):
		sockets.append(add_box("Pin socket", (uno_digital_pin_x(pin), UNO_TOP + UNO_HEADER_HEIGHT, UNO_DIGITAL_Z),
			(0.0009, 0.0002, 0.0009), materials["Gold"]))
	usb = add_box("USB-B jack", (-0.0276, UNO_TOP + 0.0055, 0.0165), (0.016, 0.011, 0.012), materials["Silver"], 0.0008)
	barrel = add_box("DC barrel jack", (-0.0276, UNO_TOP + 0.0045, -0.0175), (0.014, 0.009, 0.009), materials["Black"], 0.0008)
	chip = add_box("ATmega328P", (0.011, UNO_TOP + 0.002, -0.0095), (0.035, 0.004, 0.0075), materials["Black"], 0.0004)
	crystal = add_cylinder("Crystal", (-0.006, UNO_TOP + 0.0018, -0.004), 0.0018, 0.010, "X", materials["Silver"], 16)
	return join_parts("arduino_uno", [body, *headers, *sockets, usb, barrel, chip, crystal])


TT_GEARBOX = (0.037, 0.022, 0.018)
TT_GEARBOX_X = -0.0165
TT_SHAFT_X = -0.024
TT_SHAFT_LENGTH = 0.009


def build_tt_motor(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	gearbox = add_box("Gearbox", (TT_GEARBOX_X, 0.0, 0.0), TT_GEARBOX, materials["TtYellow"], 0.0012)
	for z in (-0.0091, 0.0091):
		subtract_cylinder(gearbox, (-0.031, 0.0, z), 0.0015, 0.004, "Z")
		subtract_cylinder(gearbox, (-0.012, 0.0, z), 0.0015, 0.004, "Z")
	can = add_cylinder("Motor can", (0.0185, 0.0, 0.0), 0.010, 0.033, "X", materials["Silver"], 32, 0.0008)
	cap = add_cylinder("End cap", (0.0355, 0.0, 0.0), 0.006, 0.002, "X", materials["Black"], 24)
	terminals = [
		add_box("Terminal", (0.0355, y, 0.0), (0.002, 0.003, 0.0006), materials["Silver"])
		for y in (-0.0075, 0.0075)
	]
	shafts = []
	for z in (-1.0, 1.0):
		center_z = z * (TT_GEARBOX[2] / 2.0 + TT_SHAFT_LENGTH / 2.0)
		shaft = add_cylinder("Shaft", (TT_SHAFT_X, 0.0, center_z), 0.0027, TT_SHAFT_LENGTH, "Z", materials["Silver"], 24)
		# D-flat on the outer half of each shaft.
		flat = add_box("Shaft flat", (TT_SHAFT_X, 0.0027 + 0.0005, center_z + z * 0.0012), (0.006, 0.0022, 0.0066), materials["Silver"])
		bpy.context.view_layer.objects.active = shaft
		modifier = shaft.modifiers.new(name="D flat", type="BOOLEAN")
		modifier.operation = "DIFFERENCE"
		modifier.solver = "EXACT"
		modifier.object = flat
		bpy.ops.object.modifier_apply(modifier=modifier.name)
		bpy.data.objects.remove(flat, do_unlink=True)
		shafts.append(shaft)
	return join_parts("tt_motor", [gearbox, can, cap, *terminals, *shafts])


WHEEL_RADIUS = 0.0325
WHEEL_WIDTH = 0.026


def build_wheel_65(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	tire = add_cylinder("Tire", (0.0, 0.0, 0.0), WHEEL_RADIUS, WHEEL_WIDTH, "Z", materials["Rubber"], 48, 0.003)
	rim = add_cylinder("Rim", (0.0, 0.0, 0.0), 0.0265, WHEEL_WIDTH + 0.0004, "Z", materials["RimYellow"], 48, 0.0008)
	for index in range(6):
		angle = index * math.tau / 6.0
		subtract_cylinder(rim, (0.016 * math.cos(angle), 0.016 * math.sin(angle), 0.0), 0.0045, 0.04, "Z")
	hub = add_cylinder("Hub", (0.0, 0.0, 0.0), 0.006, WHEEL_WIDTH + 0.002, "Z", materials["Black"], 24, 0.0006)
	subtract_cylinder(hub, (0.0, 0.0, 0.0), 0.0027, 0.04, "Z")
	return join_parts("wheel_65", [tire, rim, hub])


SENSOR_PCB = (0.045, 0.020, 0.0016)
SENSOR_FRONT = SENSOR_PCB[2] / 2.0


def build_hc_sr04(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	body = add_box("Sensor PCB", (0.0, 0.0, 0.0), SENSOR_PCB, materials["SensorBlue"], 0.0004)
	for x in (-0.0205, 0.0205):
		subtract_cylinder(body, (x, 0.0, 0.0), 0.001, 0.004, "Z")
	transducers = []
	for x in (-0.013, 0.013):
		transducers.append(add_cylinder("Transducer", (x, 0.0, SENSOR_FRONT + 0.006), 0.008, 0.012, "Z", materials["Silver"], 32, 0.0006))
		transducers.append(add_cylinder("Transducer mesh", (x, 0.0, SENSOR_FRONT + 0.0122), 0.0062, 0.0006, "Z", materials["Black"], 32))
	crystal = add_cylinder("Crystal", (0.0, 0.006, -SENSOR_FRONT - 0.0018), 0.0018, 0.009, "X", materials["Silver"], 16)
	driver = add_box("Driver IC", (0.0, -0.004, -SENSOR_FRONT - 0.0008), (0.010, 0.0045, 0.0016), materials["Black"], 0.0002)
	header = add_box("Header housing", (0.0, -SENSOR_PCB[1] / 2.0 - 0.00125, 0.0), (0.0102, 0.0025, 0.0025), materials["Black"], 0.0003)
	pins = [
		add_cylinder("Header pin", (x, -SENSOR_PCB[1] / 2.0 - 0.0025 - 0.003, 0.0), 0.00032, 0.006, "Y", materials["Gold"], 8)
		for x in (-0.00381, -0.00127, 0.00127, 0.00381)
	]
	return join_parts("hc_sr04", [body, *transducers, crystal, driver, header, *pins])


# Otto-DIY-style biped shell parts (github.com/OttoDIY, CC-BY-SA 4.0): a body that hangs two
# SG90 hips, a leg that carries an ankle servo, a foot with a horn tab. Sized to our 23 x 30 x 12
# servo placeholder rather than Otto's exact STL envelopes.
BODY = (0.07, 0.06, 0.045)
LEG = (0.012, 0.04, 0.016)
# Otto-style foot: a wide plate whose inner edge reaches the body's centre line, with a horn
# tab at the front and at the back so a left or right ankle servo (shaft along +/-Z) can drive it.
FOOT_PLATE = (0.065, 0.008, 0.045)
FOOT_TAB = (0.02, 0.03, 0.004)
FOOT_TAB_Z = 0.0135
FOOT_ANKLE_Y = 0.024


def build_biped_body(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	body = add_box("Body shell", (0.0, 0.0, 0.0), BODY, materials["Shell"], 0.004)
	for x in (-0.02, 0.02):
		subtract_cylinder(body, (x, -BODY[1] / 2.0, 0.0), 0.0015, 0.002, "Y")
	mouth = add_box("Mouth slot", (0.0, -0.012, BODY[2] / 2.0), (0.028, 0.004, 0.002), materials["Black"], 0.0005)
	buttons = [
		add_cylinder("Back button", (x, 0.012, -BODY[2] / 2.0 - 0.001), 0.004, 0.002, "Z", materials["ServoBlue"], 20, 0.0004)
		for x in (-0.012, 0.012)
	]
	return join_parts("biped_body", [body, mouth, *buttons])


def build_leg_link(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	leg = add_box("Leg", (0.0, 0.0, 0.0), LEG, materials["Shell"], 0.002)
	subtract_cylinder(leg, (LEG[0] / 2.0, 0.014, 0.0), 0.0014, 0.006, "X")
	subtract_cylinder(leg, (0.0, -LEG[1] / 2.0, 0.0), 0.0015, 0.002, "Y")
	return join_parts("leg_link", [leg])


def build_foot(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
	plate = add_box("Foot plate", (0.0, 0.0, 0.0), FOOT_PLATE, materials["Shell"], 0.002)
	tab_y = FOOT_PLATE[1] / 2.0 + FOOT_TAB[1] / 2.0 - 0.001
	tabs = []
	for z in (-FOOT_TAB_Z, FOOT_TAB_Z):
		tab = add_box("Ankle tab", (0.0, tab_y, z), FOOT_TAB, materials["Shell"], 0.001)
		subtract_cylinder(tab, (0.0, FOOT_ANKLE_Y, z), 0.0014, 0.006, "Z")
		tabs.append(tab)
	sole = add_box("Sole", (0.0, -FOOT_PLATE[1] / 2.0 - 0.0005, 0.0), (FOOT_PLATE[0] - 0.002, 0.001, FOOT_PLATE[2] - 0.002), materials["Rubber"])
	return join_parts("foot", [plate, *tabs, sole])


def export_part(obj: bpy.types.Object, filepath: Path) -> None:
	cleanup_export_mesh(obj)
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
		# Boolean-generated UVs vary between runs; these assets use only solid colors.
		export_uv=False,
		export_pbr_extensions=True,
		export_materials=True,
		path_mode="AUTO",
	)


def save_library(parts: list[bpy.types.Object], filepath: Path) -> None:
	"""Keep the source meshes editable and discoverable in Blender's Asset Browser."""
	filepath = filepath.expanduser().resolve()
	filepath.parent.mkdir(parents=True, exist_ok=True)
	scene = bpy.context.scene
	scene.unit_settings.system = "METRIC"
	scene.unit_settings.length_unit = "MILLIMETERS"
	for index, part in enumerate(parts):
		part.asset_mark()
		part.asset_data.description = "ssok robot part; dimensions in metres; ports in make_part_defs.gd"
		part["ssok_part_id"] = part.name
		part["assembly_origin"] = list(part.location)
		part.location += Vector(((index % 4) * 0.16, -(index // 4) * 0.13, 0.0))
	for screen in bpy.data.screens:
		for area in screen.areas:
			if area.type == "VIEW_3D":
				area.spaces.active.shading.type = "MATERIAL"
				area.spaces.active.region_3d.view_location = Vector((0.24, -0.18, 0.0))
				area.spaces.active.region_3d.view_distance = 0.85
	bpy.ops.object.select_all(action="DESELECT")
	bpy.context.view_layer.objects.active = None
	scene.render.engine = "CYCLES"
	bpy.ops.wm.save_as_mainfile(filepath=str(filepath), check_existing=False, compress=True)
	print(f"Saved editable library: {filepath}")


def parse_args() -> argparse.Namespace:
	arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--out", type=Path, required=True, help="OBJ/MTL output directory")
	parser.add_argument("--blend", type=Path, help="Optional editable .blend asset library (keep outside Godot import)")
	return parser.parse_args(arguments)


def main() -> None:
	args = parse_args()
	output_dir = args.out.expanduser().resolve()
	output_dir.mkdir(parents=True, exist_ok=True)
	reset_scene()
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
		"UnoBlue": make_material("UnoBlue", (0.0, 0.30, 0.42)),
		"SensorBlue": make_material("SensorBlue", (0.02, 0.16, 0.45)),
		"TtYellow": make_material("TtYellow", (0.95, 0.72, 0.08)),
		"RimYellow": make_material("RimYellow", (0.93, 0.78, 0.18)),
		"Shell": make_material("Shell", (0.90, 0.91, 0.93)),
	}
	builders = {
		"base": build_base,
		"servo": build_servo,
		"arm_link": build_arm,
		"board": build_board,
		"arduino_uno": build_arduino_uno,
		"tt_motor": build_tt_motor,
		"wheel_65": build_wheel_65,
		"hc_sr04": build_hc_sr04,
		"biped_body": build_biped_body,
		"leg_link": build_leg_link,
		"foot": build_foot,
	}
	helpers = SimpleNamespace(**globals())
	parts: list[bpy.types.Object] = []
	for part_name, builder in builders.items():
		print(f"Building {part_name}", flush=True)
		part = builder(materials)
		part = decorate(part_name, part, materials, helpers)
		export_part(part, output_dir / f"{part_name}.obj")
		parts.append(part)
	for part_name, builder in ACCESSORY_BUILDERS.items():
		print(f"Building {part_name}", flush=True)
		part = builder(materials, helpers)
		export_part(part, output_dir / f"{part_name}.obj")
		parts.append(part)
	if args.blend:
		save_library(parts, args.blend)


if __name__ == "__main__":
	main()
