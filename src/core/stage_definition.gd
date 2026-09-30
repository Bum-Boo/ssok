class_name StageDefinition
extends RefCounted

const METRICS: Array[String] = ["height", "x", "sonar_distance", "speed", "upright", "wall_contact"]
const MAX_BYTES: int = 1048576


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not MotionSnapshot._exact_keys(value, ["format", "version", "id", "title", "scene", "rules", "constraints", "author_solution"]):
		return false
	if value.format != "ssok-stage" or (not MotionSnapshot._is_integer(value.version) or (value.version != 1 and value.version != 2)) or not value.id is String or value.id.length() > 80 or not value.title is String or value.title.length() > 80:
		return false
	if not ProjectStore.valid(value.scene) or not ProjectStore.valid(value.author_solution):
		return false
	if not value.constraints is Dictionary or not MotionSnapshot._exact_keys(value.constraints, ["max_parts", "time_limit"]):
		return false
	if typeof(value.constraints.max_parts) not in [TYPE_INT, TYPE_FLOAT] or value.constraints.max_parts < 1 or value.constraints.max_parts > 256 or value.constraints.max_parts != floorf(value.constraints.max_parts):
		return false
	if typeof(value.constraints.time_limit) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value.constraints.time_limit) or value.constraints.time_limit < 1 or value.constraints.time_limit > 600:
		return false
	if not value.rules is Array or value.rules.is_empty() or value.rules.size() > 16:
		return false
	for rule: Variant in value.rules:
		var keys: Array[String] = ["metric", "part_id", "min", "max", "hold_seconds"]
		if value.version == 2:
			keys.append("target_index")
		if not rule is Dictionary or not MotionSnapshot._exact_keys(rule, keys):
			return false
		if rule.metric not in METRICS or not rule.part_id is String or not MotionSnapshot._catalog().has(rule.part_id):
			return false
		if value.version == 2:
			if not MotionSnapshot._is_integer(rule.target_index) or rule.target_index < -1:
				return false
			if rule.target_index >= 0:
				for document: Dictionary in [value.scene, value.author_solution]:
					if rule.target_index >= document.graph.parts.size() or document.graph.parts[rule.target_index].id != rule.part_id:
						return false
		for key: String in ["min", "max", "hold_seconds"]:
			if typeof(rule[key]) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(rule[key])):
				return false
		if rule.min > rule.max or rule.hold_seconds < 0 or rule.hold_seconds > value.constraints.time_limit:
			return false
	return true


static func parse(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return {}
	var value: Variant = JSON.parse_string(text)
	return value if valid(value) else {}


static func serialize(value: Dictionary) -> String:
	return JSON.stringify(value, "  ", true, true) if valid(value) else ""


static func rule(metric: String, part_id: String, minimum: float, maximum: float, hold: float = 0.0, target_index: int = -1) -> Dictionary:
	return {"metric": metric, "part_id": part_id, "min": minimum, "max": maximum, "hold_seconds": hold, "target_index": target_index}


static func create(id: String, title: String, graph: ConnectionGraph, answer: String, rules: Array) -> Dictionary:
	var result: Dictionary = {"format": "ssok-stage", "version": 2, "id": id, "title": title,
		"scene": ProjectStore.document(title, graph, ""), "author_solution": ProjectStore.document(title, graph, answer),
		"rules": rules, "constraints": {"max_parts": 256, "time_limit": 60.0}}
	return parse(JSON.stringify(result, "", true, true)) if valid(result) else {}


static func runtime_context(run_mode: RunMode = null, graph: ConnectionGraph = null, resource_identity: Dictionary = {}) -> Dictionary:
	var settings: Dictionary = {}
	for property: Dictionary in ProjectSettings.get_property_list():
		var name: String = property.name
		if name.begins_with("physics/"):
			settings[name] = ProjectSettings.get_setting(name)
	if resource_identity.is_empty():
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/stage_runtime_identity.json")) if FileAccess.file_exists("res://assets/stage_runtime_identity.json") else {}
		resource_identity = manifest if manifest is Dictionary else {}
		for directory: String in ["res://src/core/", "res://src/runtime/", "res://src/profiles/", "res://assets/parts/", "res://assets/meshes/", "res://stages/"]:
			_hash_resources(directory, resource_identity)
	var sensors: Array[Dictionary] = []
	var models: Array[Dictionary] = []
	if is_instance_valid(run_mode):
		var model_graph: ConnectionGraph = graph if graph != null else run_mode._graph
		for part: Dictionary in model_graph.parts if model_graph != null else []:
			var properties: Dictionary = {}
			for property: Dictionary in part.part_def.get_property_list():
				if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
					properties[property.name] = _model_value(part.part_def.get(property.name))
			models.append(properties)
		for key: int in run_mode.sonars:
			var sensor: SonarSensor = run_mode.sonars[key]
			sensors.append({"part": key, "realistic": sensor.realistic, "seed": sensor.noise_seed})
	return {"contract": 2, "engine": Engine.get_version_info(), "physics_settings": settings,
		"physics_ticks": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale,
		"resources": resource_identity, "sensor_conditions": sensors, "part_models": models,
		"anchors": Array(run_mode.anchored_part_ids) if is_instance_valid(run_mode) else []}


static func _model_value(value: Variant) -> Variant:
	if value is Resource:
		var properties: Dictionary = {"class": value.get_class(), "path": value.resource_path}
		if value is Mesh:
			properties.bounds = str(value.get_aabb())
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name not in ["script", "resource_name", "resource_local_to_scene"]:
				var item: Variant = value.get(property.name)
				if not item is Object and (not value is Mesh or typeof(item) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR3]):
					properties[property.name] = _model_value(item)
		return properties
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_model_value(item))
		return items
	if value is Object:
		return value.get_class()
	return value


static func _hash_resources(directory: String, hashes: Dictionary) -> void:
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".gd") or name.ends_with(".tres") or name.ends_with(".res") or name.ends_with(".tscn"):
			var path: String = directory.path_join(name)
			if FileAccess.file_exists(path):
				hashes[path] = FileAccess.get_sha256(path)
	for name: String in DirAccess.get_directories_at(directory):
		_hash_resources(directory.path_join(name), hashes)


static func fingerprint(stage: Dictionary, graph: ConnectionGraph, source: String, context: Dictionary = {}) -> String:
	var snapshot: Dictionary = MotionSnapshot.encode(graph)
	var effective_context: Dictionary = runtime_context() if context.is_empty() else context
	return JSON.stringify([stage, snapshot, source, effective_context], "", true, true).sha256_text()
