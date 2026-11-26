extends RefCounted
## Procedural detail for the kit's miniature hardware. Dimensions below are in mm.
## Frames map the profile plane onto each existing part's axis convention.

const LEGACY_IDS: Array[String] = ["microbit", "motor_driver", "tb6612_driver", "ball_caster", "flag"]
const KIT_IDS: Array[String] = ["kit_led", "kit_wheel_40", "kit_wheel_90", "kit_gear_2", "kit_gear_3"]
const HORIZONTAL := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
const DOWNWARD := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
const FINISHES := {
	"pcb_black": [Color("252324"), 0.0, 0.81],
	"pcb_red": [Color("9b3c36"), 0.0, 0.69],
	"pcb_green": [Color("245b51"), 0.0, 0.67],
	"gold": [Color("d6a55b"), 0.53, 0.39],
	"steel": [Color("aab3bc"), 0.60, 0.36],
	"zinc": [Color("83929b"), 0.47, 0.51],
	"ink": [Color("d8cdb6"), 0.0, 0.79],
	"chip": [Color("34353a"), 0.0, 0.61],
	"rubber": [Color("25272b"), 0.0, 0.92],
	"lens": [Color("d6382c"), 0.0, 0.37],
	"glass": [Color(0.96, 0.16, 0.075, 0.64), 0.0, 0.25],
	"led_window": [Color("8f4257"), 0.0, 0.43],
	"blue": [Color("375d7c"), 0.0, 0.63],
	"cream": [Color("d9ba84"), 0.0, 0.62],
	"teal": [Color("507d75"), 0.0, 0.60],
	"orange": [Color("d76b36"), 0.0, 0.71],
	"hem": [Color("e99351"), 0.0, 0.66],
}

var _surfaces: Dictionary[String, SurfaceTool]
var _frame := Basis.IDENTITY
var _bounds := AABB()
var _has_vertex := false


static func build(definition: PartDef, envelope: AABB) -> ArrayMesh:
	var detail: RefCounted = new()
	var id: String = definition.id
	match id:
		"microbit": detail._microbit(definition)
		"motor_driver", "tb6612_driver": detail._driver(definition, id == "motor_driver")
		"ball_caster": detail._caster(definition)
		"kit_led": detail._led(definition)
		"kit_wheel_40", "kit_wheel_90": detail._wheel(definition.wheel_radius * 1000.0)
		"kit_gear_2", "kit_gear_3": detail._gearbox(definition, id == "kit_gear_3")
		"flag": detail._flag(definition)
		_: return null
	return detail._mesh(id, envelope)


