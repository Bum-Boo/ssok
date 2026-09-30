class_name StageProgress
extends RefCounted

## Local clear records. Kept outside project documents so opening or sharing a project
## never changes progress, and progress never changes a learner's build.

const PATH: String = "user://progress.json"

## Tests point this elsewhere so they never touch a learner's real progress.
static var path: String = PATH


static func load_cleared() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("format") != "ssok-progress" or not value.get("cleared") is Dictionary:
		return {}
	var cleared: Dictionary = {}
	for key: Variant in value.cleared:
		if key is String and value.cleared[key] == true:
			cleared[key] = true
	return cleared


static func is_cleared(id: String) -> bool:
	return load_cleared().has(id)


static func mark_cleared(id: String) -> Error:
	var cleared: Dictionary = load_cleared()
	cleared[id] = true
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"format": "ssok-progress", "version": 1, "cleared": cleared}, "  ", true))
	return OK
