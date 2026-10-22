class_name RunMode
extends Node3D

## Builds the physics scene from a ConnectionGraph and nothing else (ADR 0003).
## Every body and joint here is derived; teardown() must leave no trace.

## Parts that sit on the table and never move (frozen as static bodies).
@export var anchored_part_ids: Array[StringName] = [&"base", &"board", &"arduino_uno", &"stage_wall", &"kit_env_line_straight", &"kit_env_line_corner", &"kit_env_ramp_10", &"kit_env_ramp_20", &"kit_env_cup"]

var bodies: Array[RigidBody3D] = []
## graph part index -> ServoDrive, for every part that owns a rotating port in a link.
var servos: Dictionary = {}
var motors: Dictionary = {}
var sonars: Dictionary = {}
var gears: Dictionary = {}
var line_sensors: Dictionary = {}
var buttons: Dictionary = {}
var leds: Dictionary = {}
var _part_visuals: Dictionary = {}
var _graph: ConnectionGraph
var _body_offsets: Array[Transform3D] = []


func build(graph: ConnectionGraph) -> void:
	teardown()
	_graph = graph
	var groups: Array[int] = []
	for i: int in graph.parts.size():
		groups.append(i)
	for link: Dictionary in graph.links:
		var a: PartDef = graph.parts[link.a_part].part_def
		var b: PartDef = graph.parts[link.b_part].part_def
		var pa: Port = _port(a, link.a_port)
		var pb: Port = _port(b, link.b_port)
		if _is_gear_shaft(a, pa.id) or _is_gear_shaft(b, pb.id):
			continue
		if not a.merge_fixed_connections or not b.merge_fixed_connections:
			continue
		if pa.kind != Port.Kind.MECH or pb.kind != Port.Kind.MECH or pa.rotates or pb.rotates:
			continue
		var previous: int = groups[link.b_part]
		var replacement: int = groups[link.a_part]
		for i: int in groups.size():
			if groups[i] == previous:
				groups[i] = replacement
	bodies.resize(graph.parts.size())
	_body_offsets.resize(graph.parts.size())
	var built_groups: Dictionary = {}
	for i: int in graph.parts.size():
		if built_groups.has(groups[i]):
			continue
		var members: Array[int] = []
		for j: int in groups.size():
			if groups[j] == groups[i]:
				members.append(j)
		_make_cluster(members)
		built_groups[groups[i]] = true
	for i: int in graph.parts.size():
		if graph.parts[i].part_def.gear_ratio > 0.0:
			_make_gear(i)
		if graph.parts[i].part_def.device_kind == "Button":
			var button := ContactButton.new()
			button.run_mode = self
			button.part_index = i
			add_child(button)
			buttons[i] = button
	for part: int in graph.parts.size():
		if graph.parts[part].part_def.device_kind == "LED":
			var led := LEDDevice.new()
			led.configure(_part_visuals[part])
			leds[part] = led
	for link: Dictionary in graph.links:
		_make_joint(link)


func teardown() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	bodies.clear()
	servos.clear()
	motors.clear()
	sonars.clear()
	gears.clear()
	line_sensors.clear()
	buttons.clear()
	leds.clear()
	_part_visuals.clear()
	_body_offsets.clear()
	_graph = null


func is_built() -> bool:
	return _graph != null


func part_global_transform(part: int) -> Transform3D:
	return bodies[part].global_transform * _body_offsets[part]


func _make_cluster(members: Array[int]) -> void:
	var representative: int = members[0]
	for member: int in members:
		if _graph.parts[member].part_def.physics_frame_priority > _graph.parts[representative].part_def.physics_frame_priority:
			representative = member
	var body: RigidBody3D = _make_body(_graph.parts[representative], representative)
	var total_mass: float = body.mass
	var mass_center: Vector3 = Vector3.ZERO
	for member: int in members:
		var entry: Dictionary = _graph.parts[member]
		var definition: PartDef = entry.part_def
		var offset: Transform3D = body.global_transform.affine_inverse() * entry.transform
		bodies[member] = body
		_body_offsets[member] = offset
		if member == representative:
			continue
		total_mass += definition.mass_kg
		mass_center += offset.origin * definition.mass_kg
		_add_part_geometry(body, definition, offset, member)
		if definition.id in anchored_part_ids:
			body.freeze = true
	if members.size() > 1:
		body.mass = total_mass
		body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		body.center_of_mass = mass_center / total_mass