func _microbit(definition: PartDef) -> void:
	_frame = HORIZONTAL
	var holes := _holes(definition)
	var edge_holes: Array[Vector2] = [Vector2(-20, -17.2), Vector2(-10, -17.2),
		Vector2(0, -17.2), Vector2(10, -17.2), Vector2(20, -17.2)]
	_plate(Vector2(-26, -21.5), Vector2(26, -13.25), edge_holes, 2.75, 2.0, -2.5, -0.85, "pcb_black", Vector2(1, 0))
	_plate(Vector2(-26, -13.25), Vector2(26, 21.5), holes, 2.0, 4.0, -2.5, -0.85, "pcb_black", Vector2(0, 1))
	for hole: Vector2 in edge_holes:
		_ring(hole, 2.75, 3.6, -0.85, -0.69, "gold", 20)
	for pin: int in range(-24, 25, 2):
		_box(Vector3(pin, -21.05, -0.78), Vector3(0.75, 0.9, 0.14), "gold")
	for hole: Vector2 in holes:
		_ring(hole, 2.0, 2.6, -0.85, -0.70, "gold", 12)
	for row: int in range(-2, 3):
		for column: int in range(-2, 3):
			var center := Vector3(column * 3.25, row * 3.25 + 0.7, -0.38)
			_box(center, Vector3(2.32, 2.16, 0.94), "chip")
			_box(center + Vector3(0, 0, 0.49), Vector3(1.28, 0.98, 0.18), "led_window")
	for button: float in [-17.4, 17.4]:
		_box(Vector3(button, 0, -0.25), Vector3(6.6, 6.2, 1.2), "steel")
		_lathe(Vector2(button, 0), [Vector2(2.55, 0.35), Vector2(2.55, 1.30), Vector2(2.12, 1.72)], "chip", 16)
		_lathe(Vector2(button, 0), [Vector2(1.32, 1.72), Vector2(1.32, 1.86)], "rubber", 12)
		for contact: float in [-2.5, 2.5]:
			_box(Vector3(button + contact, -3.48, -0.71), Vector3(1.2, 1.0, 0.27), "gold")
	_socket(Vector2(-0.9, 18.8), 8.4, 5.4, -0.85, 2.5, "steel")
	_socket(Vector2(13.8, 17.65), 6.0, 5.1, -0.85, 2.10, "ink")
	_box(Vector3(-15.4, 15.6, -0.34), Vector3(5.8, 4.3, 1.02), "chip")
	for pin: int in 5:
		_box(Vector3(-17.4 + pin, 12.9, -0.72), Vector3(0.4, 1.2, 0.26), "steel")
	for trace: int in 4:
		var offset: float = trace * 0.85
		_box(Vector3(-23.0 + offset, 11.4, -0.79), Vector3(0.37, 6.2 - offset, 0.12), "gold")
	for x: float in [-20, 20]:
		_box(Vector3(x, -5.65, -0.79), Vector3(3.5, 0.34, 0.12), "ink")


func _driver(definition: PartDef, heat_sink: bool) -> void:
	_frame = HORIZONTAL
	var pcb: String = "pcb_red" if heat_sink else "pcb_green"
	var holes := _holes(definition)
	var pcb_bottom: float = -4.0 if heat_sink else -3.8
	_plate(Vector2(-20, -14), Vector2(20, 14), holes, 2.0, 1.1, pcb_bottom, -2.1, pcb)
	for hole: Vector2 in holes:
		_ring(hole, 2.0, 2.65, -2.1, -1.94, "gold", 12)
	_chip(Vector2(-1.0, 0.4), Vector2(13.0, 6.2) if heat_sink else Vector2(8.2, 5.2),
		-2.1, 0.2, 8 if heat_sink else 6)
	if heat_sink:
		_box(Vector3(-1.0, 0.25, 0.65), Vector3(12.2, 6.15, 0.9), "zinc")
		for fin: int in 6:
			_box(Vector3(-6.15 + fin * 2.06, 0.25, 2.55), Vector3(0.82, 6.15, 2.9), "zinc")
		for x: float in [-15.55, 15.55]:
			_terminal(Vector2(x, -9.4), -2.1)
		_pin_row(Vector2(-15.0, 13.0), 4, 2.0, -2.1, 2.65)
		_pin_row(Vector2(8.0, 13.0), 4, 2.0, -2.1, 2.65)
	else:
		_pin_row(Vector2(-13.4, -13.0), 4, 2.54, -2.1, 3.5)
		_pin_row(Vector2(5.75, -13.0), 4, 2.54, -2.1, 3.5)
		_pin_row(Vector2(-16.5, 13.0), 3, 2.54, -2.1, 4.0)
		_pin_row(Vector2(10.45, 13.0), 3, 2.54, -2.1, 4.0)
		for start: float in [-16.5, 10.45]:
			for pin: int in 3:
				_box(Vector3(start + pin * 2.54, 13.0, -3.9), Vector3(1.48, 1.25, 0.2), "gold")
	for center: Vector2 in [Vector2(-13.6, 2.8), Vector2(13.8, 3.5 if heat_sink else -2.0)]:
		var radius: float = 2.45 if heat_sink else 1.68
		var top: float = 2.2 if heat_sink else 0.66
		_lathe(center, [Vector2(radius, -2.1), Vector2(radius, top - 0.30)], "chip", 16)
		_lathe(center, [Vector2(radius, top - 0.31), Vector2(radius - 0.19, top)], "steel", 16)
	for position: Vector2 in [Vector2(-5.0, -9.0), Vector2(5.0, 8.4), Vector2(0.0, -8.4), Vector2(17, 1)]:
		_box(Vector3(position.x, position.y, -1.95), Vector3(3.4, 1.55, 0.3), "steel")
		_box(Vector3(position.x, position.y, -1.69), Vector3(2.0, 1.55, 0.82), "cream")
	_box(Vector3(0, 9, -2.04), Vector3(5.5, 0.38, 0.12), "ink")


