class_name WireVisuals
extends Node3D

## Draws every electrical link of the graph as a 3D cable and marks ports that need
## attention. Purely derived from the graph and the power report; it never edits either.
## Power cables are warm and thick, signal wires cool and thin, so the kinds differ by
## shape as well as colour.

const POWER_RADIUS := 0.0016
const SIGNAL_RADIUS := 0.0009
const FOCUS_SCALE := 1.9
const LIFT := 0.012
const SEGMENTS := 14
const SIDES := 6
const MARKER_RADIUS := 0.0035

var cables: MeshInstance3D
var markers: MultiMeshInstance3D
## Endpoints the learner is pointing at: [{ "part": int, "port": StringName }].
var focus: Array[Dictionary] = []
## Endpoints with an electrical problem, e.g. an unpowered power_in port.
var problems: Array[Dictionary] = []
var _graph: ConnectionGraph
var _run_mode: RunMode
var _signature: int = 0
var _wires: Array[Dictionary] = []


func _init() -> void:
	cables = MeshInstance3D.new()
	cables.name = "WireCables"
	cables.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cable_material := StandardMaterial3D.new()
	cable_material.vertex_color_use_as_albedo = true
	cable_material.roughness = 0.55
	cable_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cables.material_override = cable_material
	add_child(cables)
	markers = MultiMeshInstance3D.new()
	markers.name = "PortHighlights"
	markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var marker_material := StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.vertex_color_use_as_albedo = true
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Highlights must stay visible through the parts that hide them.
	marker_material.no_depth_test = true
	marker_material.render_priority = 1
	markers.material_override = marker_material
	var sphere := SphereMesh.new()
	sphere.radius = MARKER_RADIUS
	sphere.height = MARKER_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = sphere
	markers.multimesh = instances
	add_child(markers)


static func is_power_port(port: Port) -> bool:
	return port != null and port.tag in WiringPanel.POWER_TAGS


func set_run_mode(run: RunMode) -> void:
	_run_mode = run
	_signature = 0


func refresh(graph: ConnectionGraph, force: bool = false) -> void:
	var running: bool = is_instance_valid(_run_mode) and _run_mode.is_built()
	var signature: int = hash([graph.parts, graph.links, focus, problems, SsokTheme.POWER_WIRE, SsokTheme.ERROR, running])
	if not force and not running and _graph == graph and signature == _signature:
		return
	_graph = graph
	_signature = signature
	_collect_wires()
	_rebuild()


func _process(_delta: float) -> void:
	if _graph != null and is_instance_valid(_run_mode) and _run_mode.is_built():
		_rebuild()


func wire_count() -> int:
	return _wires.size()


func power_wire_count() -> int:
	return _wires.filter(func(wire: Dictionary) -> bool: return wire.power).size()


func highlighted_wire_count() -> int:
	return _wires.filter(func(wire: Dictionary) -> bool: return wire.focused).size()


func marker_count() -> int:
	return markers.multimesh.instance_count


## The colour a wire is drawn with; exposed so checks can verify the kinds differ.
static func wire_color(power: bool) -> Color:
	return SsokTheme.POWER_WIRE if power else SsokTheme.SIGNAL_WIRE


func _collect_wires() -> void:
	_wires.clear()
	for link: Dictionary in _graph.links:
		var a: Port = _port(link.a_part, link.a_port)
		var b: Port = _port(link.b_part, link.b_port)
		if a == null or b == null or a.kind != Port.Kind.ELEC:
			continue
		var a_end: Dictionary = {"part": link.a_part, "port": link.a_port}
		var b_end: Dictionary = {"part": link.b_part, "port": link.b_port}
		var focused: bool = a_end in focus or b_end in focus
		var broken: bool = a_end in problems or b_end in problems
		_wires.append({"a": a_end, "b": b_end, "power": is_power_port(a) or is_power_port(b), "focused": focused, "broken": broken})


func _rebuild() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for wire: Dictionary in _wires:
		var start: Array = _endpoint(wire.a)
		var finish: Array = _endpoint(wire.b)
		var color: Color = wire_color(wire.power)
		if wire.broken:
			color = SsokTheme.ERROR
		elif wire.focused:
			color = color.lightened(0.35) if SsokTheme.dark else color.darkened(0.25)
		var radius: float = POWER_RADIUS if wire.power else SIGNAL_RADIUS
		if wire.focused or wire.broken:
			radius *= FOCUS_SCALE
		_append_tube(start[0], start[0] + start[1] * LIFT, finish[0] + finish[1] * LIFT, finish[0], radius, color, vertices, normals, colors, indices)
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cables.mesh = mesh
	var shown: Array[Dictionary] = []
	for endpoint: Dictionary in problems:
		shown.append({"end": endpoint, "color": Color(SsokTheme.ERROR, 0.9), "scale": 1.4})
	for endpoint: Dictionary in focus:
		if endpoint not in problems:
			shown.append({"end": endpoint, "color": Color(SsokTheme.ACCENT, 0.85), "scale": 1.0})
	markers.multimesh.instance_count = shown.size()
	for index: int in shown.size():
		var point: Array = _endpoint(shown[index].end)
		markers.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * shown[index].scale), point[0]))
		markers.multimesh.set_instance_color(index, shown[index].color)


## Returns [position, outward normal] of a port in this node's space.
func _endpoint(endpoint: Dictionary) -> Array:
	var part: int = endpoint.part
	var port: Port = _port(part, endpoint.port)
	if port == null:
		return [Vector3.ZERO, Vector3.UP]
	var pose: Transform3D = _graph.parts[part].transform
	if is_instance_valid(_run_mode) and _run_mode.is_built() and part < _run_mode.bodies.size():
		pose = global_transform.affine_inverse() * _run_mode.part_global_transform(part)
	var normal: Vector3 = (pose.basis * port.local_normal).normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	return [pose * port.local_position, normal]


func _append_tube(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, radius: float, color: Color, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var base: int = vertices.size()
	var previous_side := Vector3.ZERO
	for step: int in SEGMENTS + 1:
		var t: float = float(step) / float(SEGMENTS)
		var point: Vector3 = p0.bezier_interpolate(p1, p2, p3, t)
		var tangent: Vector3 = p0.bezier_derivative(p1, p2, p3, t)
		if tangent.is_zero_approx():
			tangent = p3 - p0
		tangent = tangent.normalized() if not tangent.is_zero_approx() else Vector3.RIGHT
		# Parallel-transport the ring frame so the tube does not twist.
		var side: Vector3 = previous_side - tangent * previous_side.dot(tangent)
		if side.length_squared() < 1e-8:
			side = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT)
		side = side.normalized()
		previous_side = side
		var up: Vector3 = tangent.cross(side).normalized()
		for corner: int in SIDES:
			var angle: float = TAU * float(corner) / float(SIDES)
			var normal: Vector3 = side * cos(angle) + up * sin(angle)
			vertices.append(point + normal * radius)
			normals.append(normal)
			colors.append(color)
	for step: int in SEGMENTS:
		for corner: int in SIDES:
			var next: int = (corner + 1) % SIDES
			var a: int = base + step * SIDES + corner
			var b: int = base + step * SIDES + next
			var c: int = base + (step + 1) * SIDES + corner
			var d: int = base + (step + 1) * SIDES + next
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))


func _port(part: int, id: StringName) -> Port:
	if _graph == null or part < 0 or part >= _graph.parts.size():
		return null
	for port: Port in _graph.parts[part].part_def.ports:
		if port.id == id:
			return port
	return null