## The servo wired to this pin, or null when nothing is plugged in there (ADR 0002).
func servo_on_pin(pin: int) -> ServoDrive:
	if _graph == null:
		return null
	var wired: Dictionary = Wiring.pin_map(_graph)
	if not wired.has(pin):
		return null
	return servos.get(wired[pin].part)


## Ambiguous numeric addresses cannot be controlled until the wiring is disambiguated.
func wired_servo_channels() -> Array[Dictionary]:
	var channels: Array[Dictionary] = []
	if _graph == null:
		return channels
	var addresses: Dictionary = {}
	for link: Dictionary in _graph.links:
		for side: String in ["a", "b"]:
			var part_index: int = link[side + "_part"]
			var definition: PartDef = _graph.parts[part_index].part_def
			var port := _port(definition, link[side + "_port"])
			if port == null or port.kind != Port.Kind.ELEC:
				continue
			var pin := Wiring.pin_number(port)
			if pin < 0:
				continue
			if not addresses.has(pin):
				addresses[pin] = []
			addresses[pin].append(part_index)
	var wired := Wiring.pin_map(_graph)
	var pins: Array = wired.keys()
	pins.sort()
	for pin: int in pins:
		if not addresses.has(pin) or addresses[pin].size() != 1:
			continue
		var part_index: int = wired[pin].part
		if not servos.has(part_index):
			continue
		var definition: PartDef = _graph.parts[part_index].part_def
		var board_index: int = addresses[pin][0]
		var board: PartDef = _graph.parts[board_index].part_def
		channels.append({
			"pin": pin, "part": part_index, "board_part": board_index,
			"label": "%s #%d · %s #%d / D%d" % [
				definition.display_name, part_index + 1,
				board.display_name, board_index + 1, pin],
		})
	return channels


func _make_body(entry: Dictionary, index: int) -> RigidBody3D:
	var def: PartDef = entry.part_def
	var body := RigidBody3D.new()
	body.name = "%s_%d" % [def.id, index]
	body.mass = def.mass_kg
	body.can_sleep = false
	body.collision_layer = 4 if def.surface_marker else 3
	if def.surface_marker:
		body.collision_mask = 0
	body.contact_monitor = true
	body.max_contacts_reported = 16
	_add_part_geometry(body, def, Transform3D.IDENTITY, index)
	if def.id in anchored_part_ids:
		body.freeze = true
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	add_child(body)
	body.global_transform = entry.transform
	return body


func _add_part_geometry(body: RigidBody3D, definition: PartDef, offset: Transform3D, part: int) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = definition.mesh
	mesh.transform = offset
	body.add_child(mesh)
	_part_visuals[part] = mesh
	if not definition.collision_points.is_empty():
		var shape := CollisionShape3D.new()
		var convex := ConvexPolygonShape3D.new()
		convex.points = definition.collision_points
		shape.shape = convex
		shape.transform = offset
		body.add_child(shape)
		return
	if definition.sphere_radius > 0.0:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = definition.sphere_radius
		shape.shape = sphere
		shape.transform = offset
		body.add_child(shape)
		return
	if definition.caster_radius > 0.0:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = definition.caster_radius
		shape.shape = sphere
		shape.transform = offset
		body.add_child(shape)
		var material := PhysicsMaterial.new()
		material.friction = 0.01
		body.physics_material_override = material
		return
	if definition.wheel_radius > 0.0:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = definition.wheel_radius
		cylinder.height = definition.wheel_width
		shape.shape = cylinder
		shape.transform = offset * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
		body.add_child(shape)
		var material := PhysicsMaterial.new()
		material.friction = definition.rolling_friction
		body.physics_material_override = material
		body.angular_damp = 0.02
		return
	var bounds_list: Array[AABB] = definition.collision_boxes.duplicate()
	if bounds_list.is_empty():
		bounds_list.append(definition.mesh.get_aabb())
	for bounds: AABB in bounds_list:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size.max(Vector3.ONE * 0.0001)
		shape.shape = box
		shape.transform = offset * Transform3D(Basis.IDENTITY, bounds.get_center())
		shape.set_meta("button_surface", part if definition.device_kind == "Button" and bounds.get_center().z > 0.009 else -1)
		body.add_child(shape)


