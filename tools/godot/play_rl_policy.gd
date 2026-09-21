extends SceneTree

## Playback and inspection use the application's exact learned controller.
## godot --headless --path . --fixed-fps 60 --script tools/godot/play_rl_policy.gd -- --policy policy.json
## Omit --headless and add --window to watch physical playback.

var _hardware: RunMode
var _motion: LearnedBipedMotion
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path: String = _arg("--policy", "")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if not path.is_empty() else null
	if not parsed is Dictionary or not LearnedBipedMotion.validate_policy(parsed).is_empty():
		push_error("Pass --policy with a valid ssok policy JSON file")
		quit(2)
		return
	var policy: Dictionary = parsed
	var robot_id: String = str(policy.get("robot_id", "biped"))
	if robot_id not in ["biped", "yaw_biped"] or Engine.physics_ticks_per_second != 60:
		push_error("Playback requires a supported robot and 60 Hz physics")
		quit(2)
		return
	var visible: bool = OS.get_cmdline_user_args().has("--window")
	root.size = Vector2i(960, 720) if visible else Vector2i(2, 2)
	_add_floor(visible)
	var graph: ConnectionGraph = YawBipedPreset.build() if robot_id == "yaw_biped" else BipedPreset.build()
	_hardware = RunMode.new()
	root.add_child(_hardware)
	_hardware.build(graph)
	_motion = LearnedBipedMotion.new()
	root.add_child(_motion)
	_motion.load_policy(policy)
	if not _motion.configure(_hardware, graph):
		push_error("Policy does not match this graph and runtime")
		quit(2)
		return
	_motion.set_enabled(true)
	var body: RigidBody3D = _hardware.bodies[_motion.body_part]
	if visible:
		_add_camera(body.global_position)
	var settle_seconds: float = clampf(float(_arg("--settle-seconds", "1")), 0.0, 5.0)
	for frame: int in int(60 * settle_seconds):
		await physics_frame
	var seed_value: int = int(_arg("--seed", "2001"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	body.linear_velocity += Vector3(rng.randf_range(-0.003, 0.003), 0, rng.randf_range(-0.003, 0.003))
	var start: Vector3 = body.global_position
	var minimum_upright: float = 1.0
	var fallen: bool = false
	var frames: int = 0
	_motion.set_move_input(Vector2(0, 1))
	for frame: int in 720:
		await physics_frame
		frames += 1
		var upright: float = body.global_basis.y.normalized().dot(Vector3.UP)
		minimum_upright = minf(minimum_upright, upright)
		fallen = upright < 0.5 or body.global_position.y - BipedPreset.FLOOR_TOP < 0.06
		for part: RigidBody3D in _hardware.bodies:
			fallen = fallen or not part.global_transform.is_finite() or not part.linear_velocity.is_finite() or not part.angular_velocity.is_finite()
		if visible:
			_camera.position = body.global_position + Vector3(0.35, 0.18, 0.45)
			_camera.look_at(body.global_position)
		if fallen:
			break
	var moved: Vector3 = body.global_position - start
	var heading: Vector3 = body.global_basis.z
	var yaw: float = rad_to_deg(atan2(heading.x, heading.z))
	var result: Dictionary = {
		"engine": Engine.get_version_info().string, "robot_id": robot_id,
		"policy_sha256": FileAccess.get_sha256(path), "seed": seed_value,
		"forward_m": moved.z, "lateral_m": moved.x, "yaw_deg": yaw,
		"fallen": fallen, "seconds": frames / 60.0, "min_upright": minimum_upright,
		"success": not fallen and frames == 720 and moved.z >= 0.3 and absf(moved.x) <= 0.1 and absf(yaw) <= 30,
		"graph_fingerprint": MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)),
		"runtime_fingerprint": LearnedBipedMotion.runtime_fingerprint(_hardware, graph),
	}
	print("RESULT ", JSON.stringify(result))
	var output: String = _arg("--out", "")
	if not output.is_empty():
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			quit(2)
			return
		file.store_string(JSON.stringify(result, "  "))
	_motion.set_enabled(false)
	_hardware.teardown()
	quit(0)


func _add_floor(visible: bool) -> void:
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 0.1, 10.0)
	collision.shape = box
	floor_body.add_child(collision)
	floor_body.position.y = BipedPreset.FLOOR_TOP - box.size.y * 0.5
	if visible:
		var geometry := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.24, 0.28, 0.32)
		mesh.material = material
		geometry.mesh = mesh
		floor_body.add_child(geometry)
	root.add_child(floor_body)


func _add_camera(target: Vector3) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.06, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	root.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(light)
	_camera = Camera3D.new()
	root.add_child(_camera)
	_camera.position = target + Vector3(0.35, 0.18, 0.45)
	_camera.look_at(target)
	_camera.current = true


func _arg(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
