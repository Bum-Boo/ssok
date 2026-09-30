class_name LearnedBipedMotion
extends RobotMotionProgram

## Executes a bounded exported policy. All actuation still goes through graph-wired servos.

const OBSERVATIONS: int = 21
const TRACKING_OBSERVATIONS: int = 24
const ACTIONS: int = 4
const CONTROL_HZ: int = 30

var policy: Dictionary = {}
var body_part: int = -1
var _drives: Array[ServoDrive] = []
var _pairs: Array[Dictionary] = []
var _previous_action: PackedFloat64Array = PackedFloat64Array([0, 0, 0, 0])
var _control_step: int = 0
var _physics_frame: int = 0
var _has_start_frame: bool = false
var _start_position: Vector3 = Vector3.ZERO
var _start_heading: Vector3 = Vector3.BACK
var _start_right: Vector3 = Vector3.RIGHT


func _init() -> void:
	# Keep the measured one-tick motor-command latency independent of scene insertion order.
	process_physics_priority = 10


func load_policy(data: Dictionary) -> bool:
	if not validate_policy(data).is_empty():
		return false
	policy = data.duplicate(true)
	return true


func configure(hardware: RunMode, graph: ConnectionGraph) -> bool:
	super.configure(hardware, graph)
	_drives.clear()
	_pairs.clear()
	body_part = -1
	if not validate_policy(policy).is_empty() or hardware == null or graph == null or not hardware.is_built():
		return false
	if Engine.physics_ticks_per_second != 60:
		return false
	if policy.has("graph_fingerprint") and policy.graph_fingerprint != MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)):
		return false
	if policy.has("runtime_fingerprint") and policy.runtime_fingerprint != runtime_fingerprint(hardware, graph, int(policy.version)):
		return false
	var binding := BipedMotion.new()
	if not binding.configure(hardware, graph):
		binding.free()
		return false
	body_part = binding.body_part
	binding.free()
	for pin: Variant in policy.joint_pins:
		var drive: ServoDrive = hardware.servo_on_pin(int(pin))
		if drive == null:
			return false
		_drives.append(drive)
		var parent: RigidBody3D = hardware.get_node(drive.joint.node_a)
		var child: RigidBody3D = hardware.get_node(drive.joint.node_b)
		var axis: Vector3 = (parent.global_basis.inverse() * drive.joint.global_basis.z).normalized()
		_pairs.append({"parent": parent, "child": child, "axis": axis, "initial": parent.global_basis.inverse() * child.global_basis})
	_supported = true
	return true


func set_enabled(enabled: bool) -> void:
	super.set_enabled(enabled)
	_control_step = 0
	_physics_frame = 0
	_previous_action.fill(0.0)
	_has_start_frame = false
	if _enabled:
		for drive: ServoDrive in _drives:
			drive.write_relative(0.0)


func _physics_process(_delta: float) -> void:
	if not _enabled or not is_instance_valid(_hardware) or not _hardware.is_built():
		return
	if _move_input.y < 0.05:
		_control_step = 0
		_physics_frame = 0
		_previous_action.fill(0.0)
		_has_start_frame = false
		for drive: ServoDrive in _drives:
			drive.write_relative(0.0)
		return
	if not _has_start_frame:
		var body: RigidBody3D = _hardware.bodies[body_part]
		_start_position = body.global_position
		_start_heading = Vector3(body.global_basis.z.x,0,body.global_basis.z.z).normalized()
		_start_right = Vector3.UP.cross(_start_heading)
		_has_start_frame = true
	if _physics_frame % 2 == 0:
		var action: PackedFloat64Array = infer(policy, observation())
		var startup_seconds: float = float(policy.get("startup_seconds", 0.0))
		if startup_seconds > 0.0:
			var strength: float = clampf(float(_control_step) / (CONTROL_HZ * startup_seconds), 0.0, 1.0)
			for index: int in ACTIONS:
				action[index] *= strength
		apply_action(action)
		_control_step += 1
	_physics_frame += 1


func observation() -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for pair: Dictionary in _pairs:
		var parent: RigidBody3D = pair.parent
		var child: RigidBody3D = pair.child
		var relative: Basis = (parent.global_basis.inverse() * child.global_basis).orthonormalized() * pair.initial.inverse()
		var rotation: Quaternion = relative.get_rotation_quaternion()
		result.append(2.0 * atan2(Vector3(rotation.x, rotation.y, rotation.z).dot(pair.axis), rotation.w))
	for pair: Dictionary in _pairs:
		var parent: RigidBody3D = pair.parent
		var child: RigidBody3D = pair.child
		var axis: Vector3 = parent.global_basis * pair.axis
		result.append((child.angular_velocity - parent.angular_velocity).dot(axis) * 0.1)
	result.append_array(_previous_action)
	var body: RigidBody3D = _hardware.bodies[body_part]
	var inverse: Basis = body.global_basis.orthonormalized().inverse()
	var gravity: Vector3 = inverse * Vector3.DOWN
	var angular: Vector3 = inverse * body.angular_velocity * 0.1
	result.append_array([gravity.x, gravity.y, gravity.z, angular.x, angular.y, angular.z, 1.0])
	var phase: float = TAU * float(policy.gait_hz) * _control_step / CONTROL_HZ
	result.append_array([sin(phase), cos(phase)])
	if int(policy.version) == 2:
		var heading: Vector3 = Vector3(body.global_basis.z.x,0,body.global_basis.z.z).normalized()
		result.append_array([(body.global_position - _start_position).dot(_start_right), body.linear_velocity.dot(_start_right), _start_heading.signed_angle_to(heading,Vector3.UP)])
	return result


