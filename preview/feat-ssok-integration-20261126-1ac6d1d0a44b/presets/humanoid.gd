class_name HumanoidPreset
extends RefCounted

const CATALOG: String = "res://assets/humanoid/"
const FLOOR_TOP: float = ServoArmPreset.FLOOR_TOP
const LEG_LENGTH: float = 0.24
const HIP_HEIGHT: float = 0.54


static func build() -> ConnectionGraph:
	var graph := ConnectionGraph.new()
	var torso: int = _add(graph, "humanoid_torso", Vector3(0, FLOOR_TOP + HIP_HEIGHT + 0.16, 0))
	var head: int = _add(graph, "humanoid_head", Vector3(0, FLOOR_TOP + HIP_HEIGHT + 0.405, 0))
	var board: int = _add(graph, "humanoid_board", Vector3(0, FLOOR_TOP + HIP_HEIGHT + 0.16, -0.095))
	_link(graph, torso, "neck", head, "mount")
	_link(graph, torso, "board", board, "mount")
	var pin: int = 20
	for side: String in ["left", "right"]:
		var sign_x: float = -1.0 if side == "left" else 1.0
		var thigh: int = _add(graph, "humanoid_thigh", Vector3(sign_x * 0.12, FLOOR_TOP + HIP_HEIGHT - 0.12, 0))
		var shin: int = _add(graph, "humanoid_shin", Vector3(sign_x * 0.12, FLOOR_TOP + HIP_HEIGHT - 0.36, 0))
		var foot: int = _add(graph, "humanoid_foot", Vector3(sign_x * 0.12, FLOOR_TOP + 0.03, 0.035))
		var upper_arm: int = _add(graph, "humanoid_upper_arm", Vector3(sign_x * 0.20, FLOOR_TOP + HIP_HEIGHT + 0.18, 0))
		var forearm: int = _add(graph, "humanoid_forearm", Vector3(sign_x * 0.20, FLOOR_TOP + HIP_HEIGHT - 0.04, 0))
		_link(graph, torso, "hip_" + side, thigh, "pivot")
		_link(graph, thigh, "knee", shin, "pivot")
		_link(graph, shin, "ankle", foot, "pivot")
		_link(graph, torso, "shoulder_" + side, upper_arm, "pivot")
		_link(graph, upper_arm, "elbow", forearm, "pivot")
		for part: int in [thigh, shin, foot, upper_arm, forearm]:
			_link(graph, part, "signal", board, "pin_%d" % pin)
			pin += 1
	_add(graph, "cargo_box", Vector3(0, FLOOR_TOP + 0.10, 0.26))
	return graph


static func _add(graph: ConnectionGraph, id: String, position: Vector3) -> int:
	graph.parts.append({"part_def": load(CATALOG + id + ".tres"), "transform": Transform3D(Basis.IDENTITY, position)})
	return graph.parts.size() - 1


static func _link(graph: ConnectionGraph, a: int, a_port: String, b: int, b_port: String) -> void:
	graph.links.append({"a_part": a, "a_port": StringName(a_port), "b_part": b, "b_port": StringName(b_port)})