func _caster(definition: PartDef) -> void:
	_frame = HORIZONTAL
	_plate(Vector2(-12, -12), Vector2(12, 12), _holes(definition), 1.93, 2.8, 9.8, 12.0, "steel")
	_frame = DOWNWARD
	# Pressed skirt and return lip, open at the bottom to expose the roller.
	_profile(Vector2.ZERO, [Vector2(8.0, -9.8), Vector2(9.55, -7.4), Vector2(9.65, -3.0),
		Vector2(9.55, 2.9), Vector2(8.95, 5.5), Vector2(8.25, 5.7), Vector2(7.85, 4.8),
		Vector2(8.85, 1.7), Vector2(9.05, -3.3), Vector2(8.70, -7.8), Vector2(7.4, -9.8)], "zinc", 32)
	_dome(Vector2.ZERO, 8.05, 3.95, 12.0, "steel", 24, 8, true)


func _led(definition: PartDef) -> void:
	_plate(Vector2(-20, -10), Vector2(20, 25.999999), _holes(definition), 2.0, 2.4, -2, 2, "pcb_green")
	for hole: Vector2 in _holes(definition):
		_ring(hole, 2.0, 3.1, 2, 2.35, "gold", 16)
	_box(Vector3(0, 13.2, -3.2), Vector3(7.8, 6.2, 3.9), "chip")
	_box(Vector3(0, 13.2, -5.55), Vector3(8.45, 6.8, 0.9), "chip")
	for x: float in [-2.4, 2.4]:
		_box(Vector3(x, 13.2, -4.2), Vector3(0.95, 8.4, 0.8), "steel")
		_box(Vector3(x, 6.45, 2.2), Vector3(1.1, 6.0, 0.4), "gold")
		_box(Vector3(x, 0, 5.65), Vector3(1.15, 1.2, 7.3), "steel")
	_box(Vector3(0.8, 0, 8.3), Vector3(3.2, 2.3, 0.6), "lens")
	_lathe(Vector2.ZERO, [Vector2(7.9, 2.0), Vector2(7.9, 3.7), Vector2(7.25, 4.4)], "chip", 32)
	_lathe(Vector2.ZERO, [Vector2(7.17, 4.4), Vector2(7.17, 5.55)], "lens", 32)
	_profile(Vector2.ZERO, [Vector2(7.0, 5.55), Vector2(7.0, 10.0)], "glass", 32, true)
	_dome(Vector2.ZERO, 7.0, 10.0, 17.0, "glass", 32, 7)
	_box(Vector3(0, 20, 2.08), Vector3(9.0, 0.55, 0.16), "ink")
	_box(Vector3(-6, 14, 2.08), Vector3(0.55, 4.2, 0.16), "ink")


