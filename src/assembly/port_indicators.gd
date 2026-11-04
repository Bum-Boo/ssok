class_name PortIndicators
extends Node3D

## Derived visual hints only. The graph remains the authority for occupancy.
const RING_OUTER_RADIUS := 0.0032
const RING_INNER_RADIUS := 0.0022
const FACE_OFFSET := 0.0003
const BOLT_RADIUS := 0.0035
const BOLT_HEIGHT := 0.0025
const RING_SEGMENTS := 32

var rings: MultiMeshInstance3D
var bolts: MultiMeshInstance3D
var _graph: ConnectionGraph
var _graph_signature: int = 0
var _ring_signature: int = 0
var _free_ports: Array[Dictionary] = []
var _bolt_ports: Array[Dictionary] = []
var _run_mode: RunMode


func _init() -> void:
	rings = MultiMeshInstance3D.new()
	rings.name = "FreeHoleRings"
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.vertex_color_use_as_albedo = true
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rings.material_override = ring_material
	rings.multimesh = _multimesh(_ring_mesh(), true)
	rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rings)
	bolts = MultiMeshInstance3D.new()
	bolts.name = "LinkedHoleBolts"
	var head := CylinderMesh.new()
	head.top_radius = BOLT_RADIUS
	head.bottom_radius = BOLT_RADIUS
	head.height = BOLT_HEIGHT
	head.radial_segments = 6
	bolts.multimesh = _multimesh(head, false)
	var metal: StandardMaterial3D = load("res://assets/materials/chassis_metal.tres").duplicate()
	metal.albedo_color = metal.albedo_color.lightened(0.18)
	bolts.material_override = metal
	add_child(bolts)


func refresh(graph: ConnectionGraph, selected_index: int = -1, placement: Dictionary = {}, running: bool = false) -> void:
	var graph_signature: int = hash([graph.parts, graph.links])
	if _graph != graph or _graph_signature != graph_signature:
		_graph = graph
		_graph_signature = graph_signature
		_rebuild_graph()
		_ring_signature = 0
	var signature: int = hash([graph_signature, selected_index, placement.get("active", false), placement.get("moving_part", -1), placement.get("target_part", -1), placement.get("target_port", &""), SsokTheme.ACCENT, SsokTheme.SHAFT])
	if signature != _ring_signature:
		_ring_signature = signature
		_update_rings(selected_index, placement)
	rings.visible = not running and _run_mode == null


func set_run_mode(run: RunMode) -> void:
	_run_mode = run
	rings.visible = run == null
	_update_bolt_transforms()


func ring_count() -> int:
	return rings.multimesh.instance_count


func bolt_count() -> int:
	return bolts.multimesh.instance_count


func apply_theme() -> void:
	# refresh() incorporates the current semantic palette in its cache key.
	_ring_signature = 0


func _process(_delta: float) -> void:
	if is_instance_valid(_run_mode) and _run_mode.is_built():
		_update_bolt_transforms()


func _rebuild_graph() -> void:
	_free_ports.clear()
	_bolt_ports.clear()
	var occupied: Dictionary = {}
	for link: Dictionary in _graph.links:
		occupied[_key(link.a_part, link.a_port)] = true
		occupied[_key(link.b_part, link.b_port)] = true
		var a: Port = _port(link.a_part, link.a_port)
		var b: Port = _port(link.b_part, link.b_port)
		if a == null or b == null or a.tag != &"kit_m4" or b.tag != &"kit_m4":
			continue
		# Choose a stable outward-facing endpoint once, rather than flickering
		# between the two coincident faces as the viewing camera moves.
		var a_transform: Transform3D = _graph.parts[link.a_part].transform
		var b_transform: Transform3D = _graph.parts[link.b_part].transform
		var a_normal: Vector3 = a_transform.basis * a.local_normal
		var b_normal: Vector3 = b_transform.basis * b.local_normal
		var front := Vector3(0.13, 1.0, 0.31).normalized()
		var endpoint: Dictionary = {"part": link.a_part, "port": a} if a_normal.dot(front) >= b_normal.dot(front) else {"part": link.b_part, "port": b}
		_bolt_ports.append(_exterior_bolt_face(link, endpoint))
	for index: int in _graph.parts.size():
		var definition: PartDef = _graph.parts[index].part_def
		for port: Port in definition.ports:
			if port.kind == Port.Kind.MECH and not occupied.has(_key(index, port.id)):
				_free_ports.append({"part": index, "port": port})
	bolts.multimesh.instance_count = _bolt_ports.size()
	_update_bolt_transforms()


