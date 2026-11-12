class_name AgentCameraLoop
extends Node

## Optional virtual sensor on a graph-derived body. No editor camera or scene metrics leave here.
signal state_changed(snapshot: Dictionary)
signal frame_ready(png: PackedByteArray, metadata: Dictionary)
signal event_recorded(event: Dictionary)
signal operation_finished(result: Dictionary)

const MAX_STEP_TICKS: int = 30
const SETTLE_TICKS: int = 12
const SETTLE_LIMIT: int = 240
const DECISION_TIMEOUT_MS: int = 60000
const HOLD_P: float = 8.0
const HOLD_I: float = 16.0
var app: Node3D
var controller: AppController
var enabled: bool = false
var state: String = "disabled"
var control_generation: int = 0
var episode_id: String = ""
var frame_id: int = 0
var metadata: Dictionary = {}
var png: PackedByteArray = PackedByteArray()
var _revision: int = -1
var _part: int = -1
var _body_id: int = 0
var _channels: Array[DriveMotor] = []
var _viewport: SubViewport
var _camera: Camera3D
var _mount: Transform3D = Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(0.075, 0.065, 0))
var _remaining: int = 0
var _stable: int = 0
var _settle_elapsed: int = 0
var _settle_tick: int = 0
var _capture_after_settle: bool = false
var _step_pending: bool = false
var _consumed: bool = true
var _deadline: int = 0
var _hold_integral: Dictionary = {}
var _forward_driving: bool = false


func begin() -> Dictionary:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return {"error": "rendered_desktop_required"}
	cancel("new_session")
	if not app.run_mode.is_built():
		return {"error": "physics_required"}
	_part = -1
	for index: int in app.assembly.graph.parts.size():
		if app.assembly.graph.parts[index].part_def.id == &"car_chassis":
			_part = index
			break
	if _part < 0:
		return {"error": "wired_car_required"}
	_channels.clear()
	var wires: Dictionary = Wiring.pin_map(app.assembly.graph)
	for pin: int in wires:
		var motor: DriveMotor = app.run_mode.motor_on_pin(pin)
		if motor != null and motor not in _channels:
			_channels.append(motor)
	if _channels.size() != 2 or _channels[0].housing != app.run_mode.bodies[_part] or _channels[1].housing != app.run_mode.bodies[_part]:
		return {"error": "wired_car_required"}
	app.runtime.stop()
	app.manual_controller.set_enabled(false)
	app.motion_program.set_enabled(false)
	_revision = controller.current_revision()
	_body_id = app.run_mode.bodies[_part].get_instance_id()
	episode_id = Crypto.new().generate_random_bytes(12).hex_encode()
	enabled = true
	_ensure_camera()
	_brake()
	_capture_after_settle = true
	_start_settle()
	return describe()


func describe() -> Dictionary:
	var supported: bool = false
	if app != null:
		for entry: Dictionary in app.assembly.graph.parts:
			if entry.part_def.id == &"car_chassis":
				supported = true
	return {"enabled": enabled, "state": state, "episode_id": episode_id, "revision": controller.current_revision() if controller != null else 0, "control_generation": control_generation, "frame_id": frame_id, "can_step": enabled and state == "ready" and not _consumed, "robot_supported": supported, "bridge_listening": app.agent_bridge != null and app.agent_bridge.is_listening()}


func observe() -> Dictionary:
	if not enabled:
		return {"error": "agent_disabled"}
	if state != "ready":
		return {"error": "busy"}
	_capture_after_settle = true
	_start_settle()
	return {"pending": true}


