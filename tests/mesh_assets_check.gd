extends SceneTree

## Checks imported palette meshes, accessory snapping and the complete powered biped answer.
## godot --headless --path . -s tests/mesh_assets_check.gd
## Pass -- --baseline before generating new assets to report the original biped measurements.

const MAX_TRIANGLES: int = 5000
const ACCESSORY_IDS: Array[StringName] = [&"chassis_plate", &"servo_bracket"]

var _failures: Array[String] = []
var _definitions: Array[PartDef] = []
var _run_mode: RunMode
var _runtime: MiniRuntime
var _runtime_finished: bool = false
var _runtime_error: String = ""
var _initial_body_height: float = 0.0
var _minimum_body_height: float = INF
var _invalid_motion: bool = false
var _baseline: bool = false


func _initialize() -> void:
	_baseline = "--baseline" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	_check_palette()
	if not _baseline:
		_check_accessories()
	var graph: ConnectionGraph = BipedPreset.build()
	_check_graph(graph, "biped")
	await _check_biped(graph)
	print("mesh_assets_check: %d failure(s)" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _check_palette() -> void:
	var directory: DirAccess = DirAccess.open("res://assets/parts")
	_check(directory != null, "palette directory exists")
	if directory == null:
		return
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for filename: String in files:
		if not filename.ends_with(".tres"):
			continue
		var definition: PartDef = load("res://assets/parts/" + filename) as PartDef
		_check(definition != null, "%s loads as PartDef" % filename)
		if definition == null:
			continue
		_definitions.append(definition)
		var mesh: ArrayMesh = definition.mesh as ArrayMesh
		_check(mesh != null, "%s uses an imported ArrayMesh" % definition.id)
		if mesh == null:
			continue
		var valid: bool = mesh.get_surface_count() > 0
		var triangles: int = 0
		for surface: int in mesh.get_surface_count():
			valid = valid and mesh.surface_get_material(surface) != null
			valid = valid and mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			valid = valid and not vertices.is_empty() and normals.size() == vertices.size()
			for vertex: Vector3 in vertices:
				valid = valid and vertex.is_finite()
			for normal: Vector3 in normals:
				valid = valid and normal.is_finite() and normal.length_squared() > 0.5
			var count: int = vertices.size() if indices.is_empty() else indices.size()
			valid = valid and count % 3 == 0
			triangles += count / 3
			for index: int in indices:
				valid = valid and index >= 0 and index < vertices.size()
			if valid:
				for corner: int in range(0, count, 3):
					var a: Vector3 = vertices[corner if indices.is_empty() else indices[corner]]
					var b: Vector3 = vertices[corner + 1 if indices.is_empty() else indices[corner + 1]]
					var c: Vector3 = vertices[corner + 2 if indices.is_empty() else indices[corner + 2]]
					valid = valid and (b - a).cross(c - a).length_squared() > 1e-24
		var bounds: AABB = mesh.get_aabb()
		valid = valid and bounds.position.is_finite() and bounds.size.is_finite()
		valid = valid and bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.size.z > 0.0
		_check(valid, "%s has valid triangle geometry, normals and materials" % definition.id)
		_check(triangles > 0 and triangles < MAX_TRIANGLES,
			"%s: %d triangles (< %d), %d surfaces" % [definition.id, triangles, MAX_TRIANGLES, mesh.get_surface_count()])
	_check(_definitions.size() >= 11, "all existing palette parts are present")


func _check_accessories() -> void:
	for accessory_id: StringName in ACCESSORY_IDS:
		var definition: PartDef = _definition(accessory_id)
		_check(definition != null, "%s is available in the palette" % accessory_id)
		if definition == null:
			continue
		var tested_ports: int = 0
		for port: Port in definition.ports:
			if port.kind != Port.Kind.MECH:
				continue
			var partner: Dictionary = _find_partner(definition, port)
			_check(not partner.is_empty(), "%s.%s has a compatible palette part" % [definition.id, port.id])
			if partner.is_empty():
				continue
			var assembly: AssemblyMode = AssemblyMode.new()
			root.add_child(assembly)
			assembly.snap_radius = 0.0005
			var fixed: PartNode = assembly.spawn_part(definition, Transform3D.IDENTITY)
			var partner_port: Port = partner.port
			var rotation: Basis = Basis(Quaternion(partner_port.local_normal, -port.local_normal))
			var origin: Vector3 = port.local_position - rotation * partner_port.local_position + Vector3(0.0001, 0, 0)
			var moving: PartNode = assembly.spawn_part(partner.definition, Transform3D(rotation, origin))
			_check(assembly.try_snap(moving), "%s.%s proximity snaps to %s.%s" % [definition.id, port.id, moving.part_def.id, partner_port.id])
			_check(assembly.graph.links.size() == 1, "accessory snap creates exactly one ConnectionGraph link")
			_check_graph(assembly.graph, "%s.%s" % [definition.id, port.id])
			_check(fixed.get_port_global_position(port.id).distance_to(moving.get_port_global_position(partner_port.id)) < 0.00001,
				"accessory snap aligns the selected port positions")
			assembly.free()
			tested_ports += 1
		_check(tested_ports > 0, "%s has tested mechanical ports" % accessory_id)


func _find_partner(definition: PartDef, port: Port) -> Dictionary:
	for candidate: PartDef in _definitions:
		if candidate == definition or candidate.id in ACCESSORY_IDS:
			continue
		for other: Port in candidate.ports:
			if other.kind == port.kind and (port.tag in other.accepts or other.tag in port.accepts):
				return {"definition": candidate, "port": other}
	return {}


func _definition(id: StringName) -> PartDef:
	for definition: PartDef in _definitions:
		if definition.id == id:
			return definition
	return null


func _check_graph(graph: ConnectionGraph, label: String) -> void:
	var valid: bool = true
	for link: Dictionary in graph.links:
		var first: Dictionary = graph.parts[link.a_part]
		var second: Dictionary = graph.parts[link.b_part]
		var first_port: Port = RunMode._port(first.part_def, link.a_port)
		var second_port: Port = RunMode._port(second.part_def, link.b_port)
		valid = valid and first_port != null and second_port != null
		if first_port == null or second_port == null:
			continue
		valid = valid and first_port.kind == second_port.kind
		valid = valid and (first_port.tag in second_port.accepts or second_port.tag in first_port.accepts)
		if first_port.kind == Port.Kind.MECH:
			var first_position: Vector3 = first.transform * first_port.local_position
			var second_position: Vector3 = second.transform * second_port.local_position
			var first_normal: Vector3 = first.transform.basis * first_port.local_normal
			var second_normal: Vector3 = second.transform.basis * second_port.local_normal
			valid = valid and first_position.distance_to(second_position) < 0.00001
			valid = valid and first_normal.dot(second_normal) < -0.999
	_check(valid, "%s ConnectionGraph links have compatible, aligned ports" % label)


func _check_biped(graph: ConnectionGraph) -> void:
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0, 0.05, 2.0)
	collision.shape = box
	floor.add_child(collision)
	floor.position.y = BipedPreset.FLOOR_TOP - box.size.y * 0.5
	root.add_child(floor)
	_run_mode = RunMode.new()
	root.add_child(_run_mode)
	_run_mode.build(graph)
	_check(_run_mode.bodies.size() == 11 and _run_mode.servos.size() == 4, "biped builds 11 bodies and 4 servo drives")
	for pin: int in [3, 5, 6, 9]:
		_check(_run_mode.servo_on_pin(pin) != null, "biped wiring resolves PWM pin %d" % pin)
	_initial_body_height = _run_mode.bodies[0].global_position.y - BipedPreset.FLOOR_TOP
	_runtime = MiniRuntime.new()
	_runtime.hardware = _run_mode
	root.add_child(_runtime)
	_runtime.finished.connect(func() -> void: _runtime_finished = true)
	_runtime.failed.connect(func(line: int, message: String) -> void: _runtime_error = "line %d: %s" % [line, message])
	physics_frame.connect(_sample_biped)
	_runtime.run(BipedPreset.ANSWER_CODE)
	var deadline: int = Time.get_ticks_msec() + 10000
	while not _runtime_finished and _runtime_error.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	await create_timer(0.5).timeout
	physics_frame.disconnect(_sample_biped)
	var final_height: float = _run_mode.bodies[0].global_position.y - BipedPreset.FLOOR_TOP
	var upright: float = _run_mode.bodies[0].global_basis.y.dot(Vector3.UP)
	print("BIPED_MEASUREMENTS initial_height=%.5f minimum_height=%.5f final_height=%.5f upright=%.5f" % [_initial_body_height, _minimum_body_height, final_height, upright])
	_check(_runtime_finished and _runtime_error.is_empty(), "complete powered biped answer finishes without runtime errors: %s" % _runtime_error)
	_check(not _invalid_motion, "all biped transforms and velocities stay finite and near the work surface")
	# Feet roll during the answer; retain enough body height to catch falls or oversized collision hulls.
	_check(final_height > _initial_body_height * 0.7 and final_height < _initial_body_height * 1.3,
		"biped finishes at a reasonable standing height (%.5f m)" % final_height)
	_run_mode.teardown()
	_runtime.free()
	_run_mode.free()
	floor.free()


func _sample_biped() -> void:
	_minimum_body_height = minf(_minimum_body_height, _run_mode.bodies[0].global_position.y - BipedPreset.FLOOR_TOP)
	for body: RigidBody3D in _run_mode.bodies:
		_invalid_motion = _invalid_motion or not body.global_position.is_finite() or not body.global_basis.is_finite()
		_invalid_motion = _invalid_motion or not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite()
		_invalid_motion = _invalid_motion or body.global_position.length() > 2.0


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failures.append(message)
