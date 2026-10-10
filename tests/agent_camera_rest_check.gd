extends SceneTree

## Rendered regression: a ready camera must not keep approaching during model latency.
var app: Node3D
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _ready_camera() -> void:
	for tick: int in 600:
		if app.agent_loop.state == "ready":
			return
		if not app.agent_loop.enabled:
			break
		await physics_frame
	_check(false, "Camera/action settles within its finite budget")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered desktop required")
		quit(1)
		return
	root.size = Vector2i(1600, 1000)
	app = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(app)
	await process_frame
	app._load_preset(RobotCarPreset.build(0.6), RobotCarPreset.BRAKE_CODE, "")
	app.control_source.select(app.CONTROL_CODE)
	app.mode_button.button_pressed = true
	app.agent_loop.begin()
	await _ready_camera()
	var body: RigidBody3D = app.run_mode.bodies[0]
	var start: Vector3 = body.global_position
	for step: int in 3:
		var meta: Dictionary = app.agent_loop.metadata
		app.agent_loop.drive_step({"episode_id": meta.episode_id, "frame_id": meta.frame_id,
			"revision": meta.revision, "control_generation": meta.control_generation,
			"action": "forward", "ticks": 25})
		await _ready_camera()
		app.agent_loop.observe()
		await _ready_camera()
	_check(body.global_position.x - start.x > 0.03, "Idle regression follows real motor-driven travel")
	var before: Vector3 = body.global_position
	for tick: int in 600:
		await physics_frame
	var drift: float = body.global_position.distance_to(before)
	print("idle_drift_m=", drift, " delta=", body.global_position - before)
	_check(app.agent_loop.enabled and app.agent_loop.state == "ready", "Idle camera remains ready without provider/action calls")
	_check(drift <= 0.002, "Ready camera drifts at most 2mm over 10 seconds")
	app._on_stop_pressed()
	_check(not app.agent_loop.enabled, "Local Stop revokes holding ownership")
	for drive: DriveMotor in app.run_mode.motors.values():
		_check(drive.duty == 0.0, "Revocation leaves no active motor duty")
	app.free()
	print("agent_camera_rest_check: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
