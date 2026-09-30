class_name StageEvaluator
extends RefCounted

var stage: Dictionary = {}
var elapsed: float = 0.0
var success: bool = false
var expired: bool = false
var held: Array[float] = []
var measurements: Array[Dictionary] = []
var had_wall_contact: bool = false


func configure(definition: Dictionary) -> bool:
	stage = definition.duplicate(true) if StageDefinition.valid(definition) else {}
	reset()
	return not stage.is_empty()


func reset() -> void:
	elapsed = 0.0
	success = false
	expired = false
	had_wall_contact = false
	held.clear()
	measurements.clear()
	for rule: Dictionary in stage.get("rules", []):
		held.append(0.0)


func observe(run_mode: RunMode, graph: ConnectionGraph, delta: float) -> void:
	if stage.is_empty() or success or expired or not run_mode.is_built():
		return
	elapsed += delta
	expired = elapsed > stage.constraints.time_limit or graph.parts.size() > stage.constraints.max_parts
	if expired:
		return
	var all_met: bool = true
	measurements.clear()
	for index: int in stage.rules.size():
		var rule: Dictionary = stage.rules[index]
		var value: Variant = measurement(rule.metric, rule.part_id, run_mode, graph)
		var met: bool = value != null and is_finite(float(value)) and value >= rule.min and value <= rule.max
		held[index] = held[index] + delta if met else 0.0
		all_met = all_met and met and held[index] + 0.000001 >= rule.hold_seconds
		measurements.append({"metric": rule.metric, "value": value, "held_seconds": held[index], "met": met})
	success = all_met


func measurement(metric: String, part_id: String, run_mode: RunMode, graph: ConnectionGraph) -> Variant:
	var found: int = -1
	for index: int in graph.parts.size():
		if String(graph.parts[index].part_def.id) == part_id:
			found = index
			break
	if found < 0:
		return null
	var body: RigidBody3D = run_mode.bodies[found]
	var pose: Transform3D = run_mode.part_global_transform(found)
	match metric:
		"height":
			return (pose * Vector3(0, graph.parts[found].part_def.mesh.get_aabb().end.y, 0)).y
		"x": return pose.origin.x
		"speed": return body.linear_velocity.length()
		"upright": return pose.basis.y.dot(Vector3.UP)
		"sonar_distance":
			var sensor: SonarSensor = run_mode.sonar_for_part(found)
			if sensor == null:
				return null
			var distance: float = sensor.distance_cm()
			return distance if sensor.last_valid else null
		"wall_contact":
			for collider: RigidBody3D in run_mode.bodies:
				for contact: Node3D in collider.get_colliding_bodies():
					if contact.name.begins_with("stage_wall"):
						had_wall_contact = true
			return 1.0 if had_wall_contact else 0.0
	return null


func result() -> Dictionary:
	return {"success": success, "expired": expired, "elapsed_seconds": elapsed, "measurements": measurements.duplicate(true), "wall_contact": had_wall_contact}
