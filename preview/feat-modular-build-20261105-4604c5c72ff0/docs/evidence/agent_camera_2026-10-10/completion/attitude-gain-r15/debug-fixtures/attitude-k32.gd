extends "res://src/runtime/agent_camera_loop.gd"

## DEBUG-r15: preserve last measured attitude during latency through finite graph motors only.
var _observed_attitude: Quaternion = Quaternion()
var _attitude_bound: bool = false

func _latch_observed_attitude(_png: PackedByteArray, _metadata: Dictionary) -> void:
	_observed_attitude = app.run_mode.bodies[_part].global_basis.get_rotation_quaternion()
	_attitude_bound = true

func _invalidate_observed_attitude(event: Dictionary) -> void:
	if event.get("tool") == "drive_step" and event.get("result") == "accepted" and event.args.action == "forward":
		_attitude_bound = false

func cancel(reason: String = "local_stop") -> void:
	_attitude_bound = false
	super.cancel(reason)

func _hold_brake(delta: float) -> void:
	# Passive back-EMF braking permits slow roll during model latency. Use bounded
	# wheel-speed feedback through the existing motors, never body/scene overrides.
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

