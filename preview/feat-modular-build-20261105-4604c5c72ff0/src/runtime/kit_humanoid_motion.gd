class_name KitHumanoidMotion
extends HumanoidMotion

var _shoulder_anchors: Dictionary = {}
var _tip_anchors: Dictionary = {}
var _arm_geometry: Dictionary = {}
var _grasp_start_angles: Dictionary = {}
var support_position_gain: float = 8.0
var support_velocity_gain: float = 1.2
var _balance_bodies: Array[RigidBody3D] = []
var _support_bodies: Array[RigidBody3D] = []


static func recognizes(graph: ConnectionGraph) -> bool:
	return not topology(graph).is_empty()


static func topology(graph: ConnectionGraph) -> Dictionary:
	if graph == null or graph.parts.is_empty() or graph.parts.size() > 256:
		return {}
	var groups: Array[int] = []
	for index: int in graph.parts.size():
		if not graph.parts[index].get("part_def") is PartDef:
			return {}
		groups.append(index)
	var hinges: Array[Dictionary] = []
	for link: Dictionary in graph.links:
		if link.a_part < 0 or link.a_part >= groups.size() or link.b_part < 0 or link.b_part >= groups.size():
			return {}
		var a: Port = _find_port(graph.parts[link.a_part].part_def, link.a_port)
		var b: Port = _find_port(graph.parts[link.b_part].part_def, link.b_port)
		if a == null or b == null:
			return {}
		if a.kind != Port.Kind.MECH or b.kind != Port.Kind.MECH:
			continue
		if a.rotates or b.rotates:
			var motor: int = link.a_part if a.rotates else link.b_part
			var output: int = link.b_part if a.rotates else link.a_part
			var definition: PartDef = graph.parts[motor].part_def
			if definition.id not in [&"kit_motor_35", &"kit_motor_12"] or not definition.actuator_drives_connected_body or definition.actuator_torque_nm <= 0.0:
				return {}
			var port: Port = a if a.rotates else b
			hinges.append({"motor": motor, "output": output, "port": port, "pivot": graph.parts[motor].transform * port.local_position})
			continue
		if not graph.parts[link.a_part].part_def.merge_fixed_connections or not graph.parts[link.b_part].part_def.merge_fixed_connections:
			return {}
		var previous: int = groups[link.b_part]
		var replacement: int = groups[link.a_part]
		for index: int in groups.size():
			if groups[index] == previous:
				groups[index] = replacement
	if hinges.size() != 10:
		return {}
	var outgoing: Dictionary = {}
	var incoming: Dictionary = {}
	for hinge: Dictionary in hinges:
		var parent: int = groups[hinge.motor]
		var child: int = groups[hinge.output]
		if parent == child or incoming.has(child):
			return {}
		if not outgoing.has(parent):
			outgoing[parent] = []
		outgoing[parent].append(hinge)
		incoming[child] = parent
	var root_group: int = -1
	for group: int in outgoing:
		if outgoing[group].size() == 4 and not incoming.has(group):
			if root_group >= 0:
				return {}
			root_group = group
	if root_group < 0:
		return {}
	var center: Vector3 = Vector3.ZERO
	for hinge: Dictionary in outgoing[root_group]:
		center += hinge.pivot * 0.25
	var roles: Dictionary = {}
	for initial: Dictionary in outgoing[root_group]:
		var chain: Array[Dictionary] = [initial]
		var next: int = groups[initial.output]
		while outgoing.has(next):
			if outgoing[next].size() != 1 or chain.size() >= 3:
				return {}
			chain.append(outgoing[next][0])
			next = groups[chain[-1].output]
		if chain.size() not in [2, 3] or absf(initial.pivot.x - center.x) < 0.03:
			return {}
		var side: String = "left" if initial.pivot.x < center.x else "right"
		var labels: Array[String] = []
		labels.assign(["hip", "knee", "ankle"] if chain.size() == 3 else ["shoulder", "elbow"])
		if (chain.size() == 3 and initial.pivot.y >= center.y) or (chain.size() == 2 and initial.pivot.y <= center.y):
			return {}
		for index: int in chain.size():
			var role: String = side + "_" + labels[index]
			if roles.has(role):
				return {}
			var axis: Vector3 = graph.parts[chain[index].motor].transform.basis * chain[index].port.local_normal
			if axis.dot(Vector3.RIGHT) < 0.999:
				return {}
			roles[role] = chain[index]
			if index > 0:
				var delta: Vector3 = chain[index].pivot - chain[index - 1].pivot
				if absf(delta.y + (0.24 if chain.size() == 3 else 0.22)) > 0.002 or absf(delta.z) > 0.002:
					return {}
	if roles.size() != 10:
		return {}
	var body_part: int = groups.find(root_group)
	for index: int in groups.size():
		if groups[index] == root_group and graph.parts[index].part_def.physics_frame_priority > graph.parts[body_part].part_def.physics_frame_priority:
			body_part = index
	return {"groups": groups, "root": body_part, "roles": roles}


