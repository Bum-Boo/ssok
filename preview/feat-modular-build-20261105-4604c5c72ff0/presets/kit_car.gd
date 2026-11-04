class_name KitCarPreset
extends RefCounted

## Every attachment is a real kit hole or rotating wheel shaft in the editable graph.
const FLAT: Basis = Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)


static func build(wall_x: float = 0.0) -> ConnectionGraph:
	var graph := ConnectionGraph.new()
	var deck_basis := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	var deck: int = _add(graph, "kit_plate_220_120", Vector3(0, 0.078, 0), deck_basis)
	var motors: Array[int] = []
	var rails: Array[int] = []
	for side: int in 2:
		var z: float = -0.05 if side == 0 else 0.05
		var rail: int = _attach(graph, deck, _hole(graph, deck, Vector3(-0.1, -z, 0.002)), "kit_beam_140", "h0_back", FLAT)
		rails.append(rail)
		var motor: int = _attach(graph, rail, "h3_front", "tt_motor", "kit_h0_back")
		_link(graph, rail, "h4_front", motor, "kit_h1_back")
		motors.append(motor)
		_attach(graph, motor, "shaft_left" if side == 0 else "shaft_right", "kit_wheel_90", "hub", Basis(Vector3.UP, PI) if side == 0 else Basis.IDENTITY)
	var board_rail: int = _attach(graph, rails[0], "h2_front", "kit_beam_100", "h4_back", deck_basis)
	var driver_rail: int = _attach(graph, rails[1], "h6_front", "kit_beam_100", "h0_back", deck_basis)
	var board: int = _attach(graph, board_rail, "h2_front", "microbit", "kit_h0_back")
	var driver: int = _attach(graph, driver_rail, "h2_front", "motor_driver", "kit_h0_back")
	var caster_spacer: int = _attach(graph, deck, _hole(graph, deck, Vector3(0.1, 0.01, -0.002)), "kit_spacer_20", "bore_front", deck_basis)
	_attach(graph, caster_spacer, "bore_back", "ball_caster", "kit_h1_front")
	var bracket: int = _attach(graph, deck, _hole(graph, deck, Vector3(0.1, -0.01, 0.002)), "kit_angle_bracket", "base_2_back", Basis(Vector3.UP, PI / 2.0))
	var sonar: int = _attach(graph, bracket, "upright_3_front", "hc_sr04", "kit_h0_back", Basis(Vector3.UP, PI / 2.0))
	for pin: int in [0, 8, 12, 16]:
		_link(graph, board, "pin_%d" % pin, driver, "input_%d" % pin)
	_link(graph, driver, "motor_1", motors[0], "power")
	_link(graph, driver, "motor_2", motors[1], "power")
	_link(graph, board, "pin_1", sonar, "trig_pin")
	_link(graph, board, "pin_2", sonar, "echo_pin")
	# Begin above the table so the offset caster settles without initial penetration.
	for part: Dictionary in graph.parts:
		part.transform.origin.y += 0.02
	if wall_x > 0:
		_add(graph, "stage_wall", Vector3(wall_x, 0.15, 0))
	return graph


static func _add(graph: ConnectionGraph, id: String, origin: Vector3, basis: Basis = Basis.IDENTITY) -> int:
	var path: String = "res://assets/construction_kit/parts/" if id.begins_with("kit_") else "res://assets/parts/"
	graph.parts.append({"part_def": load(path + id + ".tres"), "transform": Transform3D(basis, origin)})
	return graph.parts.size() - 1


static func _attach(graph: ConnectionGraph, parent: int, parent_port: String, id: String, child_port: String, basis: Basis = Basis.IDENTITY) -> int:
	var child: int = _add(graph, id, Vector3.ZERO, basis)
	var anchor: Vector3 = graph.parts[parent].transform * RunMode._port(graph.parts[parent].part_def, StringName(parent_port)).local_position
	var local: Vector3 = RunMode._port(graph.parts[child].part_def, StringName(child_port)).local_position
	graph.parts[child].transform.origin = anchor - basis * local
	_link(graph, parent, parent_port, child, child_port)
	return child


static func _hole(graph: ConnectionGraph, part: int, local: Vector3) -> String:
	for port: Port in graph.parts[part].part_def.ports:
		if port.tag == &"kit_m4" and port.local_position.distance_to(local) < 0.0001:
			return String(port.id)
	push_error("No kit hole at %s on %s" % [local, graph.parts[part].part_def.id])
	return ""


static func _link(graph: ConnectionGraph, a: int, a_port: String, b: int, b_port: String) -> void:
	graph.links.append({"a_part": a, "a_port": StringName(a_port), "b_part": b, "b_port": StringName(b_port)})