func _wheel(radius: float) -> void:
	var rim: float = radius * 0.71
	var boss: float = 7.2 if radius < 25.0 else 9.6
	var bore: float = 3.95
	var segments: int = 48 if radius < 25.0 else 64
	_profile(Vector2.ZERO, [Vector2(rim - 0.3, -7.70), Vector2(radius - 2.1, -7.70),
		Vector2(radius - 0.62, -6.2), Vector2(radius - 0.48, -3.8), Vector2(radius - 0.48, 3.8),
		Vector2(radius - 0.62, 6.2), Vector2(radius - 2.1, 7.70), Vector2(rim - 0.3, 7.70)], "rubber", segments)
	_profile(Vector2.ZERO, [Vector2(rim - 1.65, -8.55), Vector2(rim - 0.4, -8.55),
		Vector2(rim + 0.45, -7.6), Vector2(rim + 0.45, 7.6), Vector2(rim - 0.4, 8.55),
		Vector2(rim - 1.65, 8.55), Vector2(rim - 2.3, 7.65), Vector2(rim - 2.3, -7.65)], "cream", segments)
	_profile(Vector2.ZERO, [Vector2(bore, -10), Vector2(boss - 0.55, -10), Vector2(boss, -8.85),
		Vector2(boss, 8.85), Vector2(boss - 0.55, 10), Vector2(bore, 10)], "cream", 32)
	for side: float in [-1, 1]:
		_ring(Vector2.ZERO, bore + 0.1, boss - 1.35, minf(9.68 * side, 9.99 * side), maxf(9.68 * side, 9.99 * side), "zinc", 24)
	var spokes: int = 6 if radius < 25.0 else 8
	for index: int in spokes:
		var angle: float = TAU * index / spokes
		var half_width: float = 1.8 if spokes == 6 else 2.85
		var shape := PackedVector2Array([Vector2(boss - 0.9, -half_width), Vector2(rim - 1.1, -half_width * 0.74),
			Vector2(rim - 1.1, half_width * 0.74), Vector2(boss - 0.9, half_width)])
		for corner: int in shape.size():
			shape[corner] = shape[corner].rotated(angle)
		_prism(shape, -4.2, 4.2, "cream")
	# Low-profile staggered tread is built to the original rolling radius.
	for index: int in segments / 2:
		var step: float = TAU * index / (segments / 2)
		for side: float in [-1, 1]:
			var angle: float = step + (0.08 if side > 0 else 0.0)
			var tooth := PackedVector2Array([_polar(radius - 0.7, angle - 0.062),
				_polar(radius, angle - 0.043), _polar(radius, angle), _polar(radius, angle + 0.043),
				_polar(radius - 0.7, angle + 0.062)])
			_prism(tooth, minf(0.40 * side, 4.90 * side), maxf(0.40 * side, 4.90 * side), "rubber")


func _gearbox(definition: PartDef, high_ratio: bool) -> void:
	_plate(Vector2(-20, -10), Vector2(20, 9.8), _holes(definition), 2.0, 2.5, -2, 2, "zinc")
	for hole: Vector2 in _holes(definition):
		_ring(hole, 2.0, 3.35, 2.0, 2.9, "steel", 16)
	_box(Vector3(0, 8.75, -3.1), Vector3(13.5, 4.0, 5.8), "chip")
	_spur(Vector2(-2.0, 15), 11.0, 24 if high_ratio else 16, PI / 2.0, "cream" if high_ratio else "teal")
	if high_ratio:
		_spur(Vector2(11.3, 18.7), 4.8, 8, PI / 8.0, "zinc")
	else:
		_spur(Vector2(12.4, 18.3), 6.3, 8, PI / 8.0, "zinc")
	_box(Vector3(0, -6, 2.1), Vector3(9.0, 0.44, 0.20), "ink")


func _flag(definition: PartDef) -> void:
	_plate(Vector2(-12.5, -2.6), Vector2(12.5, 2.6), _holes(definition), 2.0, 0.38, -0.5, 0.5, "zinc")
	_frame = HORIZONTAL
	_lathe(Vector2(-12.0, 0), [Vector2(0.50, -10.0), Vector2(0.50, -6.0), Vector2(0.39, -5.7)], "zinc", 12)
	_lathe(Vector2(-12.26, 0), [Vector2(0.24, -5.7), Vector2(0.20, 10.0)], "chip", 12)
	_frame = Basis.IDENTITY
	_prism(PackedVector2Array([Vector2(-12.13, 4.0), Vector2(-12.13, 10.0),
		Vector2(0.25, 9.7), Vector2(12.50, 7.15), Vector2(0.35, 4.6)]), -0.31, 0.31, "orange")
	_prism(PackedVector2Array([Vector2(-12.13, 4.0), Vector2(-12.13, 10.0),
		Vector2(-10.8, 9.97), Vector2(-10.8, 4.05)]), -0.43, 0.43, "hem")
	_prism(PackedVector2Array([Vector2(5.6, 5.68), Vector2(2.2, 9.30),
		Vector2(3.7, 8.98), Vector2(7.4, 6.06)]), -0.33, 0.33, "hem")


