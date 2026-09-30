"""Procedural surface details that preserve the simulator's original part envelopes."""

from __future__ import annotations

import math
from types import ModuleType

import bmesh
import bpy


Vec3 = tuple[float, float, float]
Materials = dict[str, bpy.types.Material]


def _bounds(obj: bpy.types.Object) -> tuple[Vec3, Vec3]:
	vertices = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
	return (
		tuple(min(vertex[axis] for vertex in vertices) for axis in range(3)),
		tuple(max(vertex[axis] for vertex in vertices) for axis in range(3)),
	)


class Details:
	"""Low-segment components; all positions and dimensions use Godot metres."""

	def __init__(self, obj: bpy.types.Object, materials: Materials, helpers: ModuleType) -> None:
		self.base = obj
		self.parts = [obj]
		self.materials = materials
		self.helpers = helpers
		palette = {
			"DetailTeal": (0.015, 0.49, 0.48),
			"DetailGraphite": (0.035, 0.055, 0.065),
			"DetailSteel": (0.29, 0.36, 0.40),
			"DetailWhite": (0.94, 0.96, 0.94),
			"DetailAmber": (1.0, 0.47, 0.035),
			"DetailCopper": (0.29, 0.57, 0.44),
		}
		for name, color in palette.items():
			if name not in materials:
				materials[name] = helpers.make_material(name, color)

	def box(self, name: str, center: Vec3, size: Vec3, color: str, bevel: float = 0.0) -> bpy.types.Object:
		obj = self.helpers.add_box(name, center, size, self.materials[color])
		if bevel:
			# Leave a wall between opposing bevels, including after OBJ's micrometre rounding.
			self.helpers.apply_bevel(obj, min(bevel, min(size) * 0.4), segments=1)
		self.parts.append(obj)
		return obj

	def cylinder(
		self, name: str, center: Vec3, radius: float, depth: float, axis: str, color: str, vertices: int = 16,
	) -> bpy.types.Object:
		obj = self.helpers.add_cylinder(name, center, radius, depth, axis, self.materials[color], vertices)
		self.parts.append(obj)
		return obj

	def ring(
		self, name: str, center: Vec3, inner: float, outer: float, depth: float,
		axis: str, color: str, segments: int = 20,
	) -> bpy.types.Object:
		axial, first, second = {"X": (0, 1, 2), "Y": (1, 2, 0), "Z": (2, 0, 1)}[axis]
		vertices: list[Vec3] = []
		for height in (-depth / 2.0, depth / 2.0):
			for radius in (outer, inner):
				for index in range(segments):
					angle = math.tau * index / segments
					point = list(center)
					point[axial] += height
					point[first] += radius * math.cos(angle)
					point[second] += radius * math.sin(angle)
					vertices.append(self.helpers.godot_to_blender(tuple(point)))
		faces: list[tuple[int, ...]] = []
		for index in range(segments):
			next_index = (index + 1) % segments
			outer_a, outer_b = index, next_index
			inner_a, inner_b = index + segments, next_index + segments
			top = segments * 2
			faces.extend([
				(outer_a, inner_a, inner_b, outer_b),
				(outer_a + top, outer_b + top, inner_b + top, inner_a + top),
				(outer_a, outer_b, outer_b + top, outer_a + top),
				(inner_b, inner_a, inner_a + top, inner_b + top),
			])
		mesh = bpy.data.meshes.new(name)
		mesh.from_pydata(vertices, [], faces)
		mesh.update()
		obj = bpy.data.objects.new(name, mesh)
		bpy.context.collection.objects.link(obj)
		self.helpers.assign_material(obj, self.materials[color])
		self.parts.append(obj)
		return obj

	def screw(self, center: Vec3, axis: str, radius: float = 0.00075, sign: float = 1.0) -> None:
		depth = 0.00024
		self.cylinder("Slotted fastener", center, radius, depth, axis, "Silver", 12)
		axial = "XYZ".index(axis)
		slot_center = list(center)
		slot_center[axial] += sign * (depth / 2.0 + 0.000008)
		slot_size = [radius * 1.35, radius * 0.24, radius * 0.24]
		if axial == 0:
			slot_size = [radius * 0.24, radius * 1.35, radius * 0.24]
		slot_size[axial] = 0.000024
		self.box("Fastener slot", tuple(slot_center), tuple(slot_size), "DetailGraphite")

	def pocket(self, surface: Vec3, size: Vec3, axis: str, sign: float = 1.0, depth: float = 0.0006) -> None:
		axial = "XYZ".index(axis)
		center, dimensions = list(surface), list(size)
		center[axial] += sign * (0.0004 - depth) / 2.0
		dimensions[axial] = depth + 0.0004
		cutter = self.helpers.add_box("Surface pocket cutter", tuple(center), tuple(dimensions), self.materials["Black"])
		self.subtract(cutter)

	def bore(self, center: Vec3, radius: float, depth: float, axis: str) -> None:
		cutter = self.helpers.add_cylinder("Detail bore cutter", center, radius, depth, axis, self.materials["Black"], 20)
		self.subtract(cutter)

	def subtract(self, cutter: bpy.types.Object) -> None:
		bpy.context.view_layer.objects.active = self.base
		modifier = self.base.modifiers.new(name="Recessed surface detail", type="BOOLEAN")
		modifier.operation = "DIFFERENCE"
		modifier.solver = "EXACT"
		modifier.use_self = True
		modifier.object = cutter
		bpy.ops.object.modifier_apply(modifier=modifier.name)
		bpy.data.objects.remove(cutter, do_unlink=True)

	def panel(
		self, name: str, surface: Vec3, size: Vec3, axis: str, color: str,
		sign: float = 1.0, depth: float = 0.0006,
	) -> None:
		self.pocket(surface, size, axis, sign, depth)
		axial = "XYZ".index(axis)
		center, dimensions = list(surface), list(size)
		center[axial] -= sign * (depth - 0.0001)
		for index in range(3):
			dimensions[index] = 0.0002 if index == axial else dimensions[index] - 0.0002
		self.box(name, tuple(center), tuple(dimensions), color)


