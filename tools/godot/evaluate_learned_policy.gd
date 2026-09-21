extends SceneTree

## Offline evaluator: uses the same policy class as the exported web/desktop application.
## godot --headless --path . --fixed-fps 60 --script tools/godot/evaluate_learned_policy.gd -- --input batch.json --output results.json

var _viewport: SubViewport
var _hardware: RunMode
var _motion: LearnedBipedMotion


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(2, 2)
	var input_path: String = _arg("--input", "")
	var output_path: String = _arg("--output", "")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	if not parsed is Dictionary or not parsed.get("episodes") is Array or parsed.episodes.size() > 256:
		push_error("Expected a bounded episodes array")
		quit(2)
		return
	var results: Array[Dictionary] = []
	for episode: Variant in parsed.episodes:
		if not episode is Dictionary or not episode.get("policy") is Dictionary:
			quit(2)
			return
		var result: Dictionary = await _episode(episode)
		results.append(result)
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "episodes": results}, "  "))
	file.close()
	print("EVALUATED ", results.size())
	quit(0)


func _episode(episode: Dictionary) -> Dictionary:
	var validation: String = LearnedBipedMotion.validate_policy(episode.policy)
	if not validation.is_empty():
		return {"error": validation}
	var seconds: float = clampf(float(episode.get("seconds", 12.0)), 1.0, 60.0)
	var seed_value: int = int(episode.get("seed", 0))
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(2, 2)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_viewport)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 0.1, 10.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = BipedPreset.FLOOR_TOP - 0.05
	_viewport.add_child(floor_body)
	_hardware = RunMode.new()
	_viewport.add_child(_hardware)
	var graph: ConnectionGraph = BipedPreset.build()
	_hardware.build(graph)
	_motion = LearnedBipedMotion.new()
	_viewport.add_child(_motion)
	_motion.load_policy(episode.policy)
	if not _motion.configure(_hardware, graph):
		_cleanup()
		return {"error": "Policy does not match assembly"}
	_motion.set_enabled(true)
	for frame: int in 60:
		await physics_frame
	var body: RigidBody3D = _hardware.bodies[_motion.body_part]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var perturbation: float = float(episode.get("initial_velocity_noise", 0.003))
	body.linear_velocity += Vector3(rng.randf_range(-perturbation, perturbation), 0, rng.randf_range(-perturbation, perturbation))
	var start: Vector3 = body.global_position
	var minimum_upright: float = 1.0
	var fallen: bool = false
	var frames: int = 0
	var reward: float = 0.0
	_motion.set_move_input(Vector2(0, 1))
	for frame: int in int(seconds * 60):
		await physics_frame
		frames += 1
		var upright: float = body.global_basis.y.normalized().dot(Vector3.UP)
		minimum_upright = minf(minimum_upright, upright)
		var height: float = body.global_position.y - BipedPreset.FLOOR_TOP
		fallen = upright < 0.5 or height < 0.06 or not body.global_transform.is_finite()
		for part: RigidBody3D in _hardware.bodies:
			if not part.global_transform.is_finite() or not part.linear_velocity.is_finite() or not part.angular_velocity.is_finite():
				fallen = true
		var velocity: Vector3 = body.linear_velocity
		reward += 20.0 * clampf(velocity.z, -0.15, 0.15) + 0.2 + 0.5 * upright - 2.0 * absf(velocity.x) - 0.2 * absf(body.angular_velocity.y)
		if fallen:
			break
	var moved: Vector3 = body.global_position - start
	var heading: Vector3 = body.global_basis.z
	var yaw: float = rad_to_deg(atan2(heading.x, heading.z))
	var result: Dictionary = {
		"seed": seed_value, "forward_m": moved.z, "lateral_m": moved.x,
		"yaw_deg": yaw, "fallen": fallen, "min_upright": minimum_upright,
		"seconds": frames / 60.0, "return": reward / 2.0,
		"success": not fallen and frames == int(seconds * 60) and moved.z >= 0.3 and absf(moved.x) <= 0.1 and absf(yaw) <= 30.0,
		"graph_fingerprint": MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)),
		"runtime_fingerprint": LearnedBipedMotion.runtime_fingerprint(_hardware, graph),
		"final_observation": Array(_motion.observation()),
		"final_targets": _hardware.servos.values().map(func(drive: ServoDrive) -> float: return drive.current_deg),
	}
	_cleanup()
	await process_frame
	return result


func _cleanup() -> void:
	_motion.set_enabled(false)
	_hardware.teardown()
	root.remove_child(_viewport)
	_viewport.queue_free()


func _arg(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
