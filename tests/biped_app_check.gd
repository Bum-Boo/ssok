extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var commands: Array[Key] = [KEY_W, KEY_S, KEY_D, KEY_A]
	var settle_frames: int = 60
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--command="):
			commands = [commands[int(argument.get_slice("=", 1))]]
		elif argument.begins_with("--settle-frames="):
			settle_frames = int(argument.get_slice("=", 1))
	for command: Key in commands:
		await _check_command(command, settle_frames)
	print("biped_app_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check_command(command: Key, settle_frames: int) -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_biped_pressed()
	main.mode_button.button_pressed = true
	_check(main.motion_program is BipedMotion and main.motion_program.is_supported(), "actual biped starter has its wired movement program")
	var before: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(main.assembly.graph))
	for frame: int in settle_frames:
		await physics_frame
	var body: RigidBody3D = main.run_mode.bodies[main.motion_program.body_part]
	var origin: Vector3 = body.global_position
	var basis: Basis = body.global_basis.orthonormalized()
	var minimum_height: float = INF
	_key(command, true)
	var direction: Vector2 = main.manual_controller.get_move_input()
	_check(not direction.is_zero_approx(), "actual keyboard input reaches manual control")
	for frame: int in 720:
		await physics_frame
		minimum_height = minf(minimum_height, body.global_position.y - BipedPreset.FLOOR_TOP)
		_check(body.global_transform.is_finite(), "actual app trajectory stays finite")
	_key(command, false)
	for frame: int in 90:
		await physics_frame
	var displacement: Vector3 = basis.inverse() * (body.global_position - origin)
	var yaw: float = Vector3(basis.z.x, 0.0, basis.z.z).normalized().signed_angle_to(Vector3(body.global_basis.z.x, 0.0, body.global_basis.z.z).normalized(), Vector3.UP)
	var up: float = body.global_basis.y.dot(Vector3.UP)
	print("BIPED_APP command=%s settle=%d forward=%.6f lateral=%.6f yaw=%.6f min_height=%.6f stopped_up=%.6f" % [direction, settle_frames, displacement.z, displacement.x, yaw, minimum_height, up])
	_check(minimum_height > 0.09 and up > 0.9, "actual app stays standing and stops upright")
	if absf(direction.y) > 0.5:
		_check(displacement.z * direction.y > 0.001, "actual app translates in the commanded direction")
	else:
		_check(yaw * direction.x > 0.03, "actual app turns in the commanded direction")
	_check(main.motion_program._move_input.is_zero_approx(), "released input clears the movement command")
	for servo: ServoDrive in main.run_mode.servos.values():
		_check(servo.target_deg == 0.0, "released input returns every joint target to neutral")
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(main.assembly.graph)) == before, "manual control does not modify the assembly")
	main.free()
	await physics_frame


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
		push_error(message)
