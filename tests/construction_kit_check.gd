extends SceneTree

const CATALOG: String = "res://assets/construction_kit/catalog.json"
const PARTS: String = "res://assets/construction_kit/parts/"
const STRUCTURAL_KINDS: Array[String] = ["beam", "plate", "bracket", "spacer", "coupler", "pad"]

var _checks: int = 0
var _failures: int = 0
var _catalog: Dictionary = {}
var _hole_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not data is Dictionary:
		_check(false, "construction catalog parses")
		quit(1)
		return
	_check(data.standard.pitch_m == 0.02 and data.standard.hole_diameter_m == 0.004, "shared 20 mm pitch and 4 mm holes")
	_check(data.standard.commercial_compatibility == false, "virtual kit makes no commercial standard claim")
	for specification: Dictionary in data.parts:
		_check(not _catalog.has(specification.id), "unique elementary catalog ID " + specification.id)
		_catalog[specification.id] = specification
		_check_definition(specification)
	_check(_catalog.size() >= 20 and _hole_count >= 150, "reusable catalog has substantive hole-port coverage")
	var graph: ConnectionGraph = ConstructionKitHumanoidPreset.build()
	var bridge: ConnectionGraph = ConstructionKitHumanoidPreset.build_bridge()
	_check_graph(graph, "humanoid")
	_check_graph(bridge, "bridge")
	_check_reuse(graph, bridge)
	_check_snapping()
	_check_physics(graph)
	_check_physics(bridge)
	_check_wiring(graph)
	await _check_bridge_stability(bridge)
	await process_frame
	await process_frame
	print("construction_kit_check: %d checks, %d failures, %d catalog holes, %d humanoid parts, %d bridge parts" % [_checks, _failures, _hole_count, graph.parts.size(), bridge.parts.size()])
	quit(1 if _failures else 0)


func _check_definition(specification: Dictionary) -> void:
	var identity: String = specification.id
	for forbidden: String in ["torso", "thigh", "shin", "forearm", "upper_arm", "hand", "foot", "head", "pelvis", "chest"]:
		_check(not identity.contains(forbidden), "no morphology-specific aggregate part: " + identity)
	var definition: PartDef = load(PARTS + identity + ".tres") as PartDef
	_check(definition != null, "generated PartDef exists: " + identity)
	if definition == null:
		return
	_check(String(definition.id) == identity and definition.display_name == specification.name, "catalog identity and displayed name agree: " + identity)
	_check(definition.mesh is ArrayMesh and definition.mesh.resource_path == specification.mesh, "part references its Blender mesh: " + identity)
	_check(is_equal_approx(definition.mass_kg, specification.mass_kg) and definition.mass_kg > 0.0, "catalog owns positive part mass: " + identity)
	_check(definition.merge_fixed_connections, "fixed merging retains independent authored part: " + identity)
	_check(definition.ports.size() == specification.ports.size(), "all ports derive from shared catalog: " + identity)
	for surface: int in definition.mesh.get_surface_count():
		var material: Material = definition.mesh.surface_get_material(surface)
		_check(material is StandardMaterial3D and material.resource_path.begins_with("res://assets/materials/"), "external PBR material on " + identity)
	var declared_ports: Dictionary = {}
	for port_data: Dictionary in specification.ports:
		_check(not declared_ports.has(port_data.id), "unique port " + identity + ":" + port_data.id)
		declared_ports[port_data.id] = port_data
		var port: Port = RunMode._port(definition, StringName(port_data.id))
		_check(port != null, "declared port exists")
		if port == null:
			continue
		_check(port.local_position.distance_to(_vector(port_data.position)) < 0.000001, "port anchor follows catalog " + identity + ":" + port_data.id)
		_check(port.local_normal.is_equal_approx(_vector(port_data.normal)), "port normal follows catalog")
		_check(String(port.tag) == port_data.tag and port.accepts.size() == port_data.accepts.size(), "port compatibility follows catalog")
		for accepted: String in port_data.accepts:
			_check(StringName(accepted) in port.accepts, "reciprocal compatibility tag retained")
		_check(port.rotates == port_data.get("rotates", false), "only declared output shafts rotate")
		_check(port.kind == (Port.Kind.ELEC if port_data.get("kind", "MECH") == "ELEC" else Port.Kind.MECH), "mechanical and electrical interfaces stay distinct")
	var faces: PackedVector3Array = definition.mesh.get_faces()
	for hole: Dictionary in specification.holes:
		_hole_count += 1
		_check_hole(identity, hole, declared_ports, faces)
	if specification.kind in ["beam", "plate"]:
		_check_pitch(specification)
	_check(definition.collision_boxes.size() == specification.collision_boxes.size(), "collision proxies derive from elementary stock: " + identity)
	for index: int in mini(definition.collision_boxes.size(), specification.collision_boxes.size()):
		var shape: AABB = definition.collision_boxes[index]
		var declared: Dictionary = specification.collision_boxes[index]
		_check(shape.size.is_equal_approx(_vector(declared.size)) and shape.get_center().is_equal_approx(_vector(declared.position)), "compound collision boxes preserve catalog geometry")
	if specification.kind == "motor":
		_check(definition.actuator_torque_nm > 0.0 and definition.actuator_drives_connected_body, "complete motor housing drives a separate connected structural part")
	else:
		_check(definition.actuator_torque_nm == 0.0, "structural and passive modules are not hidden actuators")


