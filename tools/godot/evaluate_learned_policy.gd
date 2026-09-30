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
	var robot_id: String = str(episode.policy.get("robot_id", "biped"))
	if robot_id not in ["biped", "yaw_biped"]:
		return {"error": "Unknown robot catalog ID"}
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
	var graph: ConnectionGraph = YawBipedPreset.build() if robot_id == "yaw_biped" else BipedPreset.build()
	_hardware.build(graph)
	_motion = LearnedBipedMotion.new()
	_viewport.add_child(_motion)
	_motion.load_policy(episode.policy)
	if not _motion.configure(_hardware, graph):
		_cleanup()
		return {"error": "Policy does not match assembly"}
	_motion.set_enabled(true)
	var settle_seconds: float = clampf(float(episode.get("settle_seconds", 1.0)), 0.0, 5.0)
	for frame: int in int(settle_seconds * 60):
		await physics_frame
	var body: RigidBody3D = _hardware.bodies[_motion.body_part]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var perturbation: float = float(episode.get("initial_velocity_noise", 0.003))
	body.linear_velocity += Vector3(rng.randf_range(-perturbation, perturbation), 0, rng.randf_range(-perturbation, perturbation))
	var warmup_seconds: float = clampf(float(episode.get("warmup_walk_seconds", 0.0)), 0.0, 5.0)
	var restart_pause: float = clampf(float(episode.get("restart_pause_seconds", 1.0)), 0.0, 5.0)
	var preparation_fallen: bool = false
	if warmup_seconds > 0.0:
		_motion.set_move_input(Vector2(0, 1))
		for frame: int in int(warmup_seconds * 60):
			await physics_frame
			preparation_fallen = preparation_fallen or body.global_basis.y.dot(Vector3.UP) < 0.5 or body.global_position.y - BipedPreset.FLOOR_TOP < 0.06
		_motion.set_move_input(Vector2.ZERO)
		for frame: int in int(restart_pause * 60):
			await physics_frame
			preparation_fallen = preparation_fallen or body.global_basis.y.dot(Vector3.UP) < 0.5 or body.global_position.y - BipedPreset.FLOOR_TOP < 0.06
	var start: Vector3 = body.global_position
	var initial_heading := Vector3(body.global_basis.z.x, 0, body.global_basis.z.z).normalized()
	var initial_right: Vector3 = Vector3.UP.cross(initial_heading)
	var minimum_upright: float = 1.0
	var minimum_height: float = body.global_position.y - BipedPreset.FLOOR_TOP
	var fallen: bool = preparation_fallen
	var frames: int = 0
	var reward: float = 0.0
	var feet: Array[int] = []
	var foot_air_frames: Array[int] = []
	var maximum_foot_clearance: Array[float] = []
	for index: int in graph.parts.size():
		var definition: PartDef = graph.parts[index].part_def
		for port: Port in definition.ports:
			if port.id == &"ankle_front":
				feet.append(index)
				foot_air_frames.append(0)
				maximum_foot_clearance.append(0.0)
	var airborne_frames: int = 0
	_motion.set_move_input(Vector2(0, 1))
	for frame: int in int(seconds * 60):
		if preparation_fallen:
			break
		await physics_frame
		frames += 1
		var upright: float = body.global_basis.y.normalized().dot(Vector3.UP)
		minimum_upright = minf(minimum_upright, upright)
		var height: float = body.global_position.y - BipedPreset.FLOOR_TOP
		minimum_height = minf(minimum_height,height)
		var airborne_feet: int = 0
		for index: int in feet.size():
			var clearance: float = _foot_clearance(graph, feet[index])
			maximum_foot_clearance[index] = maxf(maximum_foot_clearance[index], clearance)
			if clearance > 0.0005:
				foot_air_frames[index] += 1
				airborne_feet += 1
		if airborne_feet == 2:
			airborne_frames += 1
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
	var relative_forward: float = moved.dot(initial_heading)
	var relative_lateral: float = moved.dot(initial_right)
	var relative_yaw: float = rad_to_deg(initial_heading.signed_angle_to(Vector3(heading.x, 0, heading.z).normalized(), Vector3.UP))
	var result: Dictionary = {
		"seed": seed_value, "settle_seconds": settle_seconds, "forward_m": moved.z, "lateral_m": moved.x,
		"yaw_deg": yaw, "fallen": fallen, "min_upright": minimum_upright, "minimum_height": minimum_height,
		"seconds": frames / 60.0, "return": reward / 2.0,
		"warmup_walk_seconds": warmup_seconds, "restart_pause_seconds": restart_pause,
		"preparation_fallen": preparation_fallen,
		"relative_forward_m": relative_forward, "relative_lateral_m": relative_lateral, "relative_yaw_deg": relative_yaw,
		"relative_success": not fallen and frames == int(seconds * 60) and relative_forward >= 0.3 and absf(relative_lateral) <= 0.1 and absf(relative_yaw) <= 30,
		"foot_air_frames": foot_air_frames, "maximum_foot_clearance_m": maximum_foot_clearance,
		"both_feet_air_frames": airborne_frames,
		"success": not fallen and frames == int(seconds * 60) and moved.z >= 0.3 and absf(moved.x) <= 0.1 and absf(yaw) <= 30.0,
		"graph_fingerprint": MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)),
		"runtime_fingerprint": LearnedBipedMotion.runtime_fingerprint(_hardware, graph,int(episode.policy.version)),
		"final_observation": Array(_motion.observation()),
		"final_targets": _hardware.servos.values().map(func(drive: ServoDrive) -> float: return drive.current_deg),
	}
	_cleanup()
	await process_frame
	return result


func _foot_clearance(graph: ConnectionGraph, index: int) -> float:
	var definition: PartDef = graph.parts[index].part_def
	var bounds: AABB = definition.mesh.get_aabb()
	var transform: Transform3D = _hardware.part_global_transform(index)
	var minimum_y: float = INF
	for corner: int in 8:
		minimum_y = minf(minimum_y, (transform * bounds.get_endpoint(corner)).y)
	return minimum_y - BipedPreset.FLOOR_TOP


func _cleanup() -> void:
	_motion.set_enabled(false)
	_hardware.teardown()
	root.remove_child(_viewport)
	_viewport.queue_free()


func _arg(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