func configure(hardware: RunMode, graph: ConnectionGraph) -> bool:
	set_enabled(false)
	_hardware = hardware
	_graph = graph
	_supported = false
	role_pins.clear()
	role_parts.clear()
	_drives.clear()
	_shoulder_anchors.clear()
	_tip_anchors.clear()
	_arm_geometry.clear()
	_grasp_start_angles.clear()
	_balance_bodies.clear()
	_support_bodies.clear()
	body_part = -1
	_box_part = -1
	fallen = false
	_set_status("Humanoid needs all ten joints and unambiguous wiring. Reload the humanoid preset to reset.")
	if hardware == null or graph == null or not hardware.is_built() or hardware._graph != graph:
		return false
	var morphology: Dictionary = topology(graph)
	if morphology.is_empty():
		return false
	body_part = morphology.root
	for index: int in graph.parts.size():
		if graph.parts[index].part_def.id == &"cargo_box":
			_box_part = index
	var channels: Array[Dictionary] = hardware.wired_servo_channels()
	for role: String in morphology.roles:
		var hinge: Dictionary = morphology.roles[role]
		role_parts[role] = hinge.output
		for channel: Dictionary in channels:
			if channel.part == hinge.motor:
				if role_pins.has(role):
					return false
				role_pins[role] = channel.pin
		if not role_pins.has(role):
			return false
		_drives[role] = hardware.servo_on_pin(role_pins[role])
	for side: String in ["left", "right"]:
		var shoulder: Dictionary = morphology.roles[side + "_shoulder"]
		_shoulder_anchors[side] = {"part": shoulder.motor, "position": shoulder.port.local_position}
		var hand_part: int = role_parts[side + "_elbow"]
		var group: int = morphology.groups[hand_part]
		var contact_pad: int = -1
		for index: int in graph.parts.size():
			if morphology.groups[index] != group:
				continue
			var definition: PartDef = graph.parts[index].part_def
			if definition.id == &"kit_rubber_pad":
				if contact_pad >= 0:
					return false
				contact_pad = index
		if contact_pad < 0:
			return false
		var pad_center: Vector3 = graph.parts[contact_pad].part_def.mesh.get_aabb().get_center()
		_tip_anchors[side] = {"part": contact_pad, "position": pad_center}
		var elbow: Dictionary = morphology.roles[side + "_elbow"]
		var upper_offset: Vector3 = elbow.pivot - shoulder.pivot
		var distal_offset: Vector3 = graph.parts[contact_pad].transform * pad_center - elbow.pivot
		_arm_geometry[side] = {"upper": Vector2(upper_offset.y, upper_offset.z).length(),
			"lower": Vector2(distal_offset.y, distal_offset.z).length(),
			"rest_angle": atan2(-distal_offset.z, -distal_offset.y)}
		for part: int in [role_parts[side + "_ankle"], hand_part]:
			var body: RigidBody3D = hardware.bodies[part]
			body.contact_monitor = true
			body.max_contacts_reported = 24
	var robot_groups: Dictionary = {morphology.groups[body_part]: true}
	for part: int in role_parts.values():
		robot_groups[morphology.groups[part]] = true
	var seen_bodies: Dictionary = {}
	for index: int in graph.parts.size():
		var body: RigidBody3D = hardware.bodies[index]
		if robot_groups.has(morphology.groups[index]) and not seen_bodies.has(body):
			seen_bodies[body] = true
			_balance_bodies.append(body)
	for side: String in ["left", "right"]:
		_support_bodies.append(hardware.bodies[role_parts[side + "_ankle"]])
	_supported = true
	_set_status("Experimental humanoid: torque-controlled joints")
	return true