func _chip(center: Vector2, size: Vector2, base: float, top: float, pins: int) -> void:
	_box(Vector3(center.x, center.y, (base + top) * 0.5), Vector3(size.x, size.y, top - base), "chip")
	for pin: int in pins:
		var x: float = center.x + (float(pin) - (pins - 1) * 0.5) * (size.x - 1.8) / (pins - 1)
		for side: float in [-1, 1]:
			var y: float = center.y + side * (size.y * 0.5 + 0.53)
			_box(Vector3(x, y, base + 0.32), Vector3(0.52, 1.26, 0.64), "steel")
	_box(Vector3(center.x - size.x * 0.33, center.y - size.y * 0.25, top + 0.04), Vector3(0.66, 0.54, 0.08), "ink")


func _socket(center: Vector2, width: float, length: float, base: float, top: float, finish: String) -> void:
	var thickness := 0.5
	_box(Vector3(center.x, center.y, top - 0.24), Vector3(width, length, 0.48), finish)
	_box(Vector3(center.x, center.y, base + 0.23), Vector3(width, length, 0.46), finish)
	for side: float in [-1, 1]:
		_box(Vector3(center.x + side * (width - thickness) * 0.5, center.y, (base + top) * 0.5),
			Vector3(thickness, length, top - base - 0.45), finish)
	_box(Vector3(center.x, center.y - (length - 0.65) * 0.5, (base + top) * 0.5),
		Vector3(width - 0.5, 0.65, top - base - 0.42), "chip")
	_box(Vector3(center.x, center.y, (base + top) * 0.5 - 0.28), Vector3(width * 0.56, length - 0.55, 0.43), "chip")
	for contact: float in [-1, 1]:
		_box(Vector3(center.x + contact * width * 0.19, center.y, (base + top) * 0.5),
			Vector3(0.37, length - 0.8, 0.23), "gold")


func _terminal(center: Vector2, base: float) -> void:
	_box(Vector3(center.x, center.y, base + 0.75), Vector3(6.9, 8.65, 1.5), "blue")
	_box(Vector3(center.x, center.y, base + 4.05), Vector3(6.9, 8.65, 2.6), "blue")
	for x: float in [-2.82, 2.82]:
		_box(Vector3(center.x + x, center.y, base + 2.18), Vector3(1.25, 8.65, 2.3), "blue")
	_box(Vector3(center.x, center.y + 3.75, base + 2.3), Vector3(5.2, 1.18, 2.5), "chip")
	var top: float = base + 5.35
	_lathe(center, [Vector2(1.75, top), Vector2(1.75, top + 0.40)], "steel", 16)
	_box(Vector3(center.x, center.y, top + 0.41), Vector3(2.9, 0.44, 0.06), "chip")


func _pin_row(start: Vector2, count: int, pitch: float, base: float, top: float) -> void:
	var width: float = (count - 1) * pitch
	_box(Vector3(start.x + width * 0.5, start.y, base + 0.65), Vector3(width + 1.85, 2.0, 1.3), "chip")
	for i: int in count:
		_box(Vector3(start.x + i * pitch, start.y, (base + top) * 0.5), Vector3(0.72, 0.72, top - base), "gold")


func _spur(center: Vector2, radius: float, teeth: int, phase: float, finish: String) -> void:
	var rim := PackedVector2Array()
	for tooth: int in teeth:
		var step: float = TAU / teeth
		var angle: float = step * tooth + phase
		rim.append(center + _polar(radius * 0.86, angle - step * 0.44))
		rim.append(center + _polar(radius * 0.98, angle - step * 0.21))
		rim.append(center + _polar(radius, angle))
		rim.append(center + _polar(radius * 0.98, angle + step * 0.21))
		rim.append(center + _polar(radius * 0.86, angle + step * 0.44))
	var bore: float = minf(radius * 0.33, 3.4)
	var inner := PackedVector2Array()
	for point: Vector2 in rim:
		inner.append(center + (point - center).normalized() * bore)
	_annulus(rim, inner, 1.15, 4.10, finish)
	_ring(center, bore, bore + 1.45, 4.10, 6.00, "steel", 24)

