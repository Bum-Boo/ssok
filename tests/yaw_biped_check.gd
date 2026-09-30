extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var original: ConnectionGraph = BipedPreset.build()
	var graph: ConnectionGraph = YawBipedPreset.build()
	_assert(graph.parts.size() == original.parts.size(), "All editable part identities must remain separate")
	_assert(MotionSnapshot.decode(MotionSnapshot.encode(graph)) != null, "Learning catalog must round-trip")
	for index: int in graph.parts.size():
		var definition: PartDef = graph.parts[index].part_def
		_assert(is_equal_approx(definition.mass_kg, original.parts[index].part_def.mass_kg), "Morphology must preserve each part mass")
	for link: Dictionary in graph.links:
		var a: Dictionary = graph.parts[link.a_part]
		var b: Dictionary = graph.parts[link.b_part]
		var ap: Port = _port(a.part_def, link.a_port)
		var bp: Port = _port(b.part_def, link.b_port)
		if ap.kind != Port.Kind.MECH:
			continue
		_assert((a.transform * ap.local_position).distance_to(b.transform * bp.local_position) < 0.000001, "Mechanical anchors must coincide")
		_assert((a.transform.basis * ap.local_normal).dot(b.transform.basis * bp.local_normal) < -0.99999, "Mechanical normals must oppose")
	for hip: int in [1, 5]:
		var entry: Dictionary = graph.parts[hip]
		var shaft: Port = _port(entry.part_def, &"output_shaft")
		_assert((entry.transform.basis * shaft.local_normal).distance_to(Vector3.DOWN) < 0.000001, "Actual motor output axes must point down")
	for index: int in [1, 3, 5, 7]:
		var definition: PartDef = graph.parts[index].part_def
		_assert(definition.actuator_drives_connected_body and is_equal_approx(definition.actuator_torque_nm, 0.25), "Each motor needs bounded physical output torque")
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var unique: Dictionary = {}
	var dynamic_mass: float = 0.0
	for body: RigidBody3D in hardware.bodies:
		if unique.has(body):
			continue
		unique[body] = true
		if not body.freeze:
			dynamic_mass += body.mass
	_assert(unique.size() == 6, "Five dynamic compounds and one anchored board are expected")
	_assert(is_equal_approx(dynamic_mass, 0.193), "Fixed merging must not duplicate physical mass")
	for index: int in graph.parts.size():
		var definition: PartDef = graph.parts[index].part_def
		var bounds: AABB = definition.mesh.get_aabb()
		var expected: Transform3D = graph.parts[index].transform * Transform3D(Basis.IDENTITY, bounds.get_center())
		var matched: bool = false
		for child: Node in hardware.bodies[index].get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				if child.global_transform.is_equal_approx(expected) and child.shape.size.is_equal_approx(bounds.size):
					matched = true
		_assert(matched, "Each original collider must retain its world shape and transform")
	hardware.free()
	print("yaw_biped_check: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _port(definition: PartDef, id: StringName) -> Port:
	for port: Port in definition.ports:
		if port.id == id:
			return port
	return null


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true