func _check_hole(identity: String, hole: Dictionary, ports: Dictionary, faces: PackedVector3Array) -> void:
	var label: String = identity + ":" + String(hole.id)
	var center: Vector3 = _vector(hole.position)
	var normal: Vector3 = _vector(hole.normal)
	var radius: float = float(hole.diameter_m) * 0.5
	_check(is_equal_approx(normal.length(), 1.0), "hole has a unit drilling axis: " + label)
	_check(is_equal_approx(radius, 0.002) or is_equal_approx(radius, 0.004), "hole uses shared bolt or axle diameter: " + label)
	for side: String in ["front", "back"]:
		var key: String = String(hole.id) + "_" + side
		_check(ports.has(key), "real hole has a connectable face: " + label + " " + side)
		if not ports.has(key):
			continue
		var port: Dictionary = ports[key]
		var sign_normal: float = 1.0 if side == "front" else -1.0
		_check(_vector(port.position).distance_to(center + normal * float(hole.thickness_m) * 0.5 * sign_normal) < 0.000001, "hole face anchor is on physical stock surface")
		_check(_vector(port.normal).is_equal_approx(normal * sign_normal) and port.hole_id == hole.id, "hole face normal points out of stock")
	var tangent: Vector3 = normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var bitangent: Vector3 = normal.cross(tangent)
	var half_length: float = float(hole.thickness_m) * 0.5 + 0.0001
	for offset: Vector3 in [Vector3.ZERO, tangent * radius * 0.5, -tangent * radius * 0.5, bitangent * radius * 0.5, -bitangent * radius * 0.5]:
		_check(not _hits_mesh(center + offset - normal * half_length, center + offset + normal * half_length, faces), "visible hole is actually open, not a painted ring: " + label)
	var surrounded: bool = false
	for offset: Vector3 in [tangent, -tangent, bitangent, -bitangent]:
		var wall: Vector3 = center + offset * (radius + 0.001)
		surrounded = surrounded or _hits_mesh(wall - normal * half_length, wall + normal * half_length, faces)
	_check(surrounded, "hole belongs to real surrounding stock: " + label)


func _check_pitch(specification: Dictionary) -> void:
	var holes: Array = specification.holes
	for i: int in holes.size():
		var nearest: float = INF
		for j: int in holes.size():
			if i == j:
				continue
			nearest = minf(nearest, _vector(holes[i].position).distance_to(_vector(holes[j].position)))
		_check(absf(nearest - 0.02) < 0.000001, "beam and plate holes follow interchangeable 20 mm grid: " + specification.id)


