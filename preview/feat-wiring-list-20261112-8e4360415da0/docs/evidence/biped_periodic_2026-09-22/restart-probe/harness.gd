extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _body: RigidBody3D
var _minimum_height: float = INF
var _finite: bool = true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var warmup: int = 60
	var gap: int = 1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--warmup="):
			warmup = int(argument.get_slice("=", 1))
		elif argument.begins_with("--gap="):
			gap = int(argument.get_slice("=", 1))
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_biped_pressed()
	main.mode_button.button_pressed = true
	_check(main.motion_program is BipedMotion and main.motion_program.is_supported(), "actual starter resolves biped program")
	var graph_before: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(main.assembly.graph))
	_body = main.run_mode.bodies[main.motion_program.body_part]
	await _advance(60)
	_key(KEY_W, true)
	_check(main.manual_controller.get_move_input() == Vector2(0, 1), "first W enters manual input")
	await _advance(warmup)
	_key(KEY_W, false)
	_check(main.motion_program._move_input.is_zero_approx(), "short release clears command")
	await _advance(gap)
	var restart_origin: Vector3 = _body.global_position
	var restart_basis: Basis = _body.global_basis.orthonormalized()
	var resumed_tick: int = main.motion_program._forward_ticks
	_key(KEY_W, true)
	_check(main.manual_controller.get_move_input() == Vector2(0, 1), "second W enters manual input")
	var physics_start: int = Engine.get_physics_frames()
	await _advance(720)
	var walk_displacement: Vector3 = restart_basis.inverse() * (_body.global_position - restart_origin)
	var physics_elapsed: int = Engine.get_physics_frames() - physics_start
	_key(KEY_W, false)
	await _advance(90)
	var stop_displacement: Vector3 = restart_basis.inverse() * (_body.global_position - restart_origin)
	var stopped_up: float = _body.global_basis.y.dot(Vector3.UP)
	_check(physics_elapsed == 720, "second W covers720physics frames")
	_check(walk_displacement.z > 0.001, "second W moves forward more than1mm in restart body frame")
	_check(_minimum_height > 0.09, "robot remains above9cm throughout warmup stop restart and final stop")
	_check(_finite, "entire actual trajectory remains finite")
	_check(stopped_up > 0.9, "robot finishes upright after final stop")
	_check(main.motion_program._move_input.is_zero_approx() and main.manual_controller.get_move_input().is_zero_approx(), "final release clears both command owners")
	var targets: Array[float] = []
	for servo: ServoDrive in main.run_mode.servos.values():
		targets.append(servo.target_deg)
		_check(servo.target_deg == 0.0, "final release restores neutral servo target")
	var graph_after: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(main.assembly.graph))
	_check(graph_after == graph_before, "actual input preserves authored graph")
	var result: Dictionary = {"initial_settle_frames":60,"warmup_w_frames":warmup,"release_frames":gap,"second_w_frames":physics_elapsed,"final_release_frames":90,"restart_forward_tick":resumed_tick,"second_forward_m":walk_displacement.z,"second_lateral_m":walk_displacement.x,"after_final_stop_forward_m":stop_displacement.z,"after_final_stop_lateral_m":stop_displacement.x,"minimum_height_m":_minimum_height,"stopped_upright":stopped_up,"finite":_finite,"final_targets":targets,"graph_before":graph_before,"graph_after":graph_after,"program_id":MotionPolicy.PROGRAM_ID,"checks":_checks,"failures":_failures,"passed":_failures==0}
	print("SSOK_RESTART_RESULT=" + JSON.stringify(result))
	main.free()
	await process_frame
	quit(1 if _failures else 0)

func _advance(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		_minimum_height = minf(_minimum_height, _body.global_position.y - BipedPreset.FLOOR_TOP)
		_finite = _finite and _body.global_transform.is_finite() and _body.linear_velocity.is_finite() and _body.angular_velocity.is_finite()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