def _biped_body(d: Details) -> None:
	# The eye/sensor mounting area and both hip ports remain unobstructed.
	for sign in (-1.0, 1.0):
		d.panel("Side cooling inset", (sign * 0.035, 0.0, 0.0), (0.0, 0.032, 0.026), "X", "DetailGraphite", sign)
		for index in range(6):
			d.box("Cooling louvre", (sign * 0.03478, -0.011 + index * 0.0044, 0.0), (0.00025, 0.0015, 0.022), "DetailSteel", 0.0001)
		for y in (-0.0143, 0.0143):
			d.screw((sign * 0.0348, y, 0.0105), "X", 0.0007, sign)
		d.box("Front cheek seam", (sign * 0.027, 0.0, 0.02268), (0.00065, 0.035, 0.00035), "DetailGraphite")
		d.box("Cheek teal accent", (sign * 0.027, -0.014, 0.02293), (0.0013, 0.007, 0.0004), "DetailTeal", 0.00015)
		d.screw((sign * 0.025, 0.023, 0.02255), "Z", 0.001)
		d.screw((sign * 0.024, -0.023, 0.02255), "Z", 0.001)
	# The existing mouth sets the front envelope, so light bars sit in a shallow cut.
	d.panel("Mouth grille inset", (0.0, -0.012, 0.0235), (0.024, 0.0026, 0.0), "Z", "DetailGraphite", depth=0.00035)
	for index in range(7):
		d.box("Status grille light", (-0.0093 + index * 0.0031, -0.012, 0.02328), (0.0011, 0.0014, 0.00016), "DetailTeal", 0.00008)
	d.cylinder("Chest badge", (0.0, -0.022, 0.02288), 0.0032, 0.0006, "Z", "DetailTeal", 24)
	for x, y in ((-0.0007, -0.0215), (0.0007, -0.0225)):
		d.box("Snap badge mark", (x, y, 0.02324), (0.0013, 0.0013, 0.00012), "DetailWhite", 0.00015)
	d.box("Rear service panel", (0.0, -0.008, -0.02285), (0.042, 0.024, 0.00065), "DetailGraphite", 0.0003)
	d.box("Rear panel face", (0.0, -0.008, -0.02321), (0.0385, 0.0205, 0.00022), "DetailSteel", 0.0001)
	for x in (-0.017, 0.017):
		for y in (-0.016, 0.0):
			d.screw((x, y, -0.02345), "Z", 0.00085, -1.0)
	for index in range(4):
		d.box("Rear service vent", (0.0, -0.012 + index * 0.003, -0.0234), (0.022, 0.0008, 0.00012), "DetailGraphite")
	d.box("Rear identification stripe", (0.0, 0.0215, -0.0229), (0.019, 0.002, 0.0006), "DetailTeal", 0.0002)