func _check_graph(graph: ConnectionGraph, label: String) -> void:
	_check(graph != null and not graph.parts.is_empty(), label + " is a graph, not a joined mesh")
	if graph == null:
		return
	var snapshot: Dictionary = MotionSnapshot.encode(graph)
	_check(not snapshot.is_empty() and MotionSnapshot.decode(snapshot) != null, label + " round-trips through the validated graph snapshot")
	var seen_poses: Dictionary = {}
	for entry: Dictionary in graph.parts:
		var definition: PartDef = entry.part_def
		_check(entry.size() == 2 and entry.has("transform"), "no hidden semantic role or extra assembly authority")
		_check(String(definition.id) == "cargo_box" or _catalog.has(String(definition.id)), label + " uses elementary catalog parts only")
		var identity_pose: String = String(definition.id) + ":" + str(entry.transform)
		_check(not seen_poses.has(identity_pose), "no duplicated stock at identical pose: " + identity_pose)
		seen_poses[identity_pose] = true
	var occupied: Dictionary = {}
	for link: Dictionary in graph.links:
		var a_definition: PartDef = graph.parts[link.a_part].part_def
		var b_definition: PartDef = graph.parts[link.b_part].part_def
		var a: Port = RunMode._port(a_definition, link.a_port)
		var b: Port = RunMode._port(b_definition, link.b_port)
		_check(a != null and b != null and a.kind == b.kind, "graph link resolves same-kind ports")
		if a == null or b == null:
			continue
		_check(a.tag in b.accepts and b.tag in a.accepts, "graph link uses mutually compatible catalog interfaces")
		for key: String in ["%d:%s" % [link.a_part, link.a_port], "%d:%s" % [link.b_part, link.b_port]]:
			_check(not occupied.has(key), "one connection per physical port " + key)
			occupied[key] = true
		if a.kind != Port.Kind.MECH:
			continue
		var a_pose: Transform3D = graph.parts[link.a_part].transform
		var b_pose: Transform3D = graph.parts[link.b_part].transform
		_check((a_pose * a.local_position).distance_to(b_pose * b.local_position) <= 0.00001, "actual surface anchors coincide: %s %d:%s / %d:%s" % [label, link.a_part, a.id, link.b_part, b.id])
		_check((a_pose.basis * a.local_normal).dot(b_pose.basis * b.local_normal) < -0.9999, "connected faces oppose for real snapping")
		if not a.rotates and not b.rotates and _structural(a_definition) and _structural(b_definition):
			_check(not _stocks_intersect(a_definition, a_pose, b_definition, b_pose), "connected structural stock does not interpenetrate: %s %d:%s / %d:%s" % [label, link.a_part, a_definition.id, link.b_part, b_definition.id])
	for i: int in graph.parts.size():
		var a: PartDef = graph.parts[i].part_def
		if _catalog.get(String(a.id), {}).get("kind", "") not in ["beam", "plate", "bracket", "pad"]:
			continue
		for j: int in range(i + 1, graph.parts.size()):
			var b: PartDef = graph.parts[j].part_def
			if _catalog.get(String(b.id), {}).get("kind", "") not in ["beam", "plate", "bracket", "pad"]:
				continue
			_check(not _stocks_intersect(a, graph.parts[i].transform, b, graph.parts[j].transform), "independent structural stock does not overlap elsewhere: %s %d:%s / %d:%s" % [label, i, a.id, j, b.id])


func _check_reuse(humanoid: ConnectionGraph, bridge: ConnectionGraph) -> void:
	var humanoid_ids: Dictionary = {}
	var repeated_kinds: Dictionary = {}
	for entry: Dictionary in humanoid.parts:
		var identity: String = String(entry.part_def.id)
		humanoid_ids[identity] = int(humanoid_ids.get(identity, 0)) + 1
	for identity: String in humanoid_ids:
		if humanoid_ids[identity] >= 2 and _catalog.has(identity):
			repeated_kinds[_catalog[identity].kind] = true
	for kind: String in ["beam", "plate", "bracket", "fastener", "motor"]:
		_check(repeated_kinds.has(kind), "humanoid repeatedly uses interchangeable " + kind + " stock")
	var common: Dictionary = {}
	for entry: Dictionary in bridge.parts:
		var identity: String = String(entry.part_def.id)
		if humanoid_ids.has(identity):
			common[_catalog[identity].kind] = true
	for kind: String in ["beam", "plate", "bracket", "fastener"]:
		_check(common.has(kind), "same " + kind + " catalog IDs are rebuilt as a bridge")
	_check(humanoid.parts.size() > 60 and bridge.parts.size() >= 10, "separate stock and fasteners are authored, not renamed limb groups")


