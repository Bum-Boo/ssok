class_name StageProgress
extends RefCounted

## Local clear records and per-stage workspaces, separate from shared project documents.
const PATH: String = "user://progress.json"
static var path: String = PATH


static func _load() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	if not data is Dictionary or data.get("format") != "ssok-progress" or not data.get("cleared") is Dictionary:
		return {"format": "ssok-progress", "version": 2, "cleared": {}, "solutions": {}, "workspaces": {}}
	for key: String in ["solutions", "workspaces"]:
		if not data.get(key) is Dictionary:
			data[key] = {}
	return data


static func _save(data: Dictionary) -> Error:
	data.version = 2
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  ", true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error


static func load_cleared() -> Dictionary:
	var cleared: Dictionary = {}
	var data: Dictionary = _load()
	for key: Variant in data.cleared:
		if key is String and data.cleared[key] == true:
			cleared[key] = true
	return cleared


static func is_cleared(id: String) -> bool:
	return load_cleared().has(id)


static func mark_cleared(id: String, used_solution: bool = false) -> Error:
	var data: Dictionary = _load()
	# An independent clear remains independent after later answer exploration.
	data.solutions[id] = used_solution if not data.cleared.get(id, false) else data.solutions.get(id, false) and used_solution
	data.cleared[id] = true
	return _save(data)


static func cleared_with_solution(id: String) -> bool:
	return is_cleared(id) and _load().solutions.get(id, false) == true


static func save_workspace(id: String, project: Dictionary, used_solution: bool) -> Error:
	if not ProjectStore.valid(project):
		return ERR_INVALID_DATA
	var data: Dictionary = _load()
	data.workspaces["stage:" + id] = {"project": project, "used_solution": used_solution}
	return _save(data)


static func load_workspace(id: String) -> Dictionary:
	var value: Variant = _load().workspaces.get("stage:" + id, {})
	if not value is Dictionary or not ProjectStore.valid(value.get("project")) or not value.get("used_solution") is bool:
		return {}
	return value