def _leg_link(d: Details) -> None:
	d.panel("Recessed shin", (0.0, -0.004, 0.008), (0.008, 0.026, 0.0), "Z", "DetailGraphite", depth=0.00075)
	for index in range(5):
		d.box("Shin protective rib", (0.0, -0.012 + index * 0.004, 0.00767), (0.0071, 0.0014, 0.00028), "DetailSteel", 0.00012)
	for y in (-0.0155, 0.0075):
		d.box("Shin teal marker", (0.0, y, 0.00768), (0.0065, 0.0011, 0.00024), "DetailTeal", 0.0001)
	d.bore((0.0061, 0.014, 0.0), 0.0034, 0.0013, "X")
	d.ring("Hip bearing trim", (0.00565, 0.014, 0.0), 0.0015, 0.00325, 0.00032, "X", "DetailTeal")
	d.panel("Rear leg cable channel", (0.0, -0.003, -0.008), (0.0035, 0.027, 0.0), "Z", "DetailGraphite", -1.0)
	for y in (-0.013, 0.007):
		d.box("Cable retaining bridge", (0.0, y, -0.00768), (0.0032, 0.0014, 0.00028), "DetailTeal", 0.0001)


def _foot(d: Details) -> None:
	for x in (-0.023, 0.023):
		for z in (-0.007, 0.0, 0.007):
			d.box("Upper grip pad", (x, 0.00435, z), (0.010, 0.001, 0.0055), "Rubber", 0.0004)
	for z in (-0.0195, 0.0195):
		d.box("Toe bumper insert", (0.0, 0.00415, z), (0.046, 0.0008, 0.003), "DetailGraphite", 0.0003)
		d.box("Toe teal marker", (0.0, 0.00465, z), (0.022, 0.0003, 0.0012), "DetailTeal", 0.00012)
	for sign in (-1.0, 1.0):
		d.ring("Ankle bearing trim", (0.0, 0.024, sign * 0.01572), 0.00155, 0.0044, 0.0004, "Z", "DetailTeal", 24)
		for x in (-0.0076, 0.0076):
			d.box("Ankle reinforcing rib", (x, 0.017, sign * 0.01567), (0.0015, 0.021, 0.0005), "DetailSteel", 0.0002)
			d.screw((x, 0.010, sign * 0.01603), "Z", 0.0007, sign)
		d.panel("Side bumper seam", (sign * 0.0325, 0.0, 0.0), (0.0, 0.0018, 0.030), "X", "DetailTeal", sign, 0.00045)


def _servo(d: Details) -> None:
	for y in (-0.0058, 0.010):
		for sign in (-1.0, 1.0):
			d.box("Servo case split", (0.0, y, sign * 0.0061), (0.020, 0.0005, 0.0003), "DetailGraphite")
			d.box("Servo side case split", (sign * 0.0116, y, 0.0), (0.0003, 0.0005, 0.009), "DetailGraphite")
	for x in (-0.008, 0.008):
		for y in (-0.0132, 0.0122):
			d.screw((x, y, 0.0061), "Z", 0.00065)
	for x in (-0.012, 0.012):
		for z in (-0.0055, 0.0055):
			d.screw((x, -0.0063, z), "Y", 0.0007)
	d.box("Servo specification plate", (-0.0005, 0.0015, 0.0062), (0.015, 0.009, 0.0004), "Silver", 0.0002)
	d.box("Servo label", (-0.0005, 0.0015, 0.00645), (0.0138, 0.0078, 0.00016), "DetailGraphite", 0.00008)
	d.box("Servo label accent", (-0.0054, 0.0015, 0.00657), (0.0014, 0.0055, 0.00012), "DetailTeal")
	for y, width in ((0.0035, 0.0072), (0.0018, 0.0053), (-0.0004, 0.0072)):
		d.box("Servo label print", (0.0008, y, 0.00657), (width, 0.0006, 0.00012), "DetailWhite")
	d.ring("Output bearing seat", (0.01464, 0.005, 0.0), 0.0028, 0.0039, 0.0002, "X", "DetailSteel")
	for y in (-0.003, 0.0, 0.003, 0.006):
		d.box("Rear casing rib", (0.0, y, -0.0062), (0.018, 0.0007, 0.0005), "ServoBlue", 0.00015)