func _shoulder_position(side: String) -> Vector3:
	var anchor: Dictionary = _shoulder_anchors[side]
	return _hardware.part_global_transform(anchor.part) * anchor.position


func _grip_tip(side: String) -> Vector3:
	var anchor: Dictionary = _tip_anchors[side]
	return _hardware.part_global_transform(anchor.part) * anchor.position


func _reach_angles(side: String, target: Vector3) -> Array[float]:
	var torso: RigidBody3D = _hardware.bodies[body_part]
	var offset: Vector3 = torso.global_basis.inverse() * (target - _shoulder_position(side))
	var geometry: Dictionary = _arm_geometry[side]
	var upper: float = geometry.upper
	var lower: float = geometry.lower
	var distance: float = minf(Vector2(offset.y, offset.z).length(), upper + lower - 0.002)
	var bend: float = -acos(clampf((distance * distance - upper * upper - lower * lower) / (2.0 * upper * lower), -1.0, 1.0))
	var shoulder: float = atan2(-offset.z, -offset.y) - atan2(lower * sin(bend), upper + lower * cos(bend))
	return [shoulder, bend - float(geometry.rest_angle)]


static func _find_port(definition: PartDef, id: StringName) -> Port:
	for port: Port in definition.ports:
		if port.id == id:
			return port
	return null


func _try_grasp() -> void:
	super._try_grasp()
	if grasped:
		_grasp_start_angles.clear()
		for side: String in ["left", "right"]:
			for role: String in ["shoulder", "elbow"]:
				var key: String = side + "_" + role
				_grasp_start_angles[key] = _drives[key].measured_deg


func _pickup_pose() -> void:
	if pickup_state != "lifting":
		super._pickup_pose()
		return
	var progress: float = smoothstep(0.0, float(pickup_policy.lift_seconds), _pickup_time)
	var height: float = lerpf(float(pickup_policy.crouch_height), stance_height, progress)
	var lean: float = deg_to_rad(float(pickup_policy.torso_lean_deg)) * (1.0 - progress)
	var bend: float = 2.0 * acos(clampf(height / 0.48, 0.0, 1.0))
	for side: String in ["left", "right"]:
		_write(side + "_hip", -rad_to_deg(bend) * 0.5 - rad_to_deg(lean))
		_write(side + "_knee", rad_to_deg(bend))
		_write(side + "_ankle", -rad_to_deg(bend) * 0.5 + rad_to_deg(_balance_correction(lean)))
		for role: String in ["shoulder", "elbow"]:
			var key: String = side + "_" + role
			_write(key, lerpf(float(_grasp_start_angles[key]), float(pickup_policy["hold_" + role + "_deg"]), progress))
	if _pickup_time >= float(pickup_policy.lift_seconds):
		pickup_state = "holding"
		_set_status("Box held. E releases it; Stop also releases the grip.")


func _balance_correction(_desired_pitch: float = 0.0) -> float:
	var torso: RigidBody3D = _hardware.bodies[body_part]
	var center: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var mass: float = 0.0
	for body: RigidBody3D in _balance_bodies:
		center += body.to_global(body.center_of_mass) * body.mass
		velocity += body.linear_velocity * body.mass
		mass += body.mass
	if grasped and _box_part >= 0:
		var box: RigidBody3D = _hardware.bodies[_box_part]
		center += box.to_global(box.center_of_mass) * box.mass
		velocity += box.linear_velocity * box.mass
		mass += box.mass
	center /= mass
	velocity /= mass
	var support: Vector3 = Vector3.ZERO
	for foot: RigidBody3D in _support_bodies:
		support += foot.to_global(foot.center_of_mass) / _support_bodies.size()
	# Moving arms and cargo change balance even while the torso remains vertical.
	var forward: Vector3 = torso.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var error: float = (center - support).dot(forward)
	var angular_speed: float = torso.angular_velocity.dot(torso.global_basis.x)
	return clampf(error * support_position_gain + velocity.dot(forward) * support_velocity_gain + angular_speed * 0.1, -0.6, 0.6)
