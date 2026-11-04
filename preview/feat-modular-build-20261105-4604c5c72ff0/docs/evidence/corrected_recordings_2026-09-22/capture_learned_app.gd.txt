extends SceneTree

## Record the actual workshop, keyboard command and physical trajectory at native speed.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.has_feature("movie"):
		push_error("Use the GL renderer with --write-movie and --fixed-fps")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	SsokLocale.select_locale("en", false)
	main._on_learned_biped_pressed()
	main.mode_button.button_pressed = true
	if not main.motion_program.is_supported():
		push_error("Bundled policy rejected the actual workshop")
		quit(1)
		return
	for frame: int in 60:
		await physics_frame
	var body: RigidBody3D = main.run_mode.bodies[main.motion_program.body_part]
	var start: Vector3 = body.global_position
	var basis: Basis = body.global_basis.orthonormalized()
	var heading: Vector3 = BipedMotion._horizontal_forward(basis)
	var right: Vector3 = Vector3.UP.cross(heading)
	var minimum_up: float = 1.0
	var minimum_height: float = INF
	_key(true)
	for frame: int in 720:
		await physics_frame
		minimum_up = minf(minimum_up, body.global_basis.y.dot(Vector3.UP))
		minimum_height = minf(minimum_height, body.global_position.y - BipedPreset.FLOOR_TOP)
	var displacement: Vector3 = body.global_position - start
	var moved: Vector3 = Vector3(displacement.dot(right), displacement.y, displacement.dot(heading))
	var yaw: float = rad_to_deg(heading.signed_angle_to(BipedMotion._horizontal_forward(body.global_basis), Vector3.UP))
	_key(false)
	for frame: int in 90:
		await physics_frame
	var stopped_up: float = body.global_basis.y.dot(Vector3.UP)
	var record: Dictionary = {
		"engine": Engine.get_version_info().string,
		"policy_sha256": FileAccess.get_sha256(BundledBipedMotion.POLICY_PATH),
		"policy_version": int(main.motion_program.policy.version),
		"physics_hz": Engine.physics_ticks_per_second,
		"render_fps": roundi(1.0 / root.get_process_delta_time()),
		"playback_speed": 1.0, "walking_seconds": 12.0,
		"forward_m": moved.z, "lateral_m": moved.x, "yaw_degrees": yaw,
		"minimum_up": minimum_up, "minimum_height_m": minimum_height,
		"stopped_up": stopped_up,
		"graph_fingerprint": MotionSnapshot.fingerprint(MotionSnapshot.encode(main.assembly.graph)),
		"runtime_fingerprint": LearnedBipedMotion.runtime_fingerprint(main.run_mode, main.assembly.graph, int(main.motion_program.policy.version)),
		"success": moved.z >= 0.3 and absf(moved.x) <= 0.1 and absf(yaw) <= 30.0
			and minimum_up >= 0.85 and minimum_height > 0.09 and stopped_up >= 0.9,
	}
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://release_media")
	root.get_texture().get_image().save_png("user://release_media/learned-app.png")
	var output: FileAccess = FileAccess.open("user://release_media/learned-app.metrics.json", FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(JSON.stringify(record, "\t") + "\n")
	print("LEARNED_RECORDING ", JSON.stringify(record))
	main.free()
	quit(0 if record.success else 1)


func _key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	root.push_input(event, true)
