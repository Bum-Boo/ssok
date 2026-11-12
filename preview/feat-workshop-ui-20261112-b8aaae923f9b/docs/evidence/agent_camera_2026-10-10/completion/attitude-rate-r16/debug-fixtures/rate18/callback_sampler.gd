extends Node
## DEBUG-r16: read-only actual post-motor physics callback sampler.
var app: Node3D
var rows: Array[Dictionary] = []
var commands: Array[Dictionary] = []
var active: bool = false
var frame_samples: Array[Dictionary] = []

func _ready() -> void:
	process_physics_priority = 100
	app.agent_loop.event_recorded.connect(_event)
	app.agent_loop.frame_ready.connect(_frame)

func _event(event: Dictionary) -> void:
	if event.get("tool") == "drive_step" and event.get("result") == "accepted":
		commands.append({"requested_tick": Engine.get_physics_frames(), "action": event.args.action,
			"ticks": event.args.ticks, "motors": _motors()})
		for motor: DriveMotor in app.agent_loop._channels:
			motor.set("debug_action", commands.size() - 1)
		active = true

func _motors() -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for motor: DriveMotor in app.agent_loop._channels:
		values.append({"duty": motor.duty, "torque_nm": motor.applied_torque_nm,
			"speed_rad_s": motor.measured_rad_s, "priority": motor.process_physics_priority})
	return values

func _physics_process(_delta: float) -> void:
	if not active:
		return
	rows.append({"command_index": commands.size() - 1, "tick": Engine.get_physics_frames(),
		"state": app.agent_loop.state, "remaining": app.agent_loop._remaining,
		"agent_priority": app.agent_loop.process_physics_priority, "motors": _motors()})
	if app.agent_loop.state != "driving":
		for motor: DriveMotor in app.agent_loop._channels:
			motor.set("debug_action", -1)
		active = false

func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

func _frame(_png: PackedByteArray, metadata: Dictionary) -> void:
	var body: RigidBody3D = app.run_mode.bodies[app.agent_loop._part]
	var motor_samples: Array[Dictionary] = []
	for motor: DriveMotor in app.agent_loop._channels:
		var axis: Vector3 = (motor.housing.global_basis * motor.axis_local).normalized()
		motor_samples.append({"axis": _vector(axis), "housing_axis_rate": body.angular_velocity.dot(axis),
			"world_wheel_axis_rate": motor.wheel.angular_velocity.dot(axis),
			"duty": motor.duty, "torque_nm": motor.applied_torque_nm})
	var camera_pose: Transform3D = app.agent_loop._camera.global_transform
	var implied_body: Transform3D = camera_pose * app.agent_loop._mount.affine_inverse()
	frame_samples.append({"sha256": metadata.sha256, "physics_tick": Engine.get_physics_frames(),
		"capture_requested_tick": metadata.capture_requested_tick,
		"callback_body_position": _vector(body.global_position), "callback_body_rotation": _vector(body.global_rotation),
		"callback_body_angular_velocity": _vector(body.angular_velocity),
		"render_assigned_body_position": _vector(implied_body.origin),
		"render_assigned_body_rotation": _vector(implied_body.basis.get_euler()),
		"motors": motor_samples,
		"scope": "Actual assigned camera pose versus later frame_ready body; no claim of identical moments."})
