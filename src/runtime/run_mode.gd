class_name RunMode
extends Node3D

## Builds the physics scene from a ConnectionGraph and nothing else (ADR 0003).
## Every body and joint here is derived; teardown() must leave no trace.

## Parts that sit on the table and never move (frozen as static bodies).
@export var anchored_part_ids: Array[StringName] = [&"base", &"board", &"arduino_uno"]

var bodies: Array[RigidBody3D] = []
## graph part index -> ServoDrive, for every part that owns a rotating port in a link.
var servos: Dictionary = {}
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
	for link: Dictionary in graph.links:
		_make_joint(link)


func teardown() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	bodies.clear()
	servos.clear()
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
		_add_part_geometry(body, definition, offset)
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
	_add_part_geometry(body, def, Transform3D.IDENTITY)
	if def.id in anchored_part_ids:
		body.freeze = true
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	add_child(body)
	body.global_transform = entry.transform
	return body


func _add_part_geometry(body: RigidBody3D, definition: PartDef, offset: Transform3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = definition.mesh
	mesh.transform = offset
	body.add_child(mesh)
	var bounds_list: Array[AABB] = definition.collision_boxes.duplicate()
	if bounds_list.is_empty():
		bounds_list.append(definition.mesh.get_aabb())
	for bounds: AABB in bounds_list:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size.max(Vector3.ONE * 0.0001)
		shape.shape = box
		shape.transform = offset * Transform3D(Basis.IDENTITY, bounds.get_center())
		body.add_child(shape)


func _make_joint(link: Dictionary) -> void:
	var a_def: PartDef = _graph.parts[link.a_part].part_def
	var b_def: PartDef = _graph.parts[link.b_part].part_def
	var a_port := _port(a_def, link.a_port)
	var b_port := _port(b_def, link.b_port)
	if a_port.kind != Port.Kind.MECH or b_port.kind != Port.Kind.MECH:
		return
	var body_a := bodies[link.a_part]
	var body_b := bodies[link.b_part]
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
		var drive := ServoDrive.new()
		drive.joint = hinge
		add_child(drive)
		servos[link.a_part if a_port.rotates else link.b_part] = drive
	else:
		var fixed := Generic6DOFJoint3D.new()
		add_child(fixed)
		fixed.global_transform = Transform3D(Basis.IDENTITY, anchor)
		joint = fixed
	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()
	if a_port.rotates or b_port.rotates:
		var definition: PartDef = a_def if a_port.rotates else b_def
		if definition.actuator_torque_nm > 0.0:
			var drive: ServoDrive = servos[link.a_part if a_port.rotates else link.b_part]
			drive.configure_torque_actuator(body_a, body_b, definition, a_port.rotates)


static func _basis_with_z(z: Vector3) -> Basis:
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(-z, up)


static func _port(def: PartDef, port_id: StringName) -> Port:
	for port in def.ports:
		if port.id == port_id:
			return port
	push_error("Part %s has no port %s" % [def.id, port_id])
	return null