def _hc_sr04(d: Details) -> None:
	for x in (-0.013, 0.013):
		# Recess the existing black disc before placing the real crosshatched grille.
		d.bore((x, 0.0, 0.01335), 0.0059, 0.0005, "Z")
		d.ring("Transducer face bezel", (x, 0.0, 0.0132), 0.00625, 0.0072, 0.00016, "Z", "Silver", 24)
		for index in range(-5, 6):
			offset = index * 0.00095
			length = 2.0 * math.sqrt(0.00565**2 - offset**2)
			d.box("Transducer grille horizontal", (x, offset, 0.01318), (length, 0.00018, 0.00012), "DetailSteel")
			d.box("Transducer grille vertical", (x + offset, 0.0, 0.01322), (0.00018, length, 0.00012), "Silver")
	for x in (-0.0032, 0.0, 0.0032):
		d.box("Sensor status component", (x, 0.0077, 0.0011), (0.0016, 0.0012, 0.0006), "DetailWhite")
	d.box("Sensor status LED", (0.0, -0.006, 0.0013), (0.0014, 0.0018, 0.0008), "DetailAmber", 0.00015)
	for x in (-0.0055, 0.0055):
		for y in (-0.0055, -0.0038, -0.0021):
			d.box("Sensor IC solder leg", (x, y, -0.00175), (0.0012, 0.00065, 0.0006), "Silver")


def _arduino_uno(d: Details) -> None:
	for index in range(14):
		x = -0.0055 + index * 0.00254
		for sign in (-1.0, 1.0):
			d.box("ATmega bent pin", (x, 0.0017, -0.0095 + sign * 0.0045), (0.00065, 0.0015, 0.0015), "Silver")
	d.box("USB jack dark opening", (-0.03552, 0.0063, 0.0165), (0.0001, 0.0075, 0.0087), "DetailGraphite", 0.000035)
	d.box("USB jack tongue", (-0.03559, 0.0059, 0.0165), (0.000015, 0.0024, 0.0055), "DetailWhite")
	d.box("Auxiliary controller", (-0.011, 0.0020, 0.009), (0.006, 0.0024, 0.006), "Black", 0.00025)
	for index in range(6):
		for sign in (-1.0, 1.0):
			d.box("Controller solder lead", (-0.0133 + index * 0.00092, 0.0013, 0.009 + sign * 0.0035), (0.00045, 0.0006, 0.001), "Silver")
	for x, z in ((-0.014, -0.009), (-0.012, -0.016), (-0.003, 0.013), (0.004, 0.010), (0.014, 0.006), (0.021, 0.007)):
		d.box("SMD resistor", (x, 0.0014, z), (0.0026, 0.001, 0.0013), "DetailWhite", 0.00012)
		for side in (-1.0, 1.0):
			d.box("SMD solder pad", (x + side * 0.0015, 0.0010, z), (0.0008, 0.0003, 0.0015), "Silver")
	for x, z in ((-0.019, -0.0065), (-0.022, -0.0105)):
		d.cylinder("Electrolytic capacitor", (x, 0.0034, z), 0.0017, 0.005, "Y", "DetailSteel", 16)
		d.cylinder("Capacitor top", (x, 0.00595, z), 0.00135, 0.00014, "Y", "Silver", 16)
		d.box("Capacitor scored vent", (x, 0.00605, z), (0.0019, 0.00004, 0.00018), "DetailGraphite")
	for x, color in ((0.006, "DetailAmber"), (0.010, "DetailTeal")):
		d.box("Board indicator LED", (x, 0.0015, 0.016), (0.0014, 0.0012, 0.0022), color, 0.00015)
	for index in range(4):
		d.box("PCB silkscreen legend", (0.0205, 0.00087, -0.0005 + index * 0.0016), (0.009 - index * 0.0014, 0.00006, 0.00035), "DetailWhite")
	for x, z in ((0.0, 0.006), (0.008, 0.003), (0.024, 0.013)):
		d.box("PCB trace", (x, 0.00084, z), (0.007, 0.00004, 0.00022), "DetailCopper")


