extends SceneTree

## Exercise the real finite-torque hold without opening the camera or supplying an observation.
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var app: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app._load_preset(RobotCarPreset.build(0.6), RobotCarPreset.BRAKE_CODE, "")
	app.control_source.select(app.CONTROL_CODE)
	app.mode_button.button_pressed = true

	var body: RigidBody3D = app.run_mode.bodies[0]
	var loop: AgentCameraLoop = app.agent_loop
	# Bind the settled physics context directly. begin() still requires a rendered desktop.
	loop._part = 0
	loop._body_id = body.get_instance_id()
	loop._revision = loop.controller.current_revision()
	loop._channels = [app.run_mode.motor_on_pin(0), app.run_mode.motor_on_pin(12)]
	loop.enabled = true
	loop._start_settle()
	if not await _wait_ready(loop):
		_finish(app)
		return
	var start: Vector3 = body.global_position
	for step: int in 3:
		loop._consumed = false
		var action: Dictionary = {"action": "forward", "ticks": 25, "episode_id": loop.episode_id,
			"frame_id": loop.frame_id, "revision": loop._revision, "control_generation": loop.control_generation}
		_check(loop.drive_step(action).get("pending", false), "the bounded forward step was accepted")
		if not await _wait_ready(loop):
			_finish(app)
			return
		loop._start_settle()
		if not await _wait_ready(loop):
			_finish(app)
			return
	_check(body.global_position.x - start.x > 0.03, "the camera car actually drove before the idle hold")

	var before: Vector3 = body.global_position
	for tick: int in 600:
		await physics_frame
	var travel: Vector3 = body.global_position - before
	print("camera_hold_idle_drift_m=", travel.length(), " delta=", travel)
	_check(travel.length() <= 0.002, "camera car drifts at most 2 mm over 10 seconds")
	_check(loop.enabled and loop.state == "ready" and loop.png.is_empty(), "only physics runs in the headless fixture")
	app._on_stop_pressed()
	_check(not loop.enabled and loop._hold_positions.is_empty(), "Stop revokes the hold")
	for motor: DriveMotor in app.run_mode.motors.values():
		_check(motor.duty == 0.0, "Stop restores ordinary zero-duty braking")
	_finish(app)


func _wait_ready(loop: AgentCameraLoop) -> bool:
	for tick: int in 600:
		if loop.state == "ready":
			return true
		if not loop.enabled:
			break
		await physics_frame
	_check(false, "camera car settles within its finite budget")
	return false


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)


func _finish(app: Node3D) -> void:
	app.free()
	print("agent_camera_hold_check: ", _failures, " failures")
	quit(1 if _failures else 0)