func _make_joint(link: Dictionary) -> void:
	var a_def: PartDef = _graph.parts[link.a_part].part_def
	var b_def: PartDef = _graph.parts[link.b_part].part_def
	var a_port := _port(a_def, link.a_port)
	var b_port := _port(b_def, link.b_port)
	if a_port.kind != Port.Kind.MECH or b_port.kind != Port.Kind.MECH:
		return
	var body_a: RigidBody3D = _connection_body(link.a_part, link.a_port)
	var body_b: RigidBody3D = _connection_body(link.b_part, link.b_port)
	if body_a == body_b:
		return
	var a_transform: Transform3D = _graph.parts[link.a_part].transform
	var b_transform: Transform3D = _graph.parts[link.b_part].transform
	var anchor: Vector3 = a_transform * a_port.local_position
	var joint: Joint3D
	if a_port.rotates or b_port.rotates:
		var driven_transform: Transform3D = a_transform if a_port.rotates else b_transform
		var driven_port := a_port if a_port.rotates else b_port
		var axis: Vector3 = (driven_transform.basis * driven_port.local_normal).normalized()
		var hinge := HingeJoint3D.new()
		add_child(hinge)
		hinge.global_transform = Transform3D(_basis_with_z(axis), anchor)
		joint = hinge
		var owner: int = link.a_part if a_port.rotates else link.b_part
		if _graph.parts[owner].part_def.passive_hinge:
			hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
			# Godot's hinge angle is the opposite of the connected body's bearing-relative angle.
			hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -deg_to_rad(_graph.parts[owner].part_def.actuator_max_deg))
			hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, -deg_to_rad(_graph.parts[owner].part_def.actuator_min_deg))
		elif _graph.parts[owner].part_def.dc_motor:
			var drive := DriveMotor.new()
			drive.housing = bodies[owner]
			drive.wheel = body_b if a_port.rotates else body_a
			drive.axis_local = drive.housing.global_basis.inverse() * (_graph.parts[owner].transform.basis * Vector3.FORWARD)
			drive.stall_torque_nm = _graph.parts[owner].part_def.motor_stall_torque_nm
			drive.no_load_rad_s = _graph.parts[owner].part_def.motor_no_load_rpm * TAU / 60.0
			add_child(drive)
			motors[owner] = drive
		else:
			var drive := ServoDrive.new()
			drive.joint = hinge
			add_child(drive)
			servos[owner] = drive
	else:
		var fixed := Generic6DOFJoint3D.new()
		add_child(fixed)
		fixed.global_transform = Transform3D(Basis.IDENTITY, anchor)
		joint = fixed
	if (a_port.rotates and a_def.passive_hinge) or (b_port.rotates and b_def.passive_hinge):
		# Catalog angle limits use the bearing as the reference, regardless of link ordering.
		joint.node_a = (body_a if a_port.rotates else body_b).get_path()
		joint.node_b = (body_b if a_port.rotates else body_a).get_path()
		return
	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()
	if a_port.rotates or b_port.rotates:
		var definition: PartDef = a_def if a_port.rotates else b_def
		if definition.actuator_torque_nm > 0.0 and not definition.dc_motor:
			var drive: ServoDrive = servos[link.a_part if a_port.rotates else link.b_part]
			drive.configure_torque_actuator(body_a, body_b, definition, a_port.rotates)
		elif not definition.dc_motor:
			(servos[link.a_part if a_port.rotates else link.b_part] as ServoDrive).configure_observation(body_a, body_b, a_port.rotates)


