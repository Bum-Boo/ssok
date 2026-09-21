extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 950)
	root.gui_embed_subwindows = true
	var settle_frames: int = 60
	var restart: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--settle-frames="):
			settle_frames = int(argument.get_slice("=", 1))
		elif argument == "--restart":
			restart = true
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_learned_biped_pressed()
	_check(main.motion_program is BundledBipedMotion, "actual starter selects the frozen learned controller")
	_check(main.control_source.selected == main.CONTROL_MANUAL, "starter selects manual forward control")
	var snapshot: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(main.assembly.graph))
	main.mode_button.button_pressed = true
	_check(main.motion_program.is_supported(), "policy accepts the actual application physics and graph")
	_check(main.motion_program.get_status() == BundledBipedMotion.HELP, "learned controller explains its forward-only controls")
	if not main.motion_program.is_supported():
		main.free()
		quit(1)
		return
	for frame: int in settle_frames:
		await physics_frame
	if restart:
		_key(KEY_W, true)
		for frame: int in 180:
			await physics_frame
		_key(KEY_W, false)
		for frame: int in 60:
			await physics_frame
	var body: RigidBody3D = main.run_mode.bodies[main.motion_program.body_part]
	var start: Vector3 = body.global_position
	var initial: Basis = body.global_basis.orthonormalized()
	var minimum_up: float = 1.0
	var minimum_height: float = INF
	_key(KEY_W, true)
	_check(main.manual_controller.get_move_input().y > 0.9, "actual W input reaches the learned controller")
	for frame: int in 720:
		await physics_frame
		minimum_up = minf(minimum_up, body.global_basis.y.dot(Vector3.UP))
		minimum_height = minf(minimum_height, body.global_position.y - BipedPreset.FLOOR_TOP)
		_check(body.global_transform.is_finite(), "learned application trajectory stays finite")
	var displacement: Vector3 = initial.inverse() * (body.global_position - start)
	var yaw: float = initial.z.signed_angle_to(body.global_basis.z, Vector3.UP)
	print("LEARNED_APP settle=%d restart=%s forward=%.5f lateral=%.5f yaw=%.3f min_up=%.4f min_height=%.4f" % [settle_frames, restart, displacement.z, displacement.x, rad_to_deg(yaw), minimum_up, minimum_height])
	_check(displacement.z >= 0.30, "actual app walks at least 30 cm in 12 seconds")
	_check(absf(displacement.x) <= 0.10, "actual app stays within 10 cm lateral drift")
	_check(absf(yaw) <= deg_to_rad(30.0), "actual app stays within 30 degrees heading drift")
	_check(minimum_up >= 0.85 and minimum_height > 0.09, "actual app remains standing throughout walking")
	_key(KEY_W, false)
	for frame: int in 90:
		await physics_frame
	_check(main.motion_program._move_input.is_zero_approx(), "releasing W stops the policy command")
	_check(body.global_basis.y.dot(Vector3.UP) >= 0.9, "robot remains upright after stopping")
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(main.assembly.graph)) == snapshot, "learned walking does not modify the authored assembly")
	main.mode_button.button_pressed = false
	main.assembly.graph.parts[0].transform.origin.x += 0.001
	main.mode_button.button_pressed = true
	_check(not main.motion_program.is_supported(), "edited geometry rejects the bundled policy")
	_check(not main.manual_controller.is_enabled(), "mismatched policy cannot drive motors")
	main.mode_button.button_pressed = false
	main._on_biped_pressed()
	_check(main.motion_program is BipedMotion, "switching back restores the original controller")
	main.free()
	print("learned_app_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
