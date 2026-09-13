class_name RunMode
extends Node3D

## Builds the physics scene from a ConnectionGraph and nothing else (ADR 0003).
## Every body and joint here is derived; teardown() must leave no trace.

## Parts that sit on the table and never move (frozen as static bodies).
@export var anchored_part_ids: Array[StringName] = [&"base", &"board"]

var bodies: Array[RigidBody3D] = []
## graph part index -> ServoDrive, for every part that owns a rotating port in a link.
var servos: Dictionary = {}
var _graph: ConnectionGraph


func build(graph: ConnectionGraph) -> void:
	teardown()
	_graph = graph
	for i in graph.parts.size():
		bodies.append(_make_body(graph.parts[i], i))
	for link: Dictionary in graph.links:
		_make_joint(link)


func teardown() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	bodies.clear()
	servos.clear()
	_graph = null


func is_built() -> bool:
	return _graph != null


## The servo wired to this pin, or null when nothing is plugged in there (ADR 0002).
func servo_on_pin(pin: int) -> ServoDrive:
	if _graph == null:
		return null
	var wired: Dictionary = Wiring.pin_map(_graph)
	if not wired.has(pin):
		return null
	return servos.get(wired[pin].part)


func _make_body(entry: Dictionary, index: int) -> RigidBody3D:
	var def: PartDef = entry.part_def
	var body := RigidBody3D.new()
	body.name = "%s_%d" % [def.id, index]
	body.mass = def.mass_kg
	body.can_sleep = false
	var mesh := MeshInstance3D.new()
	mesh.mesh = def.mesh
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var aabb := def.mesh.get_aabb()
	box.size = aabb.size
	shape.shape = box
	shape.position = aabb.get_center()
	body.add_child(shape)
	if def.id in anchored_part_ids:
		body.freeze = true
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	add_child(body)
	body.global_transform = entry.transform
	return body


func _make_joint(link: Dictionary) -> void:
	var a_def: PartDef = _graph.parts[link.a_part].part_def
	var b_def: PartDef = _graph.parts[link.b_part].part_def
	var a_port := _port(a_def, link.a_port)
	var b_port := _port(b_def, link.b_port)
	if a_port.kind != Port.Kind.MECH or b_port.kind != Port.Kind.MECH:
		return
	var body_a := bodies[link.a_part]
	var body_b := bodies[link.b_part]
	var anchor: Vector3 = body_a.global_transform * a_port.local_position
	var joint: Joint3D
	if a_port.rotates or b_port.rotates:
		var driven_body := body_a if a_port.rotates else body_b
		var driven_port := a_port if a_port.rotates else b_port
		var axis: Vector3 = (driven_body.global_transform.basis * driven_port.local_normal).normalized()
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


static func _basis_with_z(z: Vector3) -> Basis:
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	return Basis.looking_at(-z, up)


static func _port(def: PartDef, port_id: StringName) -> Port:
	for port in def.ports:
		if port.id == port_id:
			return port
	push_error("Part %s has no port %s" % [def.id, port_id])
	return null
