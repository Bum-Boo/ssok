class_name LineSensor
extends RefCounted

## 0 = black, 1023 = white on every profile; threshold is 512.
var run_mode: RunMode
var part_index: int = -1
var realistic: bool = false
var noise_seed: int = 1
var _sample: int = 0
var last_valid: bool = false


func value() -> int:
	last_valid = false
	if not is_instance_valid(run_mode) or not run_mode.is_built() or part_index < 0 or part_index >= run_mode.bodies.size():
		return 1023
	var pose: Transform3D = run_mode.part_global_transform(part_index)
	var exclusions: Array[RID] = run_mode.robot_rids(part_index)
	var brightness: float = 0.0
	var space: PhysicsDirectSpaceState3D = run_mode.get_world_3d().direct_space_state
	for offset: float in [-0.003, 0.0, 0.003]:
		var start: Vector3 = pose * Vector3(offset, -0.016, 0)
		var ray := PhysicsRayQueryParameters3D.create(start, start - pose.basis.y * 0.15)
		ray.exclude = exclusions
		ray.collision_mask = 5
		var hit: Dictionary = space.intersect_ray(ray)
		brightness += 1.0 if hit.is_empty() else run_mode.surface_brightness(hit)
		last_valid = last_valid or not hit.is_empty()
	brightness /= 3.0
	if realistic:
		var random := RandomNumberGenerator.new()
		random.seed = noise_seed + _sample
		_sample += 1
		brightness += random.randfn(0.0, 0.01)
	return int(round(clampf(brightness, 0.0, 1.0) * 1023))


func is_dark() -> bool:
	return value() < 512
