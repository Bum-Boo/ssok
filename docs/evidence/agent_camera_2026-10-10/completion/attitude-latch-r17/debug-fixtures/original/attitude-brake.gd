extends "res://src/runtime/agent_camera_loop.gd"

## DEBUG-r17: latch actual powered-forward brake-entry attitude; finite graph motors only.
var _observed_attitude: Quaternion = Quaternion()
var _attitude_bound: bool = false
var debug_latches: Array[Dictionary] = []

func _latch_observed_attitude(_png: PackedByteArray, _metadata: Dictionary) -> void:
	_observed_attitude = app.run_mode.bodies[_part].global_basis.get_rotation_quaternion()
	_attitude_bound = true
	debug_latches.append({"reason": "frame_ready", "tick": Engine.get_physics_frames(), "frame_id": frame_id, "rotation": app.run_mode.bodies[_part].global_rotation, "bound": _attitude_bound})

func _invalidate_observed_attitude(event: Dictionary) -> void:
	if event.get("tool") == "drive_step" and event.get("result") == "accepted" and event.args.action == "forward":
		_attitude_bound = false
		debug_latches.append({"reason": "accepted_forward", "tick": Engine.get_physics_frames(), "frame_id": frame_id, "rotation": app.run_mode.bodies[_part].global_rotation, "bound": _attitude_bound})

func _start_settle() -> void:
	if enabled and state == "driving" and _forward_driving and _remaining <= 0:
		_observed_attitude = app.run_mode.bodies[_part].global_basis.get_rotation_quaternion()
		_attitude_bound = true
		debug_latches.append({"reason": "brake_entry", "tick": Engine.get_physics_frames(), "frame_id": frame_id, "rotation": app.run_mode.bodies[_part].global_rotation, "bound": _attitude_bound})
	super._start_settle()

func cancel(reason: String = "local_stop") -> void:
	_attitude_bound = false
	super.cancel(reason)

func _hold_brake(delta: float) -> void:
	# Passive back-EMF braking permits slow roll during model latency. Use bounded
	# wheel-speed and reference-attitude feedback through finite graph motors only.
	if not frame_ready.is_connected(_latch_observed_attitude):
		frame_ready.connect(_latch_observed_attitude)
		event_recorded.connect(_invalidate_observed_attitude)
	var body: RigidBody3D = app.run_mode.bodies[_part]
	var error_vector: Vector3 = Vector3.ZERO
	if _attitude_bound:
		var error: Quaternion = body.global_basis.get_rotation_quaternion() * _observed_attitude.inverse()
		error_vector = Vector3(error.x, error.y, error.z) * (2.0 if error.w >= 0.0 else -2.0)
	for motor: DriveMotor in _channels:
		var axis: Vector3 = (motor.housing.global_basis * motor.axis_local).normalized()
		var speed: float = (motor.wheel.angular_velocity - motor.housing.angular_velocity).dot(axis)
		var integral: float = clampf(float(_hold_integral.get(motor, 0.0)) + speed * delta * HOLD_I, -25.0, 25.0)
		_hold_integral[motor] = integral
		var duty: float = clampf(-speed * HOLD_P - integral + error_vector.dot(axis) * 32.0, -25.0, 25.0)
		motor.motor_on("reverse" if duty < 0.0 else "forward", absf(duty))

