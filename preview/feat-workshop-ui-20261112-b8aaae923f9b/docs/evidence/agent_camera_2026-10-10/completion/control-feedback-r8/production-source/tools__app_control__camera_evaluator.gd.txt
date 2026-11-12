extends Node

## Developer-only observer. Metrics stay in user:// and never enter the agent bridge.
var app: Node3D
var robot: Array[RigidBody3D] = []
var wall: RigidBody3D
var started: bool = false
var finished: bool = false
var wall_contact: bool = false
var initial: Dictionary = {}
var minimum_gap: float = INF
var rest_ticks: int = 0
var stopped_ticks: int = 0
var samples: int = 0
var invalid: bool = false
var _last_state: String = ""
var _last_frame: int = -1
var _last_record_tick: int = 0


func _ready() -> void:
	process_physics_priority = 100
	for index: int in app.run_mode.bodies.size():
		var body: RigidBody3D = app.run_mode.bodies[index]
		if app.assembly.graph.parts[index].part_def.resource_path.get_file().get_basename() == "stage_wall":
			wall = body
		elif not robot.has(body):
			robot.append(body)
	for body: RigidBody3D in robot:
		body.max_contacts_reported = 64
		body.contact_monitor = true
		body.body_entered.connect(_on_body_entered)
	if wall == null or robot.is_empty():
		invalid = true
	else:
		app.agent_loop.frame_ready.connect(_record_frame)


func _record_frame(_png: PackedByteArray, meta: Dictionary) -> void:
	_record_sample("camera", meta)


func _record_sample(reason: String, meta: Dictionary = {}) -> void:
	var sample: Dictionary = _snapshot()
	sample.merge({"reason": reason, "physics_tick": Engine.get_physics_frames(),
		"state": app.agent_loop.state, "frame_id": app.agent_loop.frame_id,
		"capture_metadata": meta})
	var file: FileAccess = FileAccess.open("user://camera-calibration.jsonl", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://camera-calibration.jsonl", FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(JSON.stringify(sample))
	_last_record_tick = Engine.get_physics_frames()


func _on_body_entered(body: Node) -> void:
	if body == wall:
		wall_contact = true


func _x_bounds(body: RigidBody3D) -> Vector2:
	var bounds: Vector2 = Vector2(INF, -INF)
	for child: Node in body.get_children():
		if not child is CollisionShape3D or child.disabled:
			continue
		var shape: Shape3D = child.shape
		var transform: Transform3D = child.global_transform
		var extent: float = 0.0
		if shape is BoxShape3D:
			var half: Vector3 = shape.size * 0.5
			extent = absf(transform.basis.x.x) * half.x + absf(transform.basis.y.x) * half.y + absf(transform.basis.z.x) * half.z
		elif shape is SphereShape3D:
			extent = shape.radius * Vector3(transform.basis.x.x, transform.basis.y.x, transform.basis.z.x).length()
		elif shape is CylinderShape3D:
			extent = absf(transform.basis.y.x) * shape.height * 0.5 + shape.radius * sqrt(transform.basis.x.x * transform.basis.x.x + transform.basis.z.x * transform.basis.z.x)
		else:
			invalid = true
			continue
		bounds.x = minf(bounds.x, transform.origin.x - extent)
		bounds.y = maxf(bounds.y, transform.origin.x + extent)
	return bounds


func _snapshot() -> Dictionary:
	var front_x: float = -INF
	for body: RigidBody3D in robot:
		front_x = maxf(front_x, _x_bounds(body).y)
		for other: Node3D in body.get_colliding_bodies():
			if other == wall:
				wall_contact = true
	var chassis: RigidBody3D = app.run_mode.bodies[0]
	var wheel_speed: float = maxf(app.run_mode.bodies[3].angular_velocity.length(), app.run_mode.bodies[4].angular_velocity.length())
	var motor_values: Array = []
	for motor: DriveMotor in app.run_mode.motors.values():
		motor_values.append({"speed": motor.measured_rad_s, "duty": motor.duty})
	return {"x": chassis.global_position.x, "gap_x": _x_bounds(wall).x - front_x,
		"linear_speed": chassis.linear_velocity.length(), "angular_speed": chassis.angular_velocity.length(), "wheel_speed": wheel_speed,
		"position": [chassis.global_position.x, chassis.global_position.y, chassis.global_position.z],
		"rotation": [chassis.rotation.x, chassis.rotation.y, chassis.rotation.z],
		"linear_velocity": [chassis.linear_velocity.x, chassis.linear_velocity.y, chassis.linear_velocity.z],
		"motors": motor_values}


func _physics_process(_delta: float) -> void:
	if finished or invalid:
		return
	if not started:
		if app.agent_loop.state != "ready":
			return
		initial = _snapshot()
		started = true
	var current: Dictionary = _snapshot()
	if _last_state != app.agent_loop.state or _last_frame != app.agent_loop.frame_id or (app.agent_loop.state == "ready" and Engine.get_physics_frames() - _last_record_tick >= 60):
		_record_sample("state_or_idle")
		_last_state = app.agent_loop.state
		_last_frame = app.agent_loop.frame_id
	samples += 1
	minimum_gap = minf(minimum_gap, current.gap_x)
	var resting: bool = current.linear_speed <= 0.015 and current.angular_speed <= 0.1 and current.wheel_speed <= 0.5
	rest_ticks = rest_ticks + 1 if resting else 0
	if not app.agent_loop.enabled:
		stopped_ticks += 1
		if (stopped_ticks >= 30 and rest_ticks >= 12) or stopped_ticks >= 120:
			finished = true
			var result: Dictionary = {"schema": 1, "valid": not invalid, "initial": initial, "final": current,
				"travel_x": current.x - initial.x, "minimum_gap_x": minimum_gap, "wall_contact": wall_contact,
				"rest_ticks": rest_ticks, "samples": samples, "stopped_state": app.agent_loop.state,
				"gap_definition": "world-X support gap of actual collision primitives; valid for the fixed X-normal wall fixture"}
			var file: FileAccess = FileAccess.open("user://camera-evaluation.json", FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(result, "\t") + "\n")
