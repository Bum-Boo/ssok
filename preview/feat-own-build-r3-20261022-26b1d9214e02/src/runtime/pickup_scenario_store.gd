class_name PickupScenarioStore
extends RefCounted

const DIRECTORY: String = "user://pickup_scenarios/"
const MAX_BYTES: int = 262144
const MAX_FILES: int = 64


static func save_scenario(label: String, snapshot: Dictionary, result: Dictionary, provider: String) -> Dictionary:
	var name: String = label.strip_edges().left(80)
	if name.is_empty() or provider not in ["baseline", "local", "mock", "openai", "replay"]:
		return {"error": "Scenario name or source is invalid."}
	if list_scenarios().size() >= MAX_FILES:
		return {"error": "The local scenario library is full (64 files)."}
	var record: Dictionary = {"version": 1, "name": name, "graph": snapshot.duplicate(true),
		"result": _clean_result(result), "provider": provider,
		"created_utc": Time.get_datetime_string_from_system(true)}
	if not valid_record(record):
		return {"error": "Scenario data is invalid; nothing was saved."}
	var data: String = JSON.stringify(record, "", true, true)
	if data.to_utf8_buffer().size() > MAX_BYTES or DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK:
		return {"error": "Could not save the scenario under user://."}
	var id: String = (str(Time.get_ticks_usec()) + str(randi()) + name).sha256_text().left(24)
	var path: String = DIRECTORY + id + ".json"
	if FileAccess.file_exists(path):
		return {"error": "Could not save the scenario under user://."}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"error": "Could not save the scenario under user://."}
	file.store_string(data)
	var error: Error = file.get_error()
	file.close()
	return {"id": id, "path": path} if error == OK else {"error": "Could not save the scenario under user://."}


static func list_scenarios() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var directory: DirAccess = DirAccess.open(DIRECTORY)
	if directory == null:
		return records
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for filename: String in files:
		if records.size() >= MAX_FILES:
			break
		var id: String = filename.trim_suffix(".json")
		if filename != id + ".json":
			continue
		var record: Dictionary = load_scenario(id)
		if not record.is_empty():
			records.append({"id": id, "record": record})
	return records


static func load_scenario(id: String) -> Dictionary:
	if RegEx.create_from_string("^[a-f0-9]{24}$").search(id) == null:
		return {}
	var file: FileAccess = FileAccess.open(DIRECTORY + id + ".json", FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return value if valid_record(value) else {}


static func valid_record(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 6 or typeof(value.get("version")) not in [TYPE_INT, TYPE_FLOAT] or value.version != 1:
		return false
	if not value.get("name") is String or value.name.strip_edges().is_empty() or value.name.length() > 80:
		return false
	if value.get("provider") not in ["baseline", "local", "mock", "openai", "replay"] or not value.get("created_utc") is String or value.created_utc.length() > 32:
		return false
	if not value.get("graph") is Dictionary or MotionSnapshot.decode(value.graph) == null:
		return false
	if not value.get("result") is Dictionary or value.result.size() != 2 or not PickupPolicy.validate(value.result.get("policy")).is_empty() or not PickupPolicy.valid_metrics(value.result.get("metrics")):
		return false
	return value.result.metrics.graph_fingerprint == MotionSnapshot.fingerprint(value.graph)


static func _clean_result(result: Dictionary) -> Dictionary:
	if not result.get("metrics") is Dictionary or not result.get("policy") is Dictionary:
		return {}
	var metrics: Dictionary = {}
	for key: String in ["finite", "fallen", "success", "lift_m", "hold_seconds", "min_upright", "score", "simulation_seconds", "graph_fingerprint", "engine_version", "physics_hz", "phase", "contact_before_grasp", "cancelled"]:
		if result.metrics.has(key):
			metrics[key] = result.metrics[key]
	return {"policy": result.policy.duplicate(true), "metrics": metrics}
