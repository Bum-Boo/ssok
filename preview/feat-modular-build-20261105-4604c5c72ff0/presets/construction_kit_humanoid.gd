class_name ConstructionKitHumanoidPreset
extends RefCounted

const CATALOG: String = "res://assets/construction_kit/parts/"
const CROSS: Basis = Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
const FOOT: Basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))


static func build() -> ConnectionGraph:
	var graph := ConnectionGraph.new()
	var panel: int = _add(graph, "kit_plate_120_80", Vector3(0, 0.75, -0.05))
	var rails: Array[int] = []
	for x: float in [-0.05, 0.05]:
		var rail: int = _attach(graph, panel, _hole(graph, panel, Vector3(x, -0.03, 0.002)), "kit_beam_260", "h6_back")
		rails.append(rail)
	var pelvis: int = _attach(graph, rails[0], "h0_front", "kit_beam_260", "h3_back", CROSS)
	_link(graph, rails[1], "h0_front", pelvis, "h8_back")
	var shoulders: Array[int] = []
	for side: int in 2:
		var extension: int = _attach(graph, rails[side], "h12_front", "kit_beam_100", "h2_back")
		shoulders.append(_attach(graph, extension, "h4_front", "kit_beam_240", "h9_back" if side == 0 else "h1_back", CROSS))
	var board: int = _attach(graph, panel, _hole(graph, panel, Vector3(-0.05, -0.03, -0.002)), "kit_controller", "mount_0_front")
	for item: Array in [[1, -0.05, 0.03], [2, 0.05, -0.03], [3, 0.05, 0.03]]:
		_link(graph, panel, _hole(graph, panel, Vector3(item[1], item[2], -0.002)), board, "mount_%d_front" % item[0])
	var mast: int = _attach(graph, panel, _hole(graph, panel, Vector3(-0.01, 0.03, 0.002)), "kit_beam_260", "h0_back")
	_attach(graph, mast, "h10_front", "kit_optical_sensor", "mount_0_back")
	var pin: int = 2
	for side: int in 2:
		var sign_x: float = -1.0 if side == 0 else 1.0
		var bracket_basis := Basis(Vector3.BACK, sign_x * PI * 0.5)
		var pelvis_port: String = "h2_front" if side == 0 else "h10_front"
		var hip_mount: int = _attach(graph, pelvis, pelvis_port, "kit_angle_bracket", "upright_3_back", bracket_basis)
		var hip: int = _attach(graph, hip_mount, "base_2_back", "kit_motor_35", "mount_2_front" if side == 0 else "mount_2_back")
		_wire(graph, hip, board, pin)
		var knee: int = _segment(graph, hip, false, sign_x, board, pin + 1)
		var ankle: int = _segment(graph, knee, false, sign_x, board, pin + 2)
		_make_foot(graph, ankle)
		var shoulder_port: String = "h4_front" if side == 0 else "h7_front"
		var standoff: int = _attach(graph, shoulders[side], shoulder_port, "kit_spacer_20", "bore_back")
		var shoulder_mount: int = _attach(graph, standoff, "bore_front", "kit_angle_bracket", "upright_3_back", bracket_basis)
		var shoulder: int = _attach(graph, shoulder_mount, "base_2_back", "kit_motor_12", "mount_2_front" if side == 0 else "mount_2_back")
		_wire(graph, shoulder, board, pin + 3)
		var elbow: int = _segment(graph, shoulder, true, sign_x, board, pin + 4)
		_make_hand(graph, elbow, sign_x)
		pin += 5
	_add_fasteners(graph)
	for entry: Dictionary in graph.parts:
		entry.transform.origin += Vector3(-0.01, 0.004, 0)
	graph.parts.append({"part_def": load(HumanoidPreset.CATALOG + "cargo_box.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0.26))})
	return graph


static func _segment(graph: ConnectionGraph, motor: int, small: bool, sign_x: float, board: int, pin: int) -> int:
	var bracket: int = _attach(graph, motor, "output", "kit_u_bracket_small" if small else "kit_u_bracket_large", "axle_right_back")
	var rail_basis := Basis(Vector3.UP, sign_x * PI * 0.5)
	var rails: Array[int] = []
	for corner: int in 2:
		var parent_port: String = "cheek_%d_%s" % [5 + corner if sign_x < 0 else 7 + corner, "back" if sign_x < 0 else "front"]
		rails.append(_attach(graph, bracket, parent_port, "kit_beam_240" if small else "kit_beam_260", "h10_back" if small else "h11_back", rail_basis))
	var next_motor: int = _attach(graph, rails[0], "h0_back" if small else "h1_back", "kit_motor_12" if small else "kit_motor_35", "mount_2_back" if sign_x < 0 else "mount_2_front")
	_link(graph, rails[1], "h0_back" if small else "h1_back", next_motor, "mount_3_back" if sign_x < 0 else "mount_3_front")
	_cross_tie(graph, rails, small, rail_basis)
	_wire(graph, next_motor, board, pin)
	return next_motor


static func _cross_tie(graph: ConnectionGraph, rails: Array[int], small: bool, basis: Basis) -> void:
	var id: String = "kit_plate_80_60" if small else "kit_plate_60_60"
	var rail_port: String = "h6_front"
	var definition: PartDef = load(CATALOG + id + ".tres")
	var z0: float = -0.01 if small else -0.02
	var local_x: float = (basis.inverse() * Vector3(0, 0, z0)).x
	var port: String = _definition_hole(definition, Vector3(local_x, 0, -0.002))
	var tie: int = _attach(graph, rails[0], rail_port, id, port, basis)
	var target: Vector3 = graph.parts[tie].transform.affine_inverse() * _world_port(graph, rails[1], rail_port)
	_link(graph, rails[1], rail_port, tie, _hole(graph, tie, target))


static func _make_foot(graph: ConnectionGraph, motor: int) -> void:
	var bracket: int = _attach(graph, motor, "output", "kit_u_bracket_large", "axle_right_back")
	var pad_basis := Basis(Vector3.RIGHT, PI * 0.5)
	for side: int in 2:
		var definition: PartDef = load(CATALOG + "kit_plate_160_60.tres")
		var port: String = _definition_hole(definition, Vector3(-0.03, 0.02 if side == 0 else -0.02, 0.002))
		var plate: int = _attach(graph, bracket, "base_2_back" if side == 0 else "base_4_back", "kit_plate_160_60", port, FOOT)
		for z: float in [-0.05, -0.01, 0.03]:
			_attach(graph, plate, _hole(graph, plate, Vector3(z, -0.02, -0.002)), "kit_rubber_pad", "h0_back", pad_basis)


static func _make_hand(graph: ConnectionGraph, motor: int, sign_x: float) -> void:
	var bracket: int = _attach(graph, motor, "output", "kit_u_bracket_small", "axle_right_back")
	var rail_basis := Basis(Vector3.UP, sign_x * PI * 0.5)
	var rails: Array[int] = []
	for corner: int in 2:
		var parent_port: String = "cheek_%d_%s" % [5 + corner if sign_x < 0 else 7 + corner, "back" if sign_x < 0 else "front"]
		rails.append(_attach(graph, bracket, parent_port, "kit_beam_240", "h10_back", rail_basis))
	_cross_tie(graph, rails, true, rail_basis)
	var angle_basis: Basis = Basis(Vector3.UP, PI) * Basis(Vector3.BACK, -sign_x * PI * 0.5)
	var angle: int = _attach(graph, rails[1], "h0_front", "kit_angle_bracket", "base_2_front", angle_basis)
	var definition: PartDef = load(CATALOG + "kit_plate_80_60.tres")
	var plate: int = _attach(graph, angle, "upright_3_back", "kit_plate_80_60", _definition_hole(definition, Vector3(sign_x * 0.03, 0, -0.002)))
	_attach(graph, plate, _hole(graph, plate, Vector3(-sign_x * 0.01, 0, 0.002)), "kit_rubber_pad", "h1_back" if sign_x > 0 else "h0_back")


static func build_bridge() -> ConnectionGraph:
	var graph := ConnectionGraph.new()
	var deck: int = _add(graph, "kit_plate_220_120", Vector3(0, 0.19, 0), FOOT)
	var pad_basis := Basis(Vector3.RIGHT, PI * 0.5)
	for side: float in [-1.0, 1.0]:
		var hole: String = _hole(graph, deck, Vector3(side * 0.10, -0.01, -0.002))
		var angle_basis: Basis = Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI)
		var angle: int = _attach(graph, deck, hole, "kit_angle_bracket", "base_2_back", angle_basis)
		var post_basis := Basis(Vector3.UP, PI * 0.5)
		var post: int = _attach(graph, angle, "upright_3_front", "kit_beam_100", "h4_front", post_basis)
		var foot_angle: int = _attach(graph, post, "h0_front", "kit_angle_bracket", "upright_3_back", post_basis)
		var foot: int = _attach(graph, foot_angle, "base_2_back", "kit_plate_80_60", _definition_hole(load(CATALOG + "kit_plate_80_60.tres"), Vector3(0.01, 0.02, 0.002)), FOOT)
		for z: float in [-0.01, 0.03]:
			_attach(graph, foot, _hole(graph, foot, Vector3(z, -0.02, -0.002)), "kit_rubber_pad", "h0_back", pad_basis)
	_add_fasteners(graph)
	return graph


static func _add_fasteners(graph: ConnectionGraph) -> void:
	var joints: Array[Dictionary] = graph.links.duplicate()
	var used: Dictionary = {}
	for link: Dictionary in joints:
		used["%d/%s" % [link.a_part, link.a_port]] = true
		used["%d/%s" % [link.b_part, link.b_port]] = true
	for link: Dictionary in joints:
		var a: PartDef = graph.parts[link.a_part].part_def
		var b: PartDef = graph.parts[link.b_part].part_def
		if not _thin_stock(a.id) or not _thin_stock(b.id):
			continue
		var a_outer: String = _opposite(String(link.a_port))
		var b_outer: String = _opposite(String(link.b_port))
		if a_outer.is_empty() or b_outer.is_empty() or used.has("%d/%s" % [link.a_part, a_outer]) or used.has("%d/%s" % [link.b_part, b_outer]):
			continue
		var a_port: Port = RunMode._port(a, StringName(a_outer))
		var b_port: Port = RunMode._port(b, StringName(b_outer))
		if a_port.tag != &"kit_m4" or b_port.tag != &"kit_m4":
			continue
		var normal: Vector3 = -(graph.parts[link.a_part].transform.basis * a_port.local_normal)
		var basis: Basis = RunMode._basis_with_z(normal)
		_attach(graph, link.a_part, a_outer, "kit_bolt_4", "head_mount", basis)
		_attach(graph, link.b_part, b_outer, "kit_nut_4", "bore_back", basis)
		used["%d/%s" % [link.a_part, a_outer]] = true
		used["%d/%s" % [link.b_part, b_outer]] = true


static func _thin_stock(id: StringName) -> bool:
	return String(id).begins_with("kit_beam_") or String(id).begins_with("kit_plate_") or id in [&"kit_angle_bracket", &"kit_u_bracket_large", &"kit_u_bracket_small"]


static func _opposite(port: String) -> String:
	if port.ends_with("_front"):
		return port.trim_suffix("_front") + "_back"
	if port.ends_with("_back"):
		return port.trim_suffix("_back") + "_front"
	return ""


static func answer_code(graph: ConnectionGraph) -> String:
	var lines: PackedStringArray = ["# Addresses are read from the assembled wiring graph."]
	var wired: Dictionary = Wiring.pin_map(graph)
	var pins: Array = wired.keys()
	pins.sort()
	for pin: int in pins:
		var definition: PartDef = graph.parts[wired[pin].part].part_def
		if definition.actuator_torque_nm > 0.0:
			lines.append("s%d = Servo(%d)" % [pin, pin])
			lines.append("s%d.write_relative(0)" % pin)
	lines.append("sleep(2.0)")
	return "\n".join(lines) + "\n"


static func _add(graph: ConnectionGraph, id: String, position: Vector3, basis: Basis = Basis.IDENTITY) -> int:
	graph.parts.append({"part_def": load(CATALOG + id + ".tres"), "transform": Transform3D(basis, position)})
	return graph.parts.size() - 1


static func _attach(graph: ConnectionGraph, parent: int, parent_port: String, id: String, child_port: String, basis: Basis = Basis.IDENTITY) -> int:
	var definition: PartDef = load(CATALOG + id + ".tres")
	var port: Port = RunMode._port(definition, StringName(child_port))
	var position: Vector3 = _world_port(graph, parent, parent_port) - basis * port.local_position
	var child: int = _add(graph, id, position, basis)
	_link(graph, parent, parent_port, child, child_port)
	return child


static func _world_port(graph: ConnectionGraph, part: int, port: String) -> Vector3:
	return graph.parts[part].transform * RunMode._port(graph.parts[part].part_def, StringName(port)).local_position


static func _hole(graph: ConnectionGraph, part: int, position: Vector3) -> String:
	return _definition_hole(graph.parts[part].part_def, position)


static func _definition_hole(definition: PartDef, position: Vector3) -> String:
	for port: Port in definition.ports:
		if port.kind == Port.Kind.MECH and port.local_position.distance_to(position) < 0.000001:
			return String(port.id)
	assert(false, "No actual mounting hole on %s at %s" % [definition.id, position])
	return ""


static func _wire(graph: ConnectionGraph, motor: int, board: int, pin: int) -> void:
	_link(graph, motor, "signal", board, "pin_%d" % pin)


static func _link(graph: ConnectionGraph, a: int, a_port: String, b: int, b_port: String) -> void:
	graph.links.append({"a_part": a, "a_port": StringName(a_port), "b_part": b, "b_port": StringName(b_port)})