func _plate(lower: Vector2, upper: Vector2, holes: Array[Vector2], radius: float,
		corner: float, base: float, top: float, finish: String, round_edges := Vector2.ONE) -> void:
	var rows: Dictionary[float, Array] = {}
	for hole: Vector2 in holes:
		if not rows.has(hole.y):
			rows[hole.y] = []
		rows[hole.y].append(hole.x)
	var ordinates: Array = rows.keys()
	ordinates.sort()
	for row: int in ordinates.size():
		var y: float = ordinates[row]
		var lo: float = lower.y if row == 0 else (y + ordinates[row - 1]) * 0.5
		var hi: float = upper.y if row == ordinates.size() - 1 else (y + ordinates[row + 1]) * 0.5
		var xs: Array = rows[y]
		xs.sort()
		for column: int in xs.size():
			var x: float = xs[column]
			var left: float = lower.x if column == 0 else (x + xs[column - 1]) * 0.5
			var right: float = upper.x if column == xs.size() - 1 else (x + xs[column + 1]) * 0.5
			var measures := [
				corner * round_edges.x if column == 0 and row == 0 else 0.0,
				corner * round_edges.x if column == xs.size() - 1 and row == 0 else 0.0,
				corner * round_edges.y if column == xs.size() - 1 and row == ordinates.size() - 1 else 0.0,
				corner * round_edges.y if column == 0 and row == ordinates.size() - 1 else 0.0,
			]
			var contour := _rounded_rectangle(Vector2(left, lo), Vector2(right, hi), measures)
			_perforated_cell(contour, Vector2(x, y), radius, base, top, finish)


func _rounded_rectangle(lower: Vector2, upper: Vector2, radii: Array) -> PackedVector2Array:
	var corners := [lower, Vector2(upper.x, lower.y), upper, Vector2(lower.x, upper.y)]
	var result := PackedVector2Array()
	for i: int in corners.size():
		var corner: Vector2 = corners[i]
		var radius: float = radii[i]
		if is_zero_approx(radius):
			result.append(corner)
			continue
		var start: float = PI + i * PI / 2.0
		var center: Vector2 = corner - (_polar(radius, start) + _polar(radius, start + PI / 2.0))
		for step: int in 5:
			result.append(center + _polar(radius, start + step * PI / 8.0))
	return result


func _perforated_cell(contour: PackedVector2Array, center: Vector2, radius: float,
		base: float, top: float, finish: String) -> void:
	var perimeter: Array[Vector2] = []
	for point: Vector2 in contour:
		perimeter.append(point)
	const HOLE_SEGMENTS := 16
	for i: int in HOLE_SEGMENTS:
		var direction: Vector2 = _polar(200.0, i * TAU / HOLE_SEGMENTS)
		for edge: int in contour.size():
			var intersection: Variant = Geometry2D.segment_intersects_segment(center, center + direction,
				contour[edge], contour[(edge + 1) % contour.size()])
			if intersection != null:
				perimeter.append(intersection)
				break
	perimeter.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a - center).angle() < (b - center).angle())
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for point: Vector2 in perimeter:
		if not outer.is_empty() and point.distance_squared_to(outer[-1]) < 1e-8:
			continue
		outer.append(point)
		inner.append(center + (point - center).normalized() * radius)
	if outer[0].distance_squared_to(outer[-1]) < 1e-8:
		outer.resize(outer.size() - 1)
		inner.resize(inner.size() - 1)
	_annulus(outer, inner, base, top, finish)


func _ring(center: Vector2, inner_radius: float, outer_radius: float, base: float, top: float, finish: String, segments: int) -> void:
	_profile(center, [Vector2(inner_radius, base), Vector2(outer_radius, base),
		Vector2(outer_radius, top), Vector2(inner_radius, top)], finish, segments)