func _check_snapping() -> void:
	var assembly: AssemblyMode = AssemblyMode.new()
	root.add_child(assembly)
	var plate: PartNode = assembly.spawn_part(load(PARTS + "kit_plate_60_40.tres"), Transform3D(Basis(Vector3.UP, 0.35), Vector3(0.3, 0.4, 0.2)))
	var bolt: PartNode = assembly.spawn_part(load(PARTS + "kit_bolt_4.tres"), Transform3D.IDENTITY)
	for target: Port in plate.part_def.ports:
		assembly.unsnap(bolt)
		var basis: Basis = Basis(Quaternion(Vector3.BACK, -plate.get_port_global_normal(target.id)))
		var source: Port = bolt.get_port(&"head_mount")
		bolt.global_transform = Transform3D(basis, plate.get_port_global_position(target.id) - basis * source.local_position + Vector3(0.0003, 0.0002, 0.0001))
		_check(assembly.try_snap(bolt), "nearest-hole snapping works at alternate plate hole " + String(target.id))
		_check(assembly.graph.links.size() == 1, "snapping records only one chosen hole connection")
		if assembly.graph.links.size() != 1:
			continue
		var link: Dictionary = assembly.graph.links[0]
		_check(link.a_port == &"head_mount" and link.b_port == target.id, "nearest actual face wins among the plate's twelve interfaces")
		_check(bolt.get_port_global_position(&"head_mount").distance_to(plate.get_port_global_position(target.id)) < 0.000001, "alternate mounting updates exact graph-space anchor")
		_check(bolt.get_port_global_normal(&"head_mount").dot(plate.get_port_global_normal(target.id)) < -0.9999, "alternate mounting automatically aligns opposing faces")
		_check(assembly.graph.parts[bolt.graph_index].transform.is_equal_approx(bolt.global_transform), "snapped transform is authored into ConnectionGraph")
	assembly.free()


func _check_physics(graph: ConnectionGraph) -> void:
	var hardware: RunMode = RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var groups: Dictionary = {}
	var graph_mass: float = 0.0
	var body_mass: float = 0.0
	var expected_shapes: int = 0
	for index: int in graph.parts.size():
		var definition: PartDef = graph.parts[index].part_def
		var body: RigidBody3D = hardware.bodies[index]
		graph_mass += definition.mass_kg
		expected_shapes += maxi(1, definition.collision_boxes.size())
		_check(hardware.part_global_transform(index).is_equal_approx(graph.parts[index].transform), "fixed merging preserves every graph part world transform")
		_check(body.gravity_scale == 1.0 and not body.freeze, "derived construction parts retain gravity")
		if not groups.has(body):
			groups[body] = []
			body_mass += body.mass
		groups[body].append(index)
		var matched: bool = false
		for child: Node in body.get_children():
			if child is MeshInstance3D and child.mesh == definition.mesh and child.global_transform.is_equal_approx(graph.parts[index].transform):
				matched = true
		_check(matched, "merged solver body still renders the independent stock at its graph pose")
	_check(is_equal_approx(graph_mass, body_mass), "fixed components preserve summed physical mass")
	var shapes: int = 0
	var meshes: int = 0
	for body: RigidBody3D in groups:
		var expected_mass: float = 0.0
		for index: int in groups[body]:
			expected_mass += graph.parts[index].part_def.mass_kg
		_check(is_equal_approx(body.mass, expected_mass), "each solver component mass equals only its graph members")
		for child: Node in body.get_children():
			shapes += 1 if child is CollisionShape3D else 0
			meshes += 1 if child is MeshInstance3D else 0
	_check(shapes == expected_shapes and meshes == graph.parts.size(), "fixed merging keeps all collision geometry and separate visual meshes")
	for link: Dictionary in graph.links:
		var a: Port = RunMode._port(graph.parts[link.a_part].part_def, link.a_port)
		var b: Port = RunMode._port(graph.parts[link.b_part].part_def, link.b_port)
		if a.kind == Port.Kind.MECH:
			_check((hardware.bodies[link.a_part] == hardware.bodies[link.b_part]) == (not a.rotates and not b.rotates), "only graph-fixed components merge, rotating output stays separate")
	hardware.teardown()
	_check(hardware.bodies.is_empty() and hardware.servos.is_empty() and hardware.get_child_count() == 0, "teardown removes derived clusters without destroying graph parts")
	hardware.free()


func _check_wiring(graph: ConnectionGraph) -> void:
	var wires: Array[Dictionary] = []
	for link: Dictionary in graph.links:
		var a: Port = RunMode._port(graph.parts[link.a_part].part_def, link.a_port)
		if a.kind == Port.Kind.ELEC:
			wires.append(link)
	_check(wires.size() == 10, "ten generic motors are separately wired")
	if wires.size() < 2:
		return
	var a_board_side: String = "a" if Wiring.pin_number(RunMode._port(graph.parts[wires[0].a_part].part_def, wires[0].a_port)) >= 0 else "b"
	var b_board_side: String = "a" if Wiring.pin_number(RunMode._port(graph.parts[wires[1].a_part].part_def, wires[1].a_port)) >= 0 else "b"
	var old_port: StringName = wires[0][a_board_side + "_port"]
	wires[0][a_board_side + "_port"] = wires[1][b_board_side + "_port"]
	wires[1][b_board_side + "_port"] = old_port
	var hardware: RunMode = RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var motion: KitHumanoidMotion = KitHumanoidMotion.new()
	root.add_child(motion)
	_check(motion.configure(hardware, graph), "generic kit topology remains recognized after rewiring")
	var source: String = ConstructionKitHumanoidPreset.answer_code(graph)
	for channel: Dictionary in hardware.wired_servo_channels():
		_check(source.contains("Servo(%d)" % channel.pin), "learner source derives actual graph pin addresses")
		_check(hardware.servo_on_pin(channel.pin) == hardware.servos[channel.part], "wiring resolves the separately assembled motor")
	for role: String in motion.role_pins:
		_check(hardware.servo_on_pin(motion.role_pins[role]) == motion._drives[role], "motion roles follow rewired graph, not fixed pins")
	motion.free()
	hardware.free()