static func _basis_with_z(z: Vector3) -> Basis:
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(-z, up)


static func _port(def: PartDef, port_id: StringName) -> Port:
	for port in def.ports:
		if port.id == port_id:
			return port
	push_error("Part %s has no port %s" % [def.id, port_id])
	return null


func profile() -> BoardProfile:
	if _graph != null:
		for part: Dictionary in _graph.parts:
			if not part.part_def.board_profile_id.is_empty():
				return BoardProfile.for_id(part.part_def.board_profile_id)
	return BoardProfile.new()


func sleep_scale() -> float:
	return profile().sleep_unit_seconds


func stop_motors() -> void:
	for led: LEDDevice in leds.values():
		led.off()
	for drive: DriveMotor in motors.values():
		drive.stop()


func device(kind: String, args: Array) -> Variant:
	if kind == "Servo":
		return servo_on_pin(int(args[0]))
	if kind == "Motor":
		return motor_on_pins(int(args[0]), int(args[1])) if args.size() == 2 else motor_on_pin(int(args[0]))
	if kind == "LED":
		return leds.get(single_signal_part(int(args[0]), "LED"))
	if kind == "Button":
		return buttons.get(single_signal_part(int(args[0]), "Button"))
	if kind == "LineSensor":
		return line_on_pin(int(args[0]))
	if kind == "Sonar":
		return sonar_on_pins(int(args[0]), int(args[1]))
	return null


func has_device(kind: String, pins: Array[int]) -> bool:
	return device(kind, pins) != null


func motor_on_pin(pin: int) -> DriveMotor:
	if _graph == null:
		return null
	var wires: Dictionary = Wiring.pin_map(_graph)
	if not wires.has(pin):
		return null
	var driver: int = wires[pin].part
	if _graph.parts[driver].part_def.id not in [&"motor_driver", &"tb6612_driver"]:
		return null
	var input: String = wires[pin].port
	if input not in ["input_0", "input_12", "input_3", "input_6"]:
		return null
	var paired: StringName = &"input_8" if input == "input_0" else (&"input_16" if input == "input_12" else (&"input_4" if input == "input_3" else &"input_7"))
	var pair_connected: bool = false
	for mapping: Dictionary in wires.values():
		if mapping.part == driver and mapping.port == paired:
			pair_connected = true
	if not pair_connected:
		return null
	var channel: StringName = &"motor_1" if input in ["input_0", "input_3"] else &"motor_2"
	for link: Dictionary in _graph.links:
		var motor_index: int = -1
		if link.a_part == driver and link.a_port == channel:
			motor_index = link.b_part
		elif link.b_part == driver and link.b_port == channel:
			motor_index = link.a_part
		if motors.has(motor_index):
			var drive: DriveMotor = motors[motor_index]
			drive.supply_voltage = _graph.parts[driver].part_def.driver_supply_voltage
			drive.voltage_drop = _graph.parts[driver].part_def.driver_voltage_drop
			return drive
	return null


func motor_on_pins(first: int, second: int) -> DriveMotor:
	var drive: DriveMotor = motor_on_pin(first)
	if drive == null:
		return null
	var wires: Dictionary = Wiring.pin_map(_graph)
	if not wires.has(second) or wires[first].part != wires[second].part:
		return null
	var pairs: Dictionary = {&"input_0": &"input_8", &"input_12": &"input_16", &"input_3": &"input_4", &"input_6": &"input_7"}
	return drive if wires[second].port == pairs.get(wires[first].port) else null


func sonar_on_pins(trigger: int, echo: int) -> SonarSensor:
	if _graph == null:
		return null
	var wires: Dictionary = Wiring.pin_map(_graph)
	if not wires.has(trigger) or not wires.has(echo):
		return null
	var part: int = wires[trigger].part
	if part != wires[echo].part or _graph.parts[part].part_def.id != &"hc_sr04" or wires[trigger].port != &"trig_pin" or wires[echo].port != &"echo_pin":
		return null
	if not sonars.has(part):
		var sensor := SonarSensor.new()
		sensor.run_mode = self
		sensor.part_index = part
		sonars[part] = sensor
	return sonars[part]