def _board(d: Details) -> None:
	for index in range(6):
		for sign in (-1.0, 1.0):
			d.box("Controller lead", (0.0025 + index * 0.0022, 0.0031, sign * 0.0068), (0.0007, 0.001, 0.0018), "Silver")
	for x, z in ((-0.009, -0.014), (-0.004, -0.014), (0.010, 0.016)):
		d.box("Board component", (x, 0.0033, z), (0.003, 0.0015, 0.0015), "DetailWhite", 0.00015)
		for sign in (-1.0, 1.0):
			d.box("Solder pad", (x + sign * 0.0018, 0.0027, z), (0.001, 0.0002, 0.0018), "Silver")
	d.box("Power indicator", (0.024, 0.0032, -0.015), (0.0016, 0.0014, 0.0024), "DetailTeal", 0.00015)
	for index in range(3):
		d.box("Board legend", (-0.011, 0.00255, 0.012 + index * 0.002), (0.016 - index * 0.003, 0.00006, 0.00045), "DetailWhite")
	for x in (-0.025, 0.026):
		for z in (-0.020, 0.020):
			d.screw((x, 0.00265, z), "Y", 0.001)


def _base(d: Details) -> None:
	for x in (-0.032, 0.032):
		for z in (-0.032, 0.032):
			d.bore((x, 0.0101, z), 0.0038, 0.0012, "Y")
			d.ring("Base mounting collar", (x, 0.00973, z), 0.00255, 0.00365, 0.0003, "Y", "DetailSteel", 20)
	d.panel("Base identification plate", (0.0, 0.010, 0.028), (0.029, 0.0, 0.006), "Y", "DetailGraphite", depth=0.0006)
	d.box("Base teal label", (0.0, 0.0097, 0.028), (0.021, 0.00016, 0.0011), "DetailTeal")
	for sign in (-1.0, 1.0):
		d.panel("Base side bumper inset", (sign * 0.04, 0.0, 0.0), (0.0, 0.006, 0.040), "X", "DetailGraphite", sign)
		for z in (-0.012, 0.0, 0.012):
			d.box("Base bumper ridge", (sign * 0.0397, 0.0, z), (0.0002, 0.004, 0.0015), "DetailTeal")


def _arm_link(d: Details) -> None:
	# Markers fit between the existing through-holes without covering a mounting bore.
	for y, width in ((-0.023, 0.0057), (-0.002, 0.0047), (0.017, 0.004), (0.034, 0.0035)):
		d.panel("Arm index inset", (0.0, y, 0.005), (width, 0.002, 0.0), "Z", "DetailTeal", depth=0.00035)


def _tt_motor(d: Details) -> None:
	for sign in (-1.0, 1.0):
		d.box("Gearbox casing seam", (-0.016, 0.0, sign * 0.00912), (0.031, 0.00055, 0.0002), "DetailGraphite")
		for x in (-0.030, -0.013):
			d.screw((x, 0.006, sign * 0.00922), "Z", 0.00085, sign)
	d.box("Gearbox identification plate", (-0.014, 0.0045, 0.00925), (0.010, 0.006, 0.0004), "DetailGraphite", 0.00018)
	for y in (0.0035, 0.0055):
		d.box("Gearbox label print", (-0.014, y, 0.00952), (0.0065, 0.0006, 0.00012), "DetailWhite")
	for x in (0.007, 0.030):
		d.ring("Motor can seam", (x, 0.0, 0.0), 0.0097, 0.01005, 0.0007, "X", "DetailSteel", 24)
	for z in (-0.004, 0.0, 0.004):
		d.box("Motor end cooling slot", (0.03651 - 0.00013, 0.0015, z), (0.00016, 0.004, 0.0007), "DetailSteel")


