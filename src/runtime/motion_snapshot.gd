class_name MotionSnapshot
extends RefCounted

## Only catalog IDs and graph data cross the bridge; resource paths never do.

const CATALOG_PATH: String = "res://assets/parts/"
const MAX_PARTS: int = 64
const MAX_LINKS: int = 128
const MAX_POSITION: float = 100.0
const RIGID_TOLERANCE: float = 0.0001


static func encode(graph: ConnectionGraph) -> Dictionary:
	if graph == null or graph.parts.size() > MAX_PARTS or graph.links.size() > MAX_LINKS:
		return {}
	var parts: Array[Dictionary] = []
	for entry: Dictionary in graph.parts:
		if not entry.get("part_def") is PartDef or not entry.get("transform") is Transform3D:
			return {}
		var definition: PartDef = entry.part_def
		var pose: Transform3D = entry.transform
		var values: Array[float] = []
		for column: Vector3 in [pose.basis.x, pose.basis.y, pose.basis.z, pose.origin]:
			values.append_array([column.x, column.y, column.z])
		parts.append({"id": String(definition.id), "transform": values})
	var links: Array[Dictionary] = []
	for link: Dictionary in graph.links:
		if not _exact_keys(link, ["a_part", "a_port", "b_part", "b_port"]):
			return {}
		links.append({"a_part": link.a_part, "a_port": String(link.a_port), "b_part": link.b_part, "b_port": String(link.b_port)})
	var result: Dictionary = {"version": 1, "parts": parts, "links": links}
	return result if decode(result) != null else {}


static func decode(data: Variant) -> ConnectionGraph:
	if not data is Dictionary or not _exact_keys(data, ["version", "parts", "links"]):
		return null
	if not _is_integer(data.version) or int(data.version) != 1:
		return null
	if not data.parts is Array or not data.links is Array:
		return null
	if data.parts.is_empty() or data.parts.size() > MAX_PARTS or data.links.size() > MAX_LINKS:
		return null
	var catalog: Dictionary = _catalog()
	var graph: ConnectionGraph = ConnectionGraph.new()
	for entry: Variant in data.parts:
		if not entry is Dictionary or not _exact_keys(entry, ["id", "transform"]):
			return null
		if not entry.id is String or not catalog.has(entry.id):
			return null
		if not entry.transform is Array or entry.transform.size() != 12:
			return null
		for number: Variant in entry.transform:
			if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)):
				return null
		var values: Array = entry.transform
		var basis: Basis = Basis(Vector3(values[0], values[1], values[2]), Vector3(values[3], values[4], values[5]), Vector3(values[6], values[7], values[8]))
		var origin: Vector3 = Vector3(values[9], values[10], values[11])
		if not _is_rigid(basis) or not origin.is_finite():
			return null
		if maxf(absf(origin.x), maxf(absf(origin.y), absf(origin.z))) > MAX_POSITION:
			return null
		graph.parts.append({"part_def": catalog[entry.id], "transform": Transform3D(basis, origin)})
	var occupied: Dictionary = {}
	for entry: Variant in data.links:
		if not entry is Dictionary or not _exact_keys(entry, ["a_part", "a_port", "b_part", "b_port"]):
			return null
		if not _is_integer(entry.a_part) or not _is_integer(entry.b_part):
			return null
		var a_index: int = int(entry.a_part)
		var b_index: int = int(entry.b_part)
		if a_index < 0 or b_index < 0 or a_index >= graph.parts.size() or b_index >= graph.parts.size() or a_index == b_index:
			return null
		if not entry.a_port is String or not entry.b_port is String:
			return null
		var a_port: Port = _find_port(graph.parts[a_index].part_def, entry.a_port)
		var b_port: Port = _find_port(graph.parts[b_index].part_def, entry.b_port)
		if a_port == null or b_port == null or a_port.kind != b_port.kind:
			return null
		if b_port.tag not in a_port.accepts or a_port.tag not in b_port.accepts:
			return null
		var a_key: String = "%d:%s" % [a_index, entry.a_port]
		var b_key: String = "%d:%s" % [b_index, entry.b_port]
		if occupied.has(a_key) or occupied.has(b_key):
			return null
		occupied[a_key] = true
		occupied[b_key] = true
		graph.links.append({"a_part": a_index, "a_port": StringName(entry.a_port), "b_part": b_index, "b_port": StringName(entry.b_port)})
	return graph


static func fingerprint(data: Dictionary) -> String:
	var graph: ConnectionGraph = decode(data)
	if graph == null:
		return ""
	# Even sub-micrometre pose changes can alter contact dynamics; never round identity.
	return JSON.stringify(encode(graph), "", true, true).sha256_text()


static func _catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for file: String in ResourceLoader.list_directory(CATALOG_PATH):
		if not file.ends_with(".tres") or file.contains("/"):
			continue
		var definition: PartDef = load(CATALOG_PATH + file) as PartDef
		if definition != null:
			catalog[String(definition.id)] = definition
	return catalog


static func _is_rigid(basis: Basis) -> bool:
	if not basis.is_finite() or absf(basis.determinant() - 1.0) > RIGID_TOLERANCE:
		return false
	for axis: Vector3 in [basis.x, basis.y, basis.z]:
		if absf(axis.length_squared() - 1.0) > RIGID_TOLERANCE:
			return false
	return absf(basis.x.dot(basis.y)) < RIGID_TOLERANCE and absf(basis.x.dot(basis.z)) < RIGID_TOLERANCE and absf(basis.y.dot(basis.z)) < RIGID_TOLERANCE


static func _is_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and absf(float(value)) <= 1000000.0 and float(value) == floorf(float(value))


static func _exact_keys(value: Dictionary, keys: Array[String]) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true


static func _find_port(definition: PartDef, id: String) -> Port:
	for port: Port in definition.ports:
		if String(port.id) == id:
			return port
	return null
