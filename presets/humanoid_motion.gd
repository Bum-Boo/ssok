class_name HumanoidMotion
extends RobotMotionProgram

signal pickup_contact_confirmed

var role_pins: Dictionary = {}
var role_parts: Dictionary = {}
var body_part: int = -1
var elapsed: float = 0.0
var running: bool = false
var fallen: bool = false
var cycle_seconds: float = 1.4
var stride_m: float = 0.055
var lift_m: float = 0.018
var stance_height: float = 0.465
var balance_gain: float = 1.0
var lean_degrees: float = 3.0
var run_bounce: float = 0.04
var run_period: float = 0.85
var run_stride_m: float = 0.038
var run_swing_height: float = 0.022
var run_stride_phase: float = -0.383
var run_lean_degrees: float = 2.0
var run_speed_mps: float = 0.12
var run_support_position_gain: float = 9.58
var run_support_velocity_gain: float = 1.742
var grasped: bool = false
var pickup_state: String = "idle"
var pickup_policy: Dictionary = {
	"crouch_height": 0.20, "torso_lean_deg": 25.0, "reach_seconds": 2.0,
	"lift_seconds": 2.5, "hand_height_offset": 0.075,
	"hold_shoulder_deg": -35.0, "hold_elbow_deg": -60.0,
}
var _pickup_time: float = 0.0
var _box_part: int = -1
var _grips: Array[PinJoint3D] = []
var _drives: Dictionary = {}
var _speed: float = 0.0
var _run_bodies: Array[RigidBody3D] = []


func configure(hardware: RunMode, graph: ConnectionGraph) -> bool:
	super.configure(hardware, graph)
	role_pins.clear()
	role_parts.clear()
	_drives.clear()
	body_part = -1
	fallen = false
	_box_part = -1
	_set_status("Humanoid needs all ten joints and unambiguous wiring. Reload the humanoid preset to reset.")
	if hardware == null or graph == null or not hardware.is_built() or hardware._graph != graph:
		return false
	for index: int in range(graph.parts.size()):
		if graph.parts[index].part_def.id == &"cargo_box":
			_box_part = index
		if graph.parts[index].part_def.id in [&"humanoid_torso", &"modular_torso_frame"]:
			if body_part >= 0:
				return false
			body_part = index
	if body_part < 0:
		return false
	var modular: bool = graph.parts[body_part].part_def.id == &"modular_torso_frame"
	for side: String in ["left", "right"]:
		if modular:
			if not _configure_modular_side(hardware, side):
				return false
			continue
		var hip: int = _neighbor(body_part, "hip_" + side)
		var knee: int = _neighbor(hip, "knee")
		var ankle: int = _neighbor(knee, "ankle")
		var shoulder: int = _neighbor(body_part, "shoulder_" + side)
		var elbow: int = _neighbor(shoulder, "elbow")
		var parts: Array[int] = [hip, knee, ankle, shoulder, elbow]
		var roles: Array[String] = ["hip", "knee", "ankle", "shoulder", "elbow"]
		var definitions: Array[StringName] = [&"humanoid_thigh", &"humanoid_shin", &"humanoid_foot", &"humanoid_upper_arm", &"humanoid_forearm"]
		for i: int in range(parts.size()):
			if parts[i] < 0 or graph.parts[parts[i]].part_def.id != definitions[i]:
				return false
			var role: String = side + "_" + roles[i]
			role_parts[role] = parts[i]
			for channel: Dictionary in hardware.wired_servo_channels():
				if channel.part == parts[i]:
					if role_pins.has(role):
						return false
					role_pins[role] = channel.pin
	if role_pins.size() != 10:
		return false
	var unique_parts: Dictionary = {}
	for part: int in role_parts.values():
		unique_parts[part] = true
	if unique_parts.size() != 10:
		return false
	for role: String in role_pins:
		_drives[role] = hardware.servo_on_pin(role_pins[role])
	for side: String in ["left", "right"]:
		var foot: RigidBody3D = hardware.bodies[role_parts[side + "_ankle"]]
		foot.contact_monitor = true
		foot.max_contacts_reported = 8
		var hand: RigidBody3D = hardware.bodies[role_parts[side + "_elbow"]]
		hand.contact_monitor = true
		hand.max_contacts_reported = 8
	_supported = true
	_set_status("Experimental humanoid: torque-controlled joints")
	return true