func _lathe(center: Vector2, shape: Array[Vector2], finish: String, segments: int) -> void:
	var capped := shape.duplicate()
	capped.push_front(Vector2(0, shape[0].y))
	capped.append(Vector2(0, shape[-1].y))
	_profile(center, capped, finish, segments)


func _profile(center: Vector2, shape: Array[Vector2], finish: String, segments: int, open := false) -> void:
	for row: int in shape.size() - int(open):
		var a: Vector2 = shape[row]
		var b: Vector2 = shape[(row + 1) % shape.size()]
		if is_zero_approx(a.x) and is_zero_approx(b.x):
			continue
		var slope := Vector2(b.y - a.y, a.x - b.x).normalized()
		for i: int in segments:
			var u: Vector2 = _polar(1.0, i * TAU / segments)
			var v: Vector2 = _polar(1.0, (i + 1) * TAU / segments)
			var nu := Vector3(u.x * slope.x, u.y * slope.x, slope.y)
			var nv := Vector3(v.x * slope.x, v.y * slope.x, slope.y)
			_quad(finish, _point(center + u * a.x, a.y), _point(center + v * a.x, a.y),
				_point(center + v * b.x, b.y), _point(center + u * b.x, b.y), nu, nv, nv, nu)


func _dome(center: Vector2, radius: float, base: float, top: float, finish: String,
		segments: int, bands: int, sphere := false) -> void:
	var start: float = -PI / 2.0 if sphere else 0.0
	for row: int in bands:
		var a: float = lerpf(start, PI / 2.0, float(row) / bands)
		var b: float = lerpf(start, PI / 2.0, float(row + 1) / bands)
		for i: int in segments:
			var u: Vector2 = _polar(1.0, i * TAU / segments)
			var v: Vector2 = _polar(1.0, (i + 1) * TAU / segments)
			_quad(finish, _point(center + u * (radius * cos(a)), lerpf(base, top, sin(a))),
				_point(center + v * (radius * cos(a)), lerpf(base, top, sin(a))),
				_point(center + v * (radius * cos(b)), lerpf(base, top, sin(b))),
				_point(center + u * (radius * cos(b)), lerpf(base, top, sin(b))),
				Vector3(u.x * cos(a), u.y * cos(a), sin(a)), Vector3(v.x * cos(a), v.y * cos(a), sin(a)),
				Vector3(v.x * cos(b), v.y * cos(b), sin(b)), Vector3(u.x * cos(b), u.y * cos(b), sin(b)))


func _annulus(outer: PackedVector2Array, inner: PackedVector2Array, base: float, top: float, finish: String) -> void:
	for i: int in outer.size():
		var j: int = (i + 1) % outer.size()
		_flat_quad(finish, _point(outer[i], top), _point(outer[j], top), _point(inner[j], top), _point(inner[i], top), Vector3.BACK)
		_flat_quad(finish, _point(outer[i], base), _point(outer[j], base), _point(inner[j], base), _point(inner[i], base), Vector3.FORWARD)
		_wall(finish, outer[i], outer[j], base, top)
		_wall(finish, inner[j], inner[i], base, top)


func _box(center: Vector3, size: Vector3, finish: String) -> void:
	var half: Vector3 = size * 0.5
	var shape := PackedVector2Array([Vector2(center.x - half.x, center.y - half.y),
		Vector2(center.x + half.x, center.y - half.y), Vector2(center.x + half.x, center.y + half.y),
		Vector2(center.x - half.x, center.y + half.y)])
	_prism(shape, center.z - half.z, center.z + half.z, finish)