func _exterior_bolt_face(link: Dictionary, endpoint: Dictionary) -> Dictionary:
	var pose: Transform3D = _graph.parts[endpoint.part].transform
	var port: Port = endpoint.port
	var normal: Vector3 = (pose.basis * port.local_normal).normalized()
	var center: Vector3 = pose * port.local_position
	var outer_distance: float = center.dot(normal)
	# The two linked faces touch inside the joint. Draw the head on the
	# corresponding outer face of that same bore so the adjacent part cannot
	# bury it. This is a derived visual position, never another graph link.
	for part: int in [link.a_part, link.b_part]:
		var definition: PartDef = _graph.parts[part].part_def
		var candidate_pose: Transform3D = _graph.parts[part].transform
		for candidate: Port in definition.ports:
			if candidate.tag != &"kit_m4" or (candidate_pose.basis * candidate.local_normal).normalized().dot(normal) < 0.99:
				continue
			var point: Vector3 = candidate_pose * candidate.local_position
			var offset: Vector3 = point - center
			if (offset - normal * offset.dot(normal)).length() > 0.0005:
				continue
			if point.dot(normal) > outer_distance:
				outer_distance = point.dot(normal)
				endpoint = {"part": part, "port": candidate}
	return endpoint


func _update_rings(selected_index: int, placement: Dictionary) -> void:
	var shown: Array[Dictionary] = []
	for entry: Dictionary in _free_ports:
		if placement.get("active", false) and entry.part == placement.get("moving_part", -1):
			continue
		if placement.get("active", false) or entry.part == selected_index:
			shown.append(entry)
	rings.multimesh.instance_count = shown.size()
	for index: int in shown.size():
		var entry: Dictionary = shown[index]
		var port: Port = entry.port
		var pose: Transform3D = _graph.parts[entry.part].transform
		var target: bool = entry.part == placement.get("target_part", -1) and port.id == placement.get("target_port", &"")
		var shaft: bool = port.rotates or String(port.tag).contains("shaft") or String(port.tag).contains("axle") or String(port.tag).contains("hub")
		var color: Color = Color(SsokTheme.SHAFT, 0.7) if shaft else Color(SsokTheme.ACCENT, 0.55)
		if target:
			color = SsokTheme.ACCENT
		var local_pose := _port_pose(port, FACE_OFFSET)
		if target:
			local_pose.basis = local_pose.basis.scaled(Vector3.ONE * 1.6)
		rings.multimesh.set_instance_transform(index, pose * local_pose)
		rings.multimesh.set_instance_color(index, color)


func _update_bolt_transforms() -> void:
	if _graph == null:
		return
	for index: int in _bolt_ports.size():
		var entry: Dictionary = _bolt_ports[index]
		var pose: Transform3D = _graph.parts[entry.part].transform
		if is_instance_valid(_run_mode) and _run_mode.is_built() and entry.part < _run_mode.bodies.size():
			pose = global_transform.affine_inverse() * _run_mode.part_global_transform(entry.part)
		bolts.multimesh.set_instance_transform(index, pose * _port_pose(entry.port, BOLT_HEIGHT * 0.5))


func _port(part: int, id: StringName) -> Port:
	if part < 0 or part >= _graph.parts.size():
		return null
	var definition: PartDef = _graph.parts[part].part_def
	for port: Port in definition.ports:
		if port.id == id:
			return port
	return null


func _key(part: int, port: StringName) -> String:
	return "%d:%s" % [part, port]


func _port_pose(port: Port, offset: float) -> Transform3D:
	var normal: Vector3 = port.local_normal.normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	return Transform3D(Basis(Quaternion(Vector3.UP, normal)), port.local_position + normal * offset)


func _multimesh(mesh: Mesh, colors: bool) -> MultiMesh:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = colors
	instances.mesh = mesh
	return instances


func _ring_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for segment: int in RING_SEGMENTS:
		var angle: float = TAU * float(segment) / float(RING_SEGMENTS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(direction * RING_OUTER_RADIUS)
		vertices.append(direction * RING_INNER_RADIUS)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		var next: int = ((segment + 1) % RING_SEGMENTS) * 2
		var current: int = segment * 2
		indices.append_array(PackedInt32Array([current, next + 1, next, current, current + 1, next + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