func _configure_modular_side(hardware: RunMode, side: String) -> bool:
	var previous: int = body_part
	for role: String in ["hip", "knee", "ankle", "shoulder", "elbow"]:
		if role == "shoulder":
			previous = body_part
		var mount: String = role + "_" + side if role in ["hip", "shoulder"] else role
		var motor: int = _neighbor(previous, mount)
		if motor < 0 or _graph.parts[motor].part_def.id != StringName("modular_" + role + "_servo"):
			return false
		var bracket: int = _neighbor(motor, "output")
		var bracket_id: StringName = &"modular_arm_bracket" if role in ["shoulder", "elbow"] else &"modular_leg_bracket"
		if bracket < 0 or _graph.parts[bracket].part_def.id != bracket_id:
			return false
		var frame: int = _neighbor(bracket, "frame")
		var frame_ids: Dictionary = {"hip": &"modular_thigh_frame", "knee": &"modular_shin_frame", "ankle": &"modular_foot",
			"shoulder": &"modular_upper_arm_frame", "elbow": &"modular_forearm_frame"}
		if frame < 0 or _graph.parts[frame].part_def.id != frame_ids[role]:
			return false
		if role == "elbow":
			var hand: int = _neighbor(frame, "hand")
			if hand < 0 or _graph.parts[hand].part_def.id != &"modular_gripper_hand":
				return false
		var key: String = side + "_" + role
		role_parts[key] = frame
		for channel: Dictionary in hardware.wired_servo_channels():
			if channel.part == motor:
				if role_pins.has(key):
					return false
				role_pins[key] = channel.pin
		previous = frame
	return true


func set_enabled(enabled: bool) -> void:
	if not enabled:
		_run_bodies.clear()
		release_box()
		pickup_state = "idle"
		running = false
	super.set_enabled(enabled)
	elapsed = 0.0
	_speed = 0.0
	if _enabled:
		_pose(0.0)


func _exit_tree() -> void:
	release_box()


func _physics_process(delta: float) -> void:
	if not _enabled or not _hardware.is_built():
		return
	var torso: RigidBody3D = _hardware.bodies[body_part]
	if torso.global_basis.y.dot(Vector3.UP) < 0.45 or torso.global_position.y < HumanoidPreset.FLOOR_TOP + 0.30:
		fallen = true
		_supported = false
		set_enabled(false)
		_set_status("Humanoid fell. Return to edit mode to reset.")
		return
	if pickup_state in ["reaching", "lifting"]:
		_pickup_time += delta
		_pickup_pose()
		return
	_speed = move_toward(_speed, _move_input.y, delta * 1.2)
	elapsed += delta * absf(_speed)
	_pose(TAU * elapsed / (0.7 if running else cycle_seconds))


func _pose(phase: float) -> void:
	_motor_response(running)
	if running and absf(_speed) > 0.1:
		_run_pose()
		return
	for side: String in ["left", "right"]:
		var leg_phase: float = phase + (PI if side == "right" else 0.0)
		var swing: float = sin(leg_phase)
		var z: float = -stride_m * cos(leg_phase) * _speed
		var height: float = stance_height - lift_m * maxf(swing, 0.0) * absf(_speed)
		var bend: float = acos(clampf((height * height + z * z - 2.0 * 0.24 * 0.24) / (2.0 * 0.24 * 0.24), -1.0, 1.0))
		var hip: float = atan2(-z, height) - bend * 0.5
		var knee: float = bend
		var ankle: float = -hip - knee
		ankle -= deg_to_rad(lean_degrees) * _speed * (1.8 if _speed < 0.0 else 1.0)
		ankle += _balance_correction()
		_write(side + "_hip", rad_to_deg(hip))
		_write(side + "_knee", rad_to_deg(knee))
		_write(side + "_ankle", rad_to_deg(ankle))
		_write(side + "_shoulder", float(pickup_policy.hold_shoulder_deg) if grasped else 15.0 * cos(leg_phase) * _speed)
		_write(side + "_elbow", float(pickup_policy.hold_elbow_deg) if grasped else -12.0)


func _run_pose() -> void:
	var phase: float = TAU * elapsed / run_period
	var support_feedback: float = _running_balance_correction()
	var blend: float = smoothstep(0.1, 0.95, absf(_speed))
	for side: String in ["left", "right"]:
		var leg_phase: float = phase + (PI if side == "right" else 0.0)
		var wave: float = sin(leg_phase)
		var z: float = -run_stride_m * cos(leg_phase + run_stride_phase) * _speed
		var height: float = lerpf(stance_height, 0.445 + run_bounce * cos(2.0 * phase) - run_swing_height * maxf(wave, 0.0), blend)
		var bend: float = acos(clampf((height * height + z * z - 2.0 * 0.24 * 0.24) / (2.0 * 0.24 * 0.24), -1.0, 1.0))
		var hip: float = atan2(-z, height) - bend * 0.5
		_write(side + "_hip", rad_to_deg(hip))
		_write(side + "_knee", rad_to_deg(bend))
		_write(side + "_ankle", rad_to_deg(-hip - bend + support_feedback) - run_lean_degrees * _speed)
		_write(side + "_shoulder", 0.0)
		_write(side + "_elbow", lerpf(-12.0, -45.0, blend))