func apply_action(action: PackedFloat64Array) -> void:
	if action.size() != ACTIONS:
		return
	for index: int in ACTIONS:
		# Godot's ideal hinge target has the opposite sign to child-relative-parent rotation.
		var sign_value: float = float(policy.get("godot_joint_signs", [-1.0, -1.0, -1.0, -1.0])[index])
		_drives[index].write_relative(sign_value * clampf(action[index], -1.0, 1.0) * float(policy.action_scale_deg))
	_previous_action = action.duplicate()


static func infer(data: Dictionary, obs: PackedFloat64Array) -> PackedFloat64Array:
	var action := PackedFloat64Array()
	for row: Array in data.weights:
		var total: float = 0.0
		for index: int in obs.size():
			total += float(row[index]) * (obs[index] - float(data.obs_mean[index])) / sqrt(float(data.obs_var[index]) + 1e-8)
		action.append(tanh(total))
	return action


static func validate_policy(data: Dictionary) -> String:
	if data.get("format") != "ssok-linear-policy" or (data.get("version") != 1 and data.get("version") != 2) or data.get("control_hz") != CONTROL_HZ:
		return "Unsupported policy format"
	var dimensions: int = TRACKING_OBSERVATIONS if int(data.version) == 2 else OBSERVATIONS
	if not _vector(data.get("joint_pins"), ACTIONS, 0.0, 1000.0):
		return "Invalid policy pin mapping"
	var unique: Dictionary = {}
	for pin: Variant in data.joint_pins:
		if float(pin) != floorf(float(pin)) or unique.has(int(pin)):
			return "Invalid policy pin mapping"
		unique[int(pin)] = true
	if not data.get("weights") is Array or data.weights.size() != ACTIONS:
		return "Invalid policy dimensions"
	for row: Variant in data.weights:
		if not _vector(row, dimensions, -10000.0, 10000.0):
			return "Invalid policy weights"
	if not _vector(data.get("obs_mean"), dimensions, -10000.0, 10000.0) or not _vector(data.get("obs_var"), dimensions, 0.0, 1e8):
		return "Invalid observation normalization"
	for key: String in ["action_scale_deg", "gait_hz"]:
		if typeof(data.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[key])):
			return "Invalid policy action bounds"
	if float(data.action_scale_deg) <= 0.0 or float(data.action_scale_deg) > 60.0 or float(data.gait_hz) < 0.1 or float(data.gait_hz) > 3.0:
		return "Invalid policy action bounds"
	if not _vector([data.get("startup_seconds", 0.0)], 1, 0.0, 2.0):
		return "Invalid policy startup duration"
	if data.has("godot_joint_signs"):
		if not _vector(data.godot_joint_signs, ACTIONS, -1.0, 1.0):
			return "Invalid joint signs"
		for sign_value: Variant in data.godot_joint_signs:
			if absf(float(sign_value)) != 1.0:
				return "Invalid joint signs"
	return ""


static func _vector(value: Variant, length: int, low: float, high: float) -> bool:
	if not value is Array or value.size() != length:
		return false
	for item: Variant in value:
		if typeof(item) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(item)) or float(item) < low or float(item) > high:
			return false
	return true


static func runtime_fingerprint(hardware: RunMode, graph: ConnectionGraph, version: int = 1) -> String:
	var properties: Array = []
	for index: int in graph.parts.size():
		var definition: PartDef = graph.parts[index].part_def
		var body: RigidBody3D = hardware.bodies[index]
		var bounds: Array = []
		for child: Node in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				var size: Vector3 = child.shape.size
				var position: Vector3 = child.position
				var basis: Basis = child.basis
				bounds.append([size.x, size.y, size.z, position.x, position.y, position.z,
					basis.x.x, basis.x.y, basis.x.z, basis.y.x, basis.y.y, basis.y.z, basis.z.x, basis.z.y, basis.z.z])
		properties.append([String(definition.id), body.mass, body.freeze, bounds,
			definition.actuator_torque_nm, definition.actuator_min_deg, definition.actuator_max_deg,
			definition.merge_fixed_connections, hardware.bodies.find(body), body.center_of_mass_mode,
			body.center_of_mass.x, body.center_of_mass.y, body.center_of_mass.z,
			body.inertia.x, body.inertia.y, body.inertia.z])
	var actuators: Array = []
	for channel: Dictionary in hardware.wired_servo_channels():
		var drive: ServoDrive = hardware.servo_on_pin(channel.pin)
		actuators.append([channel.pin, drive.torque_limit_nm, drive.speed_deg_per_s,
			drive.velocity_gain, drive.maximum_velocity, drive.relative_min_deg, drive.relative_max_deg])
	var configuration: Array = ["motor-before-policy-v1", MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)),
		Engine.get_version_info().string, Engine.physics_ticks_per_second,
		ProjectSettings.get_setting("physics/3d/default_gravity"),
		ProjectSettings.get_setting("physics/3d/solver/solver_iterations"),
		ProjectSettings.get_setting("physics/3d/solver/contact_max_allowed_penetration"),
		ProjectSettings.get_setting("physics/3d/solver/contact_recycle_radius"),
		ProjectSettings.get_setting("physics/3d/solver/contact_max_separation"), properties, actuators]
	if version == 2:
		configuration[0] = "motor-before-policy-v2-command-start-tracking"
	return JSON.stringify(configuration, "", true, true).sha256_text()