func pulse_us(args: Array) -> Dictionary:
	var pin: int = int(args[0])
	if args[1] != 1 or args.size() == 3 and (not args[2] is float and not args[2] is int or args[2] < 0):
		return {"error": tr("Use a connected echo pin and pulse level 1.")}
	var wires: Dictionary = Wiring.pin_map(_graph)
	if not wires.has(pin) or wires[pin].port != &"echo_pin":
		return {"error": tr("Pin %d has nothing connected") % pin}
	for other: int in wires:
		var sensor: SonarSensor = sonar_on_pins(other, pin)
		if sensor != null:
			return {"value": sensor.time_pulse_us(int(args[2]) if args.size() == 3 else 1000000)}
	return {"error": tr("Use a connected echo pin and pulse level 1.")}


func robot_rids(start: int) -> Array[RID]:
	var connected: Array[int] = [start]
	var changed: bool = true
	while changed:
		changed = false
		for link: Dictionary in _graph.links:
			if _port(_graph.parts[link.a_part].part_def, link.a_port).kind != Port.Kind.MECH:
				continue
			if link.a_part in connected and link.b_part not in connected:
				connected.append(link.b_part)
				changed = true
			elif link.b_part in connected and link.a_part not in connected:
				connected.append(link.a_part)
				changed = true
	var result: Array[RID] = []
	for index: int in connected:
		var rid: RID = bodies[index].get_rid()
		if rid not in result:
			result.append(rid)
	return result


func sonar_for_part(part: int) -> SonarSensor:
	var mapping: Dictionary = Wiring.pin_map(_graph)
	var trigger: int = -1
	var echo: int = -1
	for pin: int in mapping:
		if mapping[pin].part == part:
			if mapping[pin].port == &"trig_pin":
				trigger = pin
			elif mapping[pin].port == &"echo_pin":
				echo = pin
	return sonar_on_pins(trigger, echo) if trigger >= 0 and echo >= 0 else null


static func _is_gear_shaft(definition: PartDef, port: StringName) -> bool:
	return definition.gear_ratio > 0.0 and port in [&"input", &"output"]


func _connection_body(part: int, port: StringName) -> RigidBody3D:
	if gears.has(part) and _is_gear_shaft(_graph.parts[part].part_def, port):
		return gears[part].input if port == &"input" else gears[part].output
	return bodies[part]


func _make_gear(part: int) -> void:
	var definition: PartDef = _graph.parts[part].part_def
	var drive := GearConstraint.new()
	drive.housing = bodies[part]
	drive.housing.mass -= 0.01
	drive.ratio = definition.gear_ratio
	# Motors run before the passive transmission; no commanded torque is added here.
	drive.process_physics_priority = 1
	add_child(drive)
	gears[part] = drive
	for port_id: StringName in [&"input", &"output"]:
		var port: Port = _port(definition, port_id)
		var shaft: RigidBody3D
		# Merge each rigidly attached axle/load into the rotor, so its actual inertia
		# participates in the gear impulse rather than lagging through a fixed joint.
		for link: Dictionary in _graph.links:
			for side: String in ["a", "b"]:
				var other: String = "b" if side == "a" else "a"
				if link[side + "_part"] == part and link[side + "_port"] == port_id:
					var other_def: PartDef = _graph.parts[link[other + "_part"]].part_def
					if not _port(other_def, link[other + "_port"]).rotates and other_def.gear_ratio == 0.0:
						shaft = bodies[link[other + "_part"]]
		var rotor_pose: Transform3D = _graph.parts[part].transform * Transform3D(Basis.IDENTITY, port.local_position)
		if shaft == null:
			shaft = RigidBody3D.new()
			shaft.mass = 0.005
			shaft.can_sleep = false
			shaft.collision_layer = 3
			add_child(shaft)
			shaft.global_transform = rotor_pose
		else:
			shaft.mass += 0.005
		var rotor_offset: Transform3D = shaft.global_transform.affine_inverse() * rotor_pose
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.004
		cylinder.height = 0.008
		shape.shape = cylinder
		shape.transform = rotor_offset * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)
		shaft.add_child(shape)
		var visual := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.008 if port_id == &"input" else 0.008 * drive.ratio
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.006
		visual.mesh = mesh
		visual.transform = shape.transform
		visual.material_override = load("res://assets/materials/detail_teal.tres")
		shaft.add_child(visual)
		var marker := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(mesh.top_radius, 0.002, 0.002)
		marker.mesh = bar
		marker.transform = rotor_offset * Transform3D(Basis.IDENTITY, Vector3(mesh.top_radius / 2, 0, 0.004))
		shaft.add_child(marker)
		shaft.add_collision_exception_with(drive.housing)
		var bearing := HingeJoint3D.new()
		add_child(bearing)
		bearing.global_transform = rotor_pose
		bearing.node_a = drive.housing.get_path()
		bearing.node_b = shaft.get_path()
		if port_id == &"input":
			drive.input = shaft
		else:
			drive.output = shaft
	drive.input.add_collision_exception_with(drive.output)


