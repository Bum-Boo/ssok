extends SceneTree

## Rendered regression: a ready camera must not keep approaching during model latency.
## Physics under --fixed-fps is deterministic regardless of frame rate, so the window stays
## small: at 1600x1000 a software renderer draws about 10 frames per second and the 600-tick
## idle window would approach the 60 s decision watchdog instead of measuring the hold.
## Drift reference (same source, 600 idle ticks): Windows GL 1.1753 mm (2026-10-10), Linux
## llvmpipe 2.7669 mm on every repeat (2026-10-31); passive braking 14.7-15.3 mm and the
## rejected P-only hold 5.7-6.0 mm. The 4 mm bound accepts both measured platforms and still
## fails every recorded regression mode.
const DRIFT_LIMIT_M: float = 0.004
const SLOW_FRAME_MS: int = 100
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


func _ready_camera(slow_frames: bool = false) -> void:
	for tick: int in 600:
		if app.agent_loop.state == "ready":
			return
		if not app.agent_loop.enabled:
			break
		if slow_frames:
			# Emulate a ~10 ticks/s software renderer: driving and settling budgets are
			# physics ticks, and a slow wall clock must not cancel a settling robot.
			OS.delay_msec(SLOW_FRAME_MS)
		await physics_frame
	_check(false, "Camera/action settles within its finite budget")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered desktop required")
		quit(1)
		return
	root.size = Vector2i(800, 500)
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
		var started_msec: int = Time.get_ticks_msec()
		var started_tick: int = Engine.get_physics_frames()
		app.agent_loop.drive_step({"episode_id": meta.episode_id, "frame_id": meta.frame_id,
			"revision": meta.revision, "control_generation": meta.control_generation,
			"action": "forward", "ticks": 25})
		await _ready_camera(step == 0)
		var elapsed_msec: int = Time.get_ticks_msec() - started_msec
		print("drive_step ", step, ": ticks=", Engine.get_physics_frames() - started_tick, " wall_ms=", elapsed_msec,
			" state=", app.agent_loop.state)
		if step == 0:
			_check(elapsed_msec > 10000, "Slow-frame drive outlasts the former 10 s wall deadline")
			_check(app.agent_loop.enabled and app.agent_loop.state == "ready",
				"Slow frames do not cancel a physically settled operation")
		app.agent_loop.observe()
		await _ready_camera()
	_check(body.global_position.x - start.x > 0.03, "Idle regression follows real motor-driven travel")
	var before: Vector3 = body.global_position
	for tick: int in 600:
		await physics_frame
	var drift: float = body.global_position.distance_to(before)
	print("idle_drift_m=", drift, " delta=", body.global_position - before)
	_check(app.agent_loop.enabled and app.agent_loop.state == "ready", "Idle camera remains ready without provider/action calls")
	_check(drift <= DRIFT_LIMIT_M, "Ready camera drifts at most 4mm over 10 seconds")
	app._on_stop_pressed()
	_check(not app.agent_loop.enabled, "Local Stop revokes holding ownership")
	for drive: DriveMotor in app.run_mode.motors.values():
		_check(drive.duty == 0.0, "Revocation leaves no active motor duty")
	app.free()
	print("agent_camera_rest_check: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
