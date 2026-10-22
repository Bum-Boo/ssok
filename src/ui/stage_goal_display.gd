class_name StageGoalDisplay
extends Node3D

## Decoration only. Every scored number comes from the existing evaluator's samples.
var label: Label3D
var level: Dictionary = {}
var rules: Array = []
var samples: Array[Dictionary] = []
var outcome: String = "idle"
var _assembly_value: Variant = null


func configure(stage_level: Dictionary, stage: Dictionary) -> void:
	level = stage_level
	rules = stage.get("rules", [])
	label = Label3D.new()
	label.name = "ObservedGoal"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font = SsokTheme.build().default_font
	label.font_size = 40
	label.outline_size = 10
	label.modulate = Color("eafff7")
	label.outline_modulate = Color("173e37")
	label.pixel_size = 0.00045
	add_child(label)
	match String(level.get("id", "")):
		"raise-flag":
			label.position = Vector3(0.0165, float(rules[0].min) + 0.065, 0)
		"finish-line":
			label.position = Vector3(float(rules[0].min), 0.19, 0)
		"wall-brake":
			label.position = Vector3(0.715, 0.22, 0)
	_refresh()


func show_samples(values: Array[Dictionary], status: String) -> void:
	if values == samples and status == outcome:
		return
	samples = values.duplicate(true)
	outcome = status
	_refresh()


func show_assembly(graph: ConnectionGraph) -> void:
	var value: Variant = null
	if not rules.is_empty() and rules[0].metric in ["height", "x"]:
		var matches: Array[Dictionary] = []
		for part: Dictionary in graph.parts:
			if String(part.part_def.id) == rules[0].part_id:
				matches.append(part)
		if matches.size() == 1:
			var pose: Transform3D = matches[0].transform
			value = (pose * Vector3(0, matches[0].part_def.mesh.get_aabb().end.y, 0)).y if rules[0].metric == "height" else pose.origin.x
	if value != _assembly_value:
		_assembly_value = value
		_refresh()


func _refresh() -> void:
	if label == null:
		return
	var lines: PackedStringArray = [tr(level.get("metric_label", ""))]
	if samples.is_empty():
		var primary: Dictionary = rules[0]
		if primary.max >= 50.0:
			lines.append(tr("Target: at least %.3f m") % float(primary.min))
		else:
			var scale: float = 0.01 if primary.metric == "sonar_distance" else 1.0
			lines.append(tr("Target: %.3f–%.3f m") % [float(primary.min) * scale, float(primary.max) * scale])
		if _assembly_value != null:
			if primary.metric == "height":
				lines.append(tr("Assembly height: %.3f m") % float(_assembly_value))
			else:
				lines.append(tr("Remaining: %.2f m") % maxf(0.0, float(primary.min) - float(_assembly_value)))
		lines.append(tr("Run to measure the goal."))
	else:
		for index: int in mini(rules.size(), samples.size()):
			var sample: Dictionary = samples[index]
			var rule: Dictionary = rules[index]
			if sample.get("value") == null:
				lines.append(tr("Measurement unavailable"))
				continue
			var scale: float = 0.01 if rule.metric == "sonar_distance" else 1.0
			var value: float = float(sample.value) * scale
			var low: float = float(rule.min) * scale
			var high: float = float(rule.max) * scale
			var unit: String = "m" if rule.metric in ["height", "x", "sonar_distance"] else ("m/s" if rule.metric == "speed" else "")
			var comparison: String = "%.3f %s ≥ %.3f %s" % [value, unit, low, unit] if rule.max >= 50.0 else "%.3f ≤ %.3f ≤ %.3f %s" % [low, value, high, unit]
			lines.append(tr("%s: %s; hold %.1f / %.1f s") % [tr({"height": "Flag height", "x": "Distance driven", "sonar_distance": "Distance to wall", "speed": "Speed", "upright": "Upright", "wall_contact": "Wall contact"}.get(rule.metric, rule.metric)), comparison, float(sample.get("held_seconds", 0.0)), float(rule.hold_seconds)])
			if index == 0 and rule.metric == "x":
				lines.append(tr("Remaining: %.2f m") % maxf(0.0, low - value))
	if outcome == "success":
		lines.append(tr("Stage cleared!"))
	elif outcome in ["not_met", "indeterminate"]:
		lines.append(tr("Not yet"))
	label.text = "\n".join(lines)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if label != null:
			label.font = SsokTheme.build().default_font
		_refresh()