func _running_balance_correction() -> float:
	if _run_bodies.is_empty():
		_cache_run_bodies()
	var center: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var mass: float = 0.0
	for body: RigidBody3D in _run_bodies:
		center += _physical_mass_center(body) * body.mass
		velocity += body.linear_velocity * body.mass
		mass += body.mass
	center /= mass
	velocity /= mass
	var support: Vector3 = Vector3.ZERO
	for side: String in ["left", "right"]:
		var foot: RigidBody3D = _hardware.bodies[role_parts[side + "_ankle"]]
		support += _physical_mass_center(foot) * 0.5
	var torso: RigidBody3D = _hardware.bodies[body_part]
	var forward: Vector3 = torso.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	return clampf((center - support).dot(forward) * run_support_position_gain
		+ (velocity.dot(forward) - run_speed_mps * _speed) * run_support_velocity_gain
		+ torso.angular_velocity.dot(torso.global_basis.x) * 0.1, -0.6, 0.6)


func _physical_mass_center(body: RigidBody3D) -> Vector3:
	# AUTO bodies retain zero in the custom property even when compound shapes move their COM.
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	return body.to_global(state.center_of_mass_local if state != null else body.center_of_mass)


func _cache_run_bodies() -> void:
	var connected: Dictionary = {body_part: true}
	var pending: Array[int] = [body_part]
	while not pending.is_empty():
		var current: int = pending.pop_back()
		for link: Dictionary in _graph.links:
			if link.a_part != current and link.b_part != current:
				continue
			var definition: PartDef = _graph.parts[link.a_part].part_def
			var mechanical: bool = false
			for port: Port in definition.ports:
				if port.id == link.a_port:
					mechanical = port.kind == Port.Kind.MECH
					break
			var other: int = link.b_part if link.a_part == current else link.a_part
			if mechanical and not connected.has(other):
				connected[other] = true
				pending.append(other)
	var seen: Dictionary = {}
	for index: int in _hardware.bodies.size():
		var body: RigidBody3D = _hardware.bodies[index]
		if connected.has(index) and not seen.has(body):
			seen[body] = true
			_run_bodies.append(body)


func request_pickup() -> bool:
	if not _enabled or _box_part < 0 or pickup_state != "idle":
		return false
	var body: RigidBody3D = _hardware.bodies[body_part]
	var box: RigidBody3D = _hardware.bodies[_box_part]
	var relative: Vector3 = body.global_basis.inverse() * (box.global_position - body.global_position)
	if absf(relative.x) > 0.08 or relative.z < 0.12 or relative.z > 0.40:
		_set_status("Move closer and face the box before picking it up.")
		return false
	pickup_state = "reaching"
	_pickup_time = 0.0
	_speed = 0.0
	_move_input = Vector2.ZERO
	running = false
	_motor_response(false)
	return true


func release_box() -> void:
	for grip: PinJoint3D in _grips:
		if is_instance_valid(grip):
			grip.get_parent().remove_child(grip)
			grip.queue_free()
	_grips.clear()
	grasped = false
	pickup_state = "idle"


func _pickup_pose() -> void:
	var crouch: float = float(pickup_policy.crouch_height)
	var reach_seconds: float = float(pickup_policy.reach_seconds)
	var lift_seconds: float = float(pickup_policy.lift_seconds)
	var target_lean: float = deg_to_rad(float(pickup_policy.torso_lean_deg))
	var height: float = lerpf(stance_height, crouch, smoothstep(0.0, reach_seconds, _pickup_time))
	var lean: float = target_lean * smoothstep(0.0, reach_seconds, _pickup_time)
	if pickup_state == "lifting":
		height = lerpf(crouch, stance_height, smoothstep(0.0, lift_seconds, _pickup_time))
		lean = target_lean * (1.0 - smoothstep(0.0, lift_seconds, _pickup_time))
	var bend: float = 2.0 * acos(clampf(height / 0.48, 0.0, 1.0))
	for side: String in ["left", "right"]:
		_write(side + "_hip", -rad_to_deg(bend) * 0.5 - rad_to_deg(lean))
		_write(side + "_knee", rad_to_deg(bend))
		_write(side + "_ankle", -rad_to_deg(bend) * 0.5 + rad_to_deg(_balance_correction(lean)))
		if pickup_state == "lifting":
			_write(side + "_shoulder", float(pickup_policy.hold_shoulder_deg))
			_write(side + "_elbow", float(pickup_policy.hold_elbow_deg))
		else:
			var box: RigidBody3D = _hardware.bodies[_box_part]
			var target: Vector3 = box.global_position + Vector3(0, float(pickup_policy.hand_height_offset), 0)
			var angles: Array[float] = _reach_angles(side, target)
			_write(side + "_shoulder", rad_to_deg(angles[0]))
			_write(side + "_elbow", rad_to_deg(angles[1]))
	if pickup_state == "reaching" and _pickup_time > reach_seconds:
		_try_grasp()
		if not grasped and _pickup_time > reach_seconds + 5.0:
			pickup_state = "idle"
			_set_status("Could not reach the box. Reset and move closer.")
	elif pickup_state == "lifting" and _pickup_time >= lift_seconds:
		pickup_state = "holding"
		_set_status("Box held. E releases it; Stop also releases the grip.")


