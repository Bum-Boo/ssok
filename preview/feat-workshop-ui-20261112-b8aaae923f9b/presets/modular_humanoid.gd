class_name ModularHumanoidPreset
extends RefCounted

const CATALOG: String = "res://assets/modular_humanoid/parts/"


static func build() -> ConnectionGraph:
	var graph := ConnectionGraph.new()
	var torso: int = _add(graph, "modular_torso_frame", Vector3(0, 0.75, 0))
	for entry: Array in [
		["modular_chest_shell", Vector3(0, 0.75, 0), "chest"],
		["modular_pelvis_shell", Vector3(0, 0.63, 0), "pelvis"],
		["modular_head_shell", Vector3(0, 0.995, 0), "neck"],
		["modular_controller", Vector3(0, 0.75, -0.075), "board"]]:
		var child: int = _add(graph, entry[0], entry[1])
		_link(graph, torso, entry[2], child, "mount")
	var board: int = graph.parts.size() - 1
	var pin: int = 20
	for side: String in ["left", "right"]:
		var sign_x: float = -1.0 if side == "left" else 1.0
		var thigh: int = _limb(graph, torso, "hip_" + side, "hip", "modular_thigh_frame", Vector3(sign_x * 0.12, 0.47, 0), board, pin)
		var shin: int = _limb(graph, thigh, "knee", "knee", "modular_shin_frame", Vector3(sign_x * 0.12, 0.23, 0), board, pin + 1)
		_limb(graph, shin, "ankle", "ankle", "modular_foot", Vector3(sign_x * 0.12, 0.08, 0.035), board, pin + 2)
		var upper: int = _limb(graph, torso, "shoulder_" + side, "shoulder", "modular_upper_arm_frame", Vector3(sign_x * 0.20, 0.77, 0), board, pin + 3)
		var forearm: int = _limb(graph, upper, "elbow", "elbow", "modular_forearm_frame", Vector3(sign_x * 0.20, 0.55, 0), board, pin + 4)
		var hand: int = _add(graph, "modular_gripper_hand", Vector3(sign_x * 0.20, 0.47, 0))
		_link(graph, forearm, "hand", hand, "mount")
		pin += 5
	graph.parts.append({"part_def": load(HumanoidPreset.CATALOG + "cargo_box.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0.26))})
	return graph


static func _limb(graph: ConnectionGraph, parent: int, port: String, role: String, frame_id: String, position: Vector3, board: int, pin: int) -> int:
	var definition: PartDef = graph.parts[parent].part_def
	var parent_port: Port = RunMode._port(definition, StringName(port))
	var pivot: Vector3 = graph.parts[parent].transform * parent_port.local_position
	var motor: int = _add(graph, "modular_" + role + "_servo", pivot)
	var bracket: int = _add(graph, "modular_arm_bracket" if role in ["shoulder", "elbow"] else "modular_leg_bracket", pivot)
	var frame: int = _add(graph, frame_id, position)
	_link(graph, parent, port, motor, "mount")
	_link(graph, motor, "output", bracket, "input")
	_link(graph, bracket, "frame", frame, "mount")
	_link(graph, motor, "signal", board, "pin_%d" % pin)
	return frame


static func answer_code(graph: ConnectionGraph) -> String:
	var lines: PackedStringArray = ["# Graph-derived motor addresses; no automatic pickup or learned policy."]
	var wired: Dictionary = Wiring.pin_map(graph)
	var pins: Array = wired.keys()
	pins.sort()
	for pin: int in pins:
		var part: PartDef = graph.parts[wired[pin].part].part_def
		if String(part.id).begins_with("modular_") and part.actuator_torque_nm > 0.0:
			lines.append("s%d = Servo(%d)" % [pin, pin])
	for pin: int in pins:
		var part: PartDef = graph.parts[wired[pin].part].part_def
		var angle: float = 0.0
		match part.id:
			&"modular_hip_servo", &"modular_ankle_servo": angle = -14.36
			&"modular_knee_servo": angle = 28.72
			&"modular_elbow_servo": angle = -12.0
		if String(part.id).begins_with("modular_") and part.actuator_torque_nm > 0.0:
			lines.append("s%d.write_relative(%.2f)" % [pin, angle])
	lines.append("sleep(2.0)")
	return "\n".join(lines) + "\n"


static func _add(graph: ConnectionGraph, id: String, position: Vector3) -> int:
	graph.parts.append({"part_def": load(CATALOG + id + ".tres"), "transform": Transform3D(Basis.IDENTITY, position)})
	return graph.parts.size() - 1


static func _link(graph: ConnectionGraph, a: int, a_port: String, b: int, b_port: String) -> void:
	graph.links.append({"a_part": a, "a_port": StringName(a_port), "b_part": b, "b_port": StringName(b_port)})
