class_name StageDefinition
extends RefCounted

const METRICS: Array[String] = ["height", "x", "sonar_distance", "speed", "upright", "wall_contact"]
const MAX_BYTES: int = 1048576


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not MotionSnapshot._exact_keys(value, ["format", "version", "id", "title", "scene", "rules", "constraints", "author_solution"]):
		return false
	if value.format != "ssok-stage" or value.version != 1 or not value.id is String or value.id.length() > 80 or not value.title is String or value.title.length() > 80:
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
		if not rule is Dictionary or not MotionSnapshot._exact_keys(rule, ["metric", "part_id", "min", "max", "hold_seconds"]):
			return false
		if rule.metric not in METRICS or not rule.part_id is String or not MotionSnapshot._catalog().has(rule.part_id):
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


static func rule(metric: String, part_id: String, minimum: float, maximum: float, hold: float = 0.0) -> Dictionary:
	return {"metric": metric, "part_id": part_id, "min": minimum, "max": maximum, "hold_seconds": hold}


static func create(id: String, title: String, graph: ConnectionGraph, answer: String, rules: Array) -> Dictionary:
	var result: Dictionary = {"format": "ssok-stage", "version": 1, "id": id, "title": title,
		"scene": ProjectStore.document(title, graph, ""), "author_solution": ProjectStore.document(title, graph, answer),
		"rules": rules, "constraints": {"max_parts": 256, "time_limit": 60.0}}
	return result if valid(result) else {}


static func fingerprint(stage: Dictionary, graph: ConnectionGraph, source: String) -> String:
	var snapshot: Dictionary = MotionSnapshot.encode(graph)
	return JSON.stringify([stage.get("rules"), stage.get("constraints"), snapshot, source], "", true, true).sha256_text()