func _prism(shape: PackedVector2Array, base: float, top: float, finish: String) -> void:
	var twice_area := 0.0
	for i: int in shape.size():
		twice_area += shape[i].cross(shape[(i + 1) % shape.size()])
	if twice_area < 0.0:
		shape.reverse()
	for i: int in shape.size():
		_wall(finish, shape[i], shape[(i + 1) % shape.size()], base, top)
	var corners: PackedInt32Array = Geometry2D.triangulate_polygon(shape)
	for i: int in range(0, corners.size(), 3):
		var a: Vector2 = shape[corners[i]]
		var b: Vector2 = shape[corners[i + 1]]
		var c: Vector2 = shape[corners[i + 2]]
		_triangle(finish, _point(a, base), _point(b, base), _point(c, base), Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD)
		_triangle(finish, _point(a, top), _point(b, top), _point(c, top), Vector3.BACK, Vector3.BACK, Vector3.BACK)


func _wall(finish: String, a: Vector2, b: Vector2, base: float, top: float) -> void:
	var edge: Vector2 = (b - a).normalized()
	_flat_quad(finish, _point(a, base), _point(b, base), _point(b, top), _point(a, top), Vector3(edge.y, -edge.x, 0))


func _flat_quad(finish: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_quad(finish, a, b, c, d, normal, normal, normal, normal)


func _quad(finish: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	_triangle(finish, a, b, c, na, nb, nc)
	_triangle(finish, a, c, d, na, nc, nd)


func _triangle(finish: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face: Vector3 = (b - a).cross(c - a)
	if face.length_squared() < 1e-10:
		return
	if not _surfaces.has(finish):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[finish] = surface
	var surface: SurfaceTool = _surfaces[finish]
	_vertex(surface, a, na)
	# Godot uses clockwise front faces.
	if face.dot(na + nb + nc) > 0.0:
		_vertex(surface, c, nc)
		_vertex(surface, b, nb)
	else:
		_vertex(surface, b, nb)
		_vertex(surface, c, nc)


func _vertex(surface: SurfaceTool, point: Vector3, normal: Vector3) -> void:
	var position: Vector3 = _frame * point * 0.001
	if _has_vertex:
		_bounds = _bounds.expand(position)
	else:
		_bounds = AABB(position, Vector3.ZERO)
		_has_vertex = true
	surface.set_normal(_frame * normal)
	surface.add_vertex(position)


func _mesh(id: String, envelope: AABB) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.resource_name = id
	mesh.resource_scene_unique_id = "Mesh_" + id
	# Legacy collision and stage fingerprints consume the visual AABB. Correct only
	# small modeling and floating-point differences at the original envelope.
	if not _bounds.position.is_equal_approx(envelope.position) or not _bounds.end.is_equal_approx(envelope.end):
		push_error("%s detail exceeds or falls short of its mesh envelope: %s vs %s" % [id, _bounds, envelope])
		return null
	for finish: String in _surfaces:
		var surface: SurfaceTool = _surfaces[finish]
		surface.index()
		var arrays: Array = surface.commit_to_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i: int in vertices.size():
			for axis: int in 3:
				if absf(vertices[i][axis] - _bounds.position[axis]) < 0.0000001:
					vertices[i][axis] = envelope.position[axis]
				if absf(vertices[i][axis] - _bounds.end[axis]) < 0.0000001:
					vertices[i][axis] = envelope.end[axis]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var spec: Array = FINISHES[finish]
		var material := StandardMaterial3D.new()
		material.resource_name = finish
		material.resource_scene_unique_id = "Finish_" + finish
		material.albedo_color = spec[0]
		material.metallic = spec[1]
		material.roughness = spec[2]
		if material.albedo_color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	if mesh.get_aabb() != envelope:
		push_error("%s detail mesh bounds %s differ from %s" % [id, mesh.get_aabb(), envelope])
		return null
	return mesh


func _holes(definition: PartDef) -> Array[Vector2]:
	var planes: Array[Vector2] = []
	for port: Port in definition.ports:
		if port.tag != &"kit_m4":
			continue
		var position: Vector3 = _frame.transposed() * (port.local_position * 1000.0)
		var plane := Vector2(position.x, position.y)
		if not planes.has(plane):
			planes.append(plane)
	return planes


static func _point(in_plane: Vector2, depth: float) -> Vector3:
	return Vector3(in_plane.x, in_plane.y, depth)


static func _polar(radius: float, angle: float) -> Vector2:
	return Vector2.from_angle(angle) * radius