func single_signal_part(pin: int, kind: String) -> int:
	if _graph == null:
		return -1
	var wires: Dictionary = Wiring.pin_map(_graph)
	if not wires.has(pin) or wires[pin].port != &"signal_pin":
		return -1
	var part: int = wires[pin].part
	return part if _graph.parts[part].part_def.device_kind == kind else -1


func line_on_pin(pin: int) -> LineSensor:
	var part: int = single_signal_part(pin, "LineSensor")
	if part < 0:
		return null
	if not line_sensors.has(part):
		var sensor := LineSensor.new()
		sensor.run_mode = self
		sensor.part_index = part
		line_sensors[part] = sensor
	return line_sensors[part]


## Brightness comes from the hit part's material, with white as the unmarked-floor default.
func surface_brightness(hit: Dictionary) -> float:
	var collider: Node = hit.collider
	var nearest: float = INF
	var brightness: float = 1.0
	for index: int in bodies.size():
		if bodies[index] != collider:
			continue
		var visual: MeshInstance3D = _part_visuals[index]
		var distance: float = visual.global_position.distance_squared_to(hit.position)
		if distance >= nearest:
			continue
		nearest = distance
		var material: StandardMaterial3D = visual.mesh.surface_get_material(0) as StandardMaterial3D
		if material != null:
			var color: Color = material.albedo_color
			brightness = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
	return brightness


## Environment-based observation: unique movable solver bodies wholly inside any cup.
## Cup orientation is respected; no robot/ball SKU or stage target ID is required.
func cup_object_count() -> int:
	var inside: Array[RID] = []
	if _graph == null:
		return 0
	for cup: int in bodies.size():
		var definition: PartDef = _graph.parts[cup].part_def
		if definition.environment_role != "cup":
			continue
		var to_cup: Transform3D = part_global_transform(cup).affine_inverse()
		var candidates: Array[RID] = []
		for part: int in bodies.size():
			var body: RigidBody3D = bodies[part]
			if body.freeze or body == bodies[cup] or body.get_rid() in inside or body.get_rid() in candidates:
				continue
			candidates.append(body.get_rid())
			var fully_inside: bool = true
			for member: int in bodies.size():
				if bodies[member] != body:
					continue
				var bounds: AABB = _graph.parts[member].part_def.mesh.get_aabb()
				var pose: Transform3D = to_cup * part_global_transform(member)
				var radius: float = _graph.parts[member].part_def.sphere_radius
				if radius > 0.0:
					# A rotated sphere stays spherical; rotating its mesh AABB would inflate it.
					bounds = AABB(pose.origin - Vector3.ONE * radius, Vector3.ONE * radius * 2)
					pose = Transform3D.IDENTITY
				for corner: int in 8:
					if not definition.cup_inner_bounds.grow(float(ProjectSettings.get_setting("physics/3d/solver/contact_max_allowed_penetration", 0.001))).has_point(pose * bounds.get_endpoint(corner)):
						fully_inside = false
			if fully_inside:
				inside.append(body.get_rid())
	return inside.size()
