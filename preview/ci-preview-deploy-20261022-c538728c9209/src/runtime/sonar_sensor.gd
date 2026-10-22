class_name SonarSensor
extends RefCounted

var run_mode: RunMode
var part_index: int = -1
var realistic: bool = false
var noise_seed: int = 1
var _sample: int = 0
var last_state: String = "unavailable"
var last_valid: bool = false
var last_distance_cm: float = 401.0


func distance_cm() -> float:
	last_state = "unavailable"
	last_valid = false
	last_distance_cm = 401.0
	if not is_instance_valid(run_mode) or not run_mode.is_built() or part_index < 0 or part_index >= run_mode.bodies.size():
		return last_distance_cm
	last_state = "out_of_range"
	var pose: Transform3D = run_mode.part_global_transform(part_index)
	var origin: Vector3 = pose * Vector3(0, 0, 0.012)
	var exclusions: Array[RID] = run_mode.robot_rids(part_index)
	var space: PhysicsDirectSpaceState3D = run_mode.get_world_3d().direct_space_state
	var nearest: float = INF
	# Treat the ambiguous 15-degree sheet value as full cone width (7.5-degree half angle).
	var spread: float = tan(deg_to_rad(7.5))
	var directions: Array[Vector3] = [Vector3(0, 0, 1)]
	for index: int in 8:
		var angle: float = index * TAU / 8.0
		directions.append(Vector3(cos(angle) * spread, sin(angle) * spread, 1).normalized())
	for direction: Vector3 in directions:
		var ray := PhysicsRayQueryParameters3D.create(origin, origin + pose.basis * direction * 4.01)
		ray.exclude = exclusions
		ray.collision_mask = 2
		var hit: Dictionary = space.intersect_ray(ray)
		if not hit.is_empty():
			nearest = minf(nearest, origin.distance_to(hit.position) * 100.0)
	if nearest < 2.0 or nearest > 400.0:
		return last_distance_cm
	if realistic:
		var random := RandomNumberGenerator.new()
		random.seed = noise_seed + _sample
		_sample += 1
		nearest = clampf(nearest + random.randfn(0.0, 0.3), 2.0, 400.0)
	last_state = "valid"
	last_valid = true
	last_distance_cm = nearest
	return nearest


func time_pulse_us(timeout_us: int = 1000000) -> int:
	var distance: float = distance_cm()
	if not last_valid:
		return -2
	var pulse: int = int(round(distance * 58.0))
	return pulse if pulse <= timeout_us else -1