def decorate(part_name: str, obj: bpy.types.Object, materials: Materials, helpers: ModuleType) -> bpy.types.Object:
	"""Add baked detail geometry, keeping the part's full AABB and material bounds intact."""
	decorators = {
		"base": _base,
		"servo": _servo,
		"arm_link": _arm_link,
		"board": _board,
		"arduino_uno": _arduino_uno,
		"tt_motor": _tt_motor,
		"hc_sr04": _hc_sr04,
		"biped_body": _biped_body,
		"leg_link": _leg_link,
		"foot": _foot,
	}
	if part_name not in decorators:
		return obj
	before = _bounds(obj)
	# Custom-built source meshes can have inward faces, which invert Boolean cuts.
	mesh = bmesh.new()
	mesh.from_mesh(obj.data)
	bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
	mesh.to_mesh(obj.data)
	mesh.free()
	details = Details(obj, materials, helpers)
	decorators[part_name](details)
	joined = helpers.join_parts(part_name, details.parts)
	joined.data.calc_loop_triangles()
	triangles = len(joined.data.loop_triangles)
	if triangles >= 5000:
		raise ValueError(f"{part_name}: {triangles} triangles exceeds the 5000-triangle budget")
	after = _bounds(joined)
	for old_corner, new_corner in zip(before, after, strict=True):
		for old_value, new_value in zip(old_corner, new_corner, strict=True):
			if abs(old_value - new_value) > 0.0000001:
				raise ValueError(f"{part_name}: detail changed the physics envelope: {before} -> {after}")
	return joined


def cleanup_export_mesh(obj: bpy.types.Object) -> None:
	"""Bake valid triangles at the OBJ writer's six-decimal world-space precision."""
	def rounded_area_squared(points: list[Vec3]) -> int:
		a, b, c = [tuple(round(value * 1000000) for value in point) for point in points]
		ab, ac = [b[index] - a[index] for index in range(3)], [c[index] - a[index] for index in range(3)]
		cross = (
			ab[1] * ac[2] - ab[2] * ac[1],
			ab[2] * ac[0] - ab[0] * ac[2],
			ab[0] * ac[1] - ab[1] * ac[0],
		)
		return sum(value * value for value in cross)

	before = _bounds(obj)
	mesh = bmesh.new()
	mesh.from_mesh(obj.data)
	inverse = obj.matrix_world.inverted()
	for vertex in mesh.verts:
		world_position = obj.matrix_world @ vertex.co
		for axis in range(3):
			world_position[axis] = round(world_position[axis], 6)
		vertex.co = inverse @ world_position
	# Boolean intersections and fully clamped bevels can leave coincident corners.
	bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=0.00000001)
	bmesh.ops.dissolve_degenerate(mesh, edges=list(mesh.edges), dist=0.0000001)
	bmesh.ops.triangulate(mesh, faces=list(mesh.faces), quad_method="FIXED", ngon_method="EAR_CLIP")
	bmesh.ops.dissolve_degenerate(mesh, edges=list(mesh.edges), dist=0.0000001)
	bmesh.ops.triangulate(mesh, faces=list(mesh.faces), quad_method="FIXED", ngon_method="EAR_CLIP")
	# Collinear Boolean slivers may have long edges despite having no area.
	flat_faces = [
		face for face in mesh.faces
		if rounded_area_squared([tuple(obj.matrix_world @ vertex.co) for vertex in face.verts]) <= 1
	]
	if flat_faces:
		bmesh.ops.delete(mesh, geom=flat_faces, context="FACES_ONLY")
	loose_vertices = [vertex for vertex in mesh.verts if not vertex.link_faces]
	if loose_vertices:
		bmesh.ops.delete(mesh, geom=loose_vertices, context="VERTS")
	bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
	mesh.to_mesh(obj.data)
	mesh.free()
	obj.data.update()
	obj.data.calc_loop_triangles()
	triangles = obj.data.loop_triangles
	if not 0 < len(triangles) < 5000:
		raise ValueError(f"{obj.name}: invalid cleaned triangle count {len(triangles)}")
	for triangle in triangles:
		points = [tuple(obj.matrix_world @ obj.data.vertices[index].co) for index in triangle.vertices]
		if rounded_area_squared(points) <= 1:
			raise ValueError(f"{obj.name}: export cleanup left a degenerate triangle")
	after = _bounds(obj)
	for old_corner, new_corner in zip(before, after, strict=True):
		for old_value, new_value in zip(old_corner, new_corner, strict=True):
			if abs(old_value - new_value) > 0.00000051:
				raise ValueError(f"{obj.name}: export cleanup changed the envelope beyond OBJ precision")