func drive_step(args: Dictionary) -> Dictionary:
	for key: Variant in args:
		if key not in ["episode_id", "frame_id", "revision", "control_generation", "ticks", "action"]:
			cancel("invalid_action")
			return {"error": "invalid_action"}
	if not enabled or state != "ready":
		return {"error": "agent_not_ready"}
	if args.get("episode_id") != episode_id or args.get("frame_id") != frame_id or args.get("revision") != _revision or args.get("control_generation") != control_generation or _consumed:
		return {"error": "stale_observation"}
	var ticks: Variant = args.get("ticks")
	if not MotionSnapshot._is_integer(ticks) or ticks < 1 or ticks > MAX_STEP_TICKS or args.get("action") not in ["forward", "brake"]:
		cancel("invalid_action")
		return {"error": "invalid_action"}
	if not _context_valid():
		cancel("context_changed")
		return {"error": "stale_observation"}
	_consumed = true
	_step_pending = true
	_remaining = int(ticks)
	_capture_after_settle = false
	state = "driving"
	_forward_driving = args.action == "forward"
	_hold_integral.clear()
	_deadline = Time.get_ticks_msec() + 10000
	for motor: DriveMotor in _channels:
		if args.action == "forward":
			motor.motor_on("forward", 25.0)
		else:
			motor.stop()
	event_recorded.emit({"tool": "drive_step", "args": args.duplicate(), "result": "accepted", "physics_tick": Engine.get_physics_frames()})
	state_changed.emit(describe())
	return {"pending": true}


func receipt(args: Dictionary) -> Dictionary:
	if not enabled or state != "ready" or not _context_valid() or _consumed or args.get("episode_id") != episode_id or args.get("frame_id") != frame_id or args.get("control_generation") != control_generation or args.get("sha256") != metadata.get("sha256"):
		return {"error": "stale_dispatch"}
	if not args.get("summary", "") is String or str(args.get("summary", "")).length() > 240 or not args.get("provider", "") is String or str(args.get("provider", "")).length() > 80:
		return {"error": "invalid_dispatch"}
	if not MotionSnapshot._is_integer(args.get("max_calls")) or args.max_calls < 1 or args.max_calls > 100:
		return {"error": "invalid_dispatch"}
	event_recorded.emit({"kind": "dispatch", "tool": "trace_dispatch", "summary": args.get("summary", ""), "provider": args.get("provider", ""), "image_sha256": metadata.sha256, "frame_id": frame_id, "result": "hash_matched"})
	_deadline = Time.get_ticks_msec() + DECISION_TIMEOUT_MS
	return {"receipt": "hash_matched", "frame_id": frame_id}


func cancel(reason: String = "local_stop") -> void:
	control_generation += 1
	_brake()
	enabled = false
	_consumed = true
	_remaining = 0
	_capture_after_settle = false
	_step_pending = false
	_hold_integral.clear()
	_forward_driving = false
	state = "stopped" if reason in ["local_stop", "new_session"] else "fault"
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	state_changed.emit(describe())
	event_recorded.emit({"tool": "stop", "args": {"reason": reason}, "result": "braked", "physics_tick": Engine.get_physics_frames()})
	operation_finished.emit({"error": reason})


func _process(_delta: float) -> void:
	if not enabled:
		return
	if not _context_valid():
		cancel("context_changed")
	elif Time.get_ticks_msec() > _deadline:
		cancel("decision_timeout" if state == "ready" else "operation_timeout")


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if not _context_valid():
		cancel("context_changed")
		return
	if state != "driving" or not _forward_driving:
		_hold_brake(delta)
	if state == "driving":
		_remaining -= 1
		if _remaining <= 0:
			_brake()
			_start_settle()
	elif state == "settling":
		_settle_elapsed += 1
		_stable = _stable + 1 if _at_rest() else 0
		if _stable >= SETTLE_TICKS:
			_settle_tick = Engine.get_physics_frames()
			if _capture_after_settle:
				state = "capturing"
				_capture.call_deferred(control_generation)
			else:
				state = "ready"
				_deadline = Time.get_ticks_msec() + DECISION_TIMEOUT_MS
				_step_pending = false
				operation_finished.emit({"state": "ready", "episode_id": episode_id, "frame_id": frame_id, "settle_confirmed_tick": _settle_tick})
			state_changed.emit(describe())
		elif _settle_elapsed >= SETTLE_LIMIT:
			cancel("settle_timeout")