func set_sprint_requested(pressed: bool) -> void:
	if not _enabled:
		return
	running = pressed and not grasped and pickup_state == "idle"


func interact() -> void:
	if not _enabled:
		return
	if grasped:
		release_box()
		_set_status("Box released under gravity.")
	else:
		request_pickup()


func _try_grasp() -> void:
	var box: RigidBody3D = _hardware.bodies[_box_part]
	for side: String in ["left", "right"]:
		var hand: RigidBody3D = _hardware.bodies[role_parts[side + "_elbow"]]
		if box not in hand.get_colliding_bodies():
			return
	pickup_contact_confirmed.emit()
	for side: String in ["left", "right"]:
		var hand: RigidBody3D = _hardware.bodies[role_parts[side + "_elbow"]]
		var tip: Vector3 = _grip_tip(side)
		var local_point: Vector3 = box.to_local(tip).clamp(Vector3(-0.17, -0.10, -0.10), Vector3(0.17, 0.10, 0.10))
		var joint := PinJoint3D.new()
		_hardware.add_child(joint)
		joint.global_position = box.to_global(local_point)
		joint.node_a = hand.get_path()
		joint.node_b = box.get_path()
		_grips.append(joint)
	grasped = true
	pickup_state = "lifting"
	_pickup_time = 0.0
	_set_status("Box gripped through hand contact. Lifting.")


func _shoulder_position(side: String) -> Vector3:
	return _hardware.bodies[role_parts[side + "_shoulder"]].to_global(Vector3(0, 0.11, 0))


# Vector2 would quantize servo targets to float32 and change physical contact timing.
func _reach_angles(side: String, target: Vector3) -> Array[float]:
	var torso: RigidBody3D = _hardware.bodies[body_part]
	var offset: Vector3 = torso.global_basis.inverse() * (target - _shoulder_position(side))
	var distance: float = minf(Vector2(offset.y, offset.z).length(), 0.438)
	var elbow: float = -acos(clampf((distance * distance - 2.0 * 0.22 * 0.22) / (2.0 * 0.22 * 0.22), -1.0, 1.0))
	return [atan2(-offset.z, -offset.y) - elbow * 0.5, elbow]


func _grip_tip(side: String) -> Vector3:
	return _hardware.bodies[role_parts[side + "_elbow"]].to_global(Vector3(0, -0.11, 0))


func _write(role: String, degrees: float) -> void:
	var servo: ServoDrive = _drives.get(role)
	if servo != null:
		servo.write_relative(degrees)


func _balance_correction(desired_pitch: float = 0.0) -> float:
	var torso: RigidBody3D = _hardware.bodies[body_part]
	var pitch: float = atan2(torso.global_basis.y.z, torso.global_basis.y.y)
	return clampf((pitch - desired_pitch) * balance_gain + torso.angular_velocity.x * 0.12, -0.4, 0.4)


func _motor_response(fast: bool) -> void:
	for servo: ServoDrive in _drives.values():
		servo.velocity_gain = 18.0 if fast else 12.0
		servo.maximum_velocity = 8.0 if fast else 4.0
		servo.speed_deg_per_s = 480.0 if fast else 240.0


func _neighbor(part: int, port: String) -> int:
	var found: int = -1
	for link: Dictionary in _graph.links:
		for side: String in ["a", "b"]:
			if link[side + "_part"] == part and String(link[side + "_port"]) == port:
				var other: String = "b" if side == "a" else "a"
				if found >= 0:
					return -1
				found = link[other + "_part"]
	return found
