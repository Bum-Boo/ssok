class_name StageEvaluator
extends RefCounted

var stage: Dictionary = {}
var elapsed: float = 0.0
var success: bool = false
var expired: bool = false
var status: String = "idle"
var reason: String = ""
var execution_id: int = 0
var held: Array[float] = []
var measurements: Array[Dictionary] = []
var had_wall_contact: bool = false
var _target_tokens: Dictionary = {}
var _bound_graph: ConnectionGraph


func configure(definition: Dictionary, graph: ConnectionGraph = null) -> bool:
	stage = definition.duplicate(true) if StageDefinition.valid(definition) else {}
	_target_tokens.clear()
	_bound_graph = graph
	reset()
	if graph != null:
		for index: int in stage.get("rules", []).size():
			var rule: Dictionary = stage.rules[index]
			var target: int = int(rule.get("target_index", -1))
			if target >= 0 and target < graph.parts.size():
				if not graph.parts[target].has("stage_target_token"):
					graph.parts[target].stage_target_token = Crypto.new().generate_random_bytes(16).hex_encode()
				_target_tokens[index] = graph.parts[target].stage_target_token
	return not stage.is_empty()


func reset() -> void:
	execution_id += 1
	elapsed = 0.0
	success = false
	expired = false
	status = "idle"
	reason = ""
	had_wall_contact = false
	held.clear()
	measurements.clear()
	for rule: Dictionary in stage.get("rules", []):
		held.append(0.0)


func start(graph: ConnectionGraph) -> bool:
	reset()
	if stage.is_empty():
		return false
	for index: int in stage.rules.size():
		var target: Dictionary = resolve_target(index, graph)
		if target.has("error"):
			finish("indeterminate", target.error)
			return false
	if graph.parts.size() > stage.constraints.max_parts:
		finish("not_met", "part_limit")
		return false
	status = "running"
	return true


func resolve_target(rule_index: int, graph: ConnectionGraph) -> Dictionary:
	if graph == null or rule_index < 0 or rule_index >= stage.rules.size():
		return {"error": "target_missing"}
	var rule: Dictionary = stage.rules[rule_index]
	var selected: int = int(rule.get("target_index", -1))
	if selected >= 0:
		if not _target_tokens.has(rule_index) or graph != _bound_graph:
			return {"error": "target_missing"}
		if selected >= graph.parts.size() or graph.parts[selected].get("stage_target_token", "") != _target_tokens[rule_index]:
			return {"error": "target_changed"}
		if String(graph.parts[selected].part_def.id) != rule.part_id:
			return {"error": "target_changed"}
		return {"index": selected}
	var matches: Array[int] = []
	for index: int in graph.parts.size():
		if String(graph.parts[index].part_def.id) == rule.part_id:
			matches.append(index)
	if matches.is_empty():
		return {"error": "target_missing"}
	if matches.size() > 1:
		return {"error": "target_ambiguous"}
	return {"index": matches[0]}


func finish(outcome: String, cause: String = "", expected_execution: int = -1) -> void:
	if expected_execution >= 0 and expected_execution != execution_id:
		return
	if status in ["success", "not_met", "cancelled", "indeterminate"]:
		return
	status = outcome
	reason = cause
	success = status == "success"
	expired = status == "not_met" and reason == "time_limit"


func observe(run_mode: RunMode, graph: ConnectionGraph, delta: float) -> void:
	if stage.is_empty() or status != "running":
		return
	if not is_instance_valid(run_mode) or not run_mode.is_built() or run_mode.bodies.size() != graph.parts.size():
		finish("indeterminate", "physics_unavailable")
		return
	if not is_finite(delta) or delta <= 0:
		finish("indeterminate", "invalid_time_step")
		return
	elapsed += delta
	if graph.parts.size() > stage.constraints.max_parts:
		finish("not_met", "part_limit")
		return
	if elapsed > stage.constraints.time_limit:
		finish("not_met", "time_limit")
		return
	var all_met: bool = true
	measurements.clear()
	for index: int in stage.rules.size():
		var rule: Dictionary = stage.rules[index]
		var target: Dictionary = resolve_target(index, graph)
		if target.has("error"):
			finish("indeterminate", target.error)
			return
		var sample: Dictionary = measurement(rule.metric, target.index, run_mode)
		if sample.has("error"):
			finish("indeterminate", sample.error)
			return
		var value: Variant = sample.get("value")
		var met: bool = value != null and value >= rule.min and value <= rule.max
		held[index] = held[index] + delta if met else 0.0
		all_met = all_met and met and held[index] + 0.000001 >= rule.hold_seconds
		measurements.append({"metric": rule.metric, "part_index": target.index, "value": value,
			"state": sample.get("state", "valid"), "held_seconds": held[index], "met": met})
	if all_met:
		finish("success")


func measurement(metric: String, part: int, run_mode: RunMode) -> Dictionary:
	if part < 0 or part >= run_mode.bodies.size() or not is_instance_valid(run_mode.bodies[part]):
		return {"error": "physics_unavailable"}
	var body: RigidBody3D = run_mode.bodies[part]
	var pose: Transform3D = run_mode.part_global_transform(part)
	if not pose.origin.is_finite() or not pose.basis.x.is_finite() or not pose.basis.y.is_finite() or not pose.basis.z.is_finite() or not body.linear_velocity.is_finite():
		return {"error": "nonfinite_physics"}
	var value: Variant
	match metric:
		"height": value = (pose * Vector3(0, run_mode._graph.parts[part].part_def.mesh.get_aabb().end.y, 0)).y
		"x": value = pose.origin.x
		"speed": value = body.linear_velocity.length()
		"upright": value = pose.basis.y.dot(Vector3.UP)
		"sonar_distance":
			var sensor: SonarSensor = run_mode.sonar_for_part(part)
			if sensor == null:
				return {"error": "sensor_missing"}
			var distance: float = sensor.distance_cm()
			if sensor.last_state == "unavailable":
				return {"error": "sensor_unavailable"}
			return {"value": distance if sensor.last_valid else null, "state": sensor.last_state}
		"wall_contact":
			for collider: RigidBody3D in run_mode.bodies:
				for contact: Node3D in collider.get_colliding_bodies():
					if contact.name.begins_with("stage_wall"):
						had_wall_contact = true
			value = 1.0 if had_wall_contact else 0.0
		_: return {"error": "unknown_metric"}
	if not is_finite(float(value)):
		return {"error": "nonfinite_physics"}
	return {"value": value, "state": "valid"}


func result() -> Dictionary:
	return {"status": status, "reason": reason, "execution_id": execution_id, "success": success,
		"expired": expired, "elapsed_seconds": elapsed, "measurements": measurements.duplicate(true), "wall_contact": had_wall_contact}