func _check_bridge_stability(graph: ConnectionGraph) -> void:
	var floor: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4.0, 0.10, 4.0)
	collider.shape = shape
	floor.add_child(collider)
	floor.position.y = HumanoidPreset.FLOOR_TOP - 0.05
	root.add_child(floor)
	var hardware: RunMode = RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var minimum_upright: float = 1.0
	var finite: bool = true
	for frame: int in range(180):
		await physics_frame
		var deck: Transform3D = hardware.part_global_transform(0)
		minimum_upright = minf(minimum_upright, deck.basis.z.normalized().dot(Vector3.UP))
		finite = finite and deck.is_finite() and hardware.bodies[0].linear_velocity.is_finite()
	_check(finite, "alternative bridge remains finite while settling under gravity")
	_check(not hardware.bodies[0].freeze and hardware.bodies[0].gravity_scale == 1.0, "bridge stability is not manufactured by anchoring or gravity suppression")
	_check(minimum_upright > 0.95, "bridge built from the same parts stays upright for three seconds")
	_check(hardware.part_global_transform(0).origin.y > HumanoidPreset.FLOOR_TOP + 0.04, "bridge deck remains supported above the floor")
	print("construction_bridge_metrics: min_upright=%.6f deck_height=%.6f" % [minimum_upright, hardware.part_global_transform(0).origin.y])
	hardware.free()
	floor.free()


func _structural(definition: PartDef) -> bool:
	var specification: Dictionary = _catalog.get(String(definition.id), {})
	return specification.get("kind", "") in STRUCTURAL_KINDS


func _stocks_intersect(a: PartDef, a_pose: Transform3D, b: PartDef, b_pose: Transform3D) -> bool:
	for a_box: AABB in a.collision_boxes:
		for b_box: AABB in b.collision_boxes:
			if _boxes_intersect(a_box, a_pose, b_box, b_pose):
				return true
	return false


func _boxes_intersect(a: AABB, a_pose: Transform3D, b: AABB, b_pose: Transform3D) -> bool:
	var a_axes: Array[Vector3] = [a_pose.basis.x, a_pose.basis.y, a_pose.basis.z]
	var b_axes: Array[Vector3] = [b_pose.basis.x, b_pose.basis.y, b_pose.basis.z]
	var axes: Array[Vector3] = a_axes.duplicate()
	axes.append_array(b_axes)
	for a_axis: Vector3 in a_axes:
		for b_axis: Vector3 in b_axes:
			var cross: Vector3 = a_axis.cross(b_axis)
			if cross.length_squared() > 0.000001:
				axes.append(cross.normalized())
	var difference: Vector3 = a_pose * a.get_center() - b_pose * b.get_center()
	for axis: Vector3 in axes:
		var a_radius: float = 0.0
		var b_radius: float = 0.0
		for i: int in range(3):
			a_radius += a.size[i] * 0.5 * absf(axis.dot(a_axes[i]))
			b_radius += b.size[i] * 0.5 * absf(axis.dot(b_axes[i]))
		if absf(axis.dot(difference)) >= a_radius + b_radius - 0.0001:
			return false
	return true


func _hits_mesh(from: Vector3, to: Vector3, faces: PackedVector3Array) -> bool:
	# Millimetres avoid the engine triangle intersection epsilon at tiny bolt-hole scale.
	for index: int in range(0, faces.size(), 3):
		if Geometry3D.segment_intersects_triangle(from * 1000.0, to * 1000.0, faces[index] * 1000.0, faces[index + 1] * 1000.0, faces[index + 2] * 1000.0) != null:
			return true
	return false


func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