func _start_settle() -> void:
	_brake()
	_stable = 0
	_settle_elapsed = 0
	state = "settling"
	_deadline = Time.get_ticks_msec() + 10000
	state_changed.emit(describe())


func _at_rest() -> bool:
	var body: RigidBody3D = app.run_mode.bodies[_part]
	if body.linear_velocity.length() > 0.001 or body.angular_velocity.length() > 0.1:
		return false
	for motor: DriveMotor in _channels:
		if absf(motor.measured_rad_s) > 0.05:
			return false
	return true


func _context_valid() -> bool:
	return app.run_mode.is_built() and _part >= 0 and _part < app.run_mode.bodies.size() and app.run_mode.bodies[_part].get_instance_id() == _body_id and controller.current_revision() == _revision and not app.runtime.is_running() and not app.manual_controller.is_enabled()


func _brake() -> void:
	if is_instance_valid(app) and is_instance_valid(app.run_mode):
		app.run_mode.stop_motors()


func _hold_brake(delta: float) -> void:
	# Passive back-EMF braking permits slow roll during model latency. Use bounded
	# wheel-speed feedback through the existing motors, never body/scene overrides.
	for motor: DriveMotor in _channels:
		var axis: Vector3 = (motor.housing.global_basis * motor.axis_local).normalized()
		var speed: float = (motor.wheel.angular_velocity - motor.housing.angular_velocity).dot(axis)
		var integral: float = clampf(float(_hold_integral.get(motor, 0.0)) + speed * delta * HOLD_I, -25.0, 25.0)
		_hold_integral[motor] = integral
		var duty: float = clampf(-speed * HOLD_P - integral, -25.0, 25.0)
		motor.motor_on("reverse" if duty < 0.0 else "forward", absf(duty))


func _exit_tree() -> void:
	# Brake even when a coordinator detaches this controller without destroying the robot.
	_brake()
	enabled = false
	control_generation += 1


func _ensure_camera() -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 480)
	_viewport.disable_3d = false
	_viewport.gui_disable_input = true
	_viewport.world_3d = app.get_viewport().world_3d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.near = 0.005
	_camera.far = 20.0
	_camera.fov = 60.0
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_viewport.add_child(_camera)
	_camera.current = true


func _capture(generation: int) -> void:
	if not enabled or generation != control_generation:
		return
	var requested_tick: int = Engine.get_physics_frames()
	_camera.global_transform = app.run_mode.part_global_transform(_part) * _mount
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not enabled or generation != control_generation or not _context_valid():
		return
	if not _at_rest():
		cancel("capture_not_settled")
		return
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		cancel("capture_failed")
		return
	png = image.save_png_to_buffer()
	frame_id += 1
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(png)
	metadata = {"episode_id": episode_id, "robot_instance_id": str(_body_id), "part_id": _part, "camera_id": "virtual-front-camera", "frame_id": frame_id, "revision": _revision, "control_generation": generation, "settle_confirmed_tick": _settle_tick, "capture_requested_tick": requested_tick, "draw_frame": Engine.get_process_frames(), "physics_tick": Engine.get_physics_frames(), "width": image.get_width(), "height": image.get_height(), "sha256": hash.finish().hex_encode(), "interpolation_enabled": bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))}
	_consumed = false
	state = "ready"
	_deadline = Time.get_ticks_msec() + DECISION_TIMEOUT_MS
	frame_ready.emit(png, metadata.duplicate())
	event_recorded.emit({"tool": "observe", "args": {}, "result": {"frame_id": frame_id, "sha256": metadata.sha256}})
	state_changed.emit(describe())
	operation_finished.emit({"metadata": metadata.duplicate(), "png_base64": Marshalls.raw_to_base64(png)})
