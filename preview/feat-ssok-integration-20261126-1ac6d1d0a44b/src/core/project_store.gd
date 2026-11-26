class_name ProjectStore
extends RefCounted

## Portable project documents keep graph authority separate from learner-authored source.
const DIRECTORY: String = "user://projects/"
const MAX_BYTES: int = 524288
const MAX_CODE_BYTES: int = 65536
const MAX_FILES: int = 128


static func document(title: String, graph: ConnectionGraph, source: String) -> Dictionary:
	var snapshot: Dictionary = MotionSnapshot.encode(graph)
	# Empty workspaces are valid projects, unlike physics trials.
	if graph != null and graph.parts.is_empty() and graph.links.is_empty():
		snapshot = {"version": 1, "parts": [], "links": []}
	var record: Dictionary = {"format": "ssok-project", "version": 1,
		"title": title.strip_edges(), "graph": snapshot, "source": source,
		"saved_utc": Time.get_datetime_string_from_system(true)}
	return record if valid(record) else {}


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not MotionSnapshot._exact_keys(value, ["format", "version", "title", "graph", "source", "saved_utc"]):
		return false
	if value.format != "ssok-project" or not MotionSnapshot._is_integer(value.version) or int(value.version) != 1:
		return false
	if not value.title is String or value.title.strip_edges().is_empty() or value.title.length() > 80:
		return false
	if not value.source is String or value.source.to_utf8_buffer().size() > MAX_CODE_BYTES:
		return false
	if not value.saved_utc is String or value.saved_utc.length() > 32 or not value.graph is Dictionary:
		return false
	return graph_from(value) != null


static func graph_from(record: Dictionary) -> ConnectionGraph:
	var data: Variant = record.get("graph")
	if data is Dictionary and MotionSnapshot._exact_keys(data, ["version", "parts", "links"]) \
			and MotionSnapshot._is_integer(data.version) and int(data.version) == 1 \
			and data.parts is Array and data.parts.is_empty() and data.links is Array and data.links.is_empty():
		return ConnectionGraph.new()
	return MotionSnapshot.decode(data)


static func parse(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return {}
	var value: Variant = parser.data
	return value if valid(value) else {}


static func serialize(record: Dictionary) -> String:
	return JSON.stringify(record, "  ", true, true) if valid(record) else ""


static func save(record: Dictionary, directory: String = DIRECTORY) -> Dictionary:
	var data: String = serialize(record)
	if data.is_empty() or data.to_utf8_buffer().size() > MAX_BYTES:
		return {"error": "Project data is invalid or too large."}
	if list_projects(directory).size() >= MAX_FILES:
		return {"error": "Your project library is full. Export or delete a saved project first."}
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return {"error": "Could not save this project. Export a copy to keep your work."}
	var id: String = (str(Time.get_ticks_usec()) + str(randi())).sha256_text().left(24)
	var path: String = directory.path_join(id + ".json")
	var temporary: String = path + ".tmp"
	if FileAccess.file_exists(path):
		return {"error": "Could not save this project. Export a copy to keep your work."}
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"error": "Could not save this project. Export a copy to keep your work."}
	file.store_string(data)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return {"error": "Could not save this project. Export a copy to keep your work."}
	return {"id": id}


static func load_project(id: String, directory: String = DIRECTORY) -> Dictionary:
	if not _valid_id(id):
		return {}
	var file: FileAccess = FileAccess.open(directory.path_join(id + ".json"), FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var text: String = file.get_as_text()
	file.close()
	return parse(text)


static func list_projects(directory: String = DIRECTORY) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var folder: DirAccess = DirAccess.open(directory)
	if folder == null:
		return records
	for filename: String in folder.get_files():
		if not filename.ends_with(".json"):
			continue
		var id: String = filename.trim_suffix(".json")
		var record: Dictionary = load_project(id, directory)
		if not record.is_empty():
			records.append({"id": id, "record": record})
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.record.saved_utc > b.record.saved_utc)
	return records


static func remove(id: String, directory: String = DIRECTORY) -> Error:
	if not _valid_id(id):
		return ERR_INVALID_PARAMETER
	return DirAccess.remove_absolute(directory.path_join(id + ".json"))


static func _valid_id(id: String) -> bool:
	return RegEx.create_from_string("^[a-f0-9]{24}$").search(id) != null
