class_name StageGoalDisplay
extends Control

## Screen-space annotation only; scored values come from the existing evaluator.
var label: Label
var card: PanelContainer
var anchor: Vector3
var projected_anchor: Vector2
var leader_end: Vector2
var level: Dictionary = {}
var rules: Array = []
var samples: Array[Dictionary] = []
var outcome: String = "idle"
var camera: Camera3D
var area_provider: Callable
var _appearance: String = ""
var _assembly_value: Variant = null


func configure(stage_level: Dictionary, stage: Dictionary) -> void:
	level = stage_level
	rules = stage.get("rules", [])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	label = Label.new()
	label.name = "ObservedGoal"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(label)
	match String(level.get("id", "")):
		"raise-flag":
			anchor = Vector3(0.0165, float(rules[0].min), 0.075)
		"finish-line":
			anchor = Vector3(float(rules[0].min), 0.055, 0.14)
		"wall-brake":
			anchor = Vector3(0.715, 0.055, 0.14)
	_refresh()


func _process(_delta: float) -> void:
	update_projection()


func update_projection() -> void:
	if camera == null or card == null:
		return
	var area: Rect2 = area_provider.call() if area_provider.is_valid() else get_viewport_rect()
	area = area.grow(-8.0)
	var appearance: String = str(SsokTheme.dark) + str(SsokTheme.ui_scale)
	if appearance != _appearance:
		_appearance = appearance
		var style := StyleBoxFlat.new()
		style.bg_color = Color(SsokTheme.BG, 0.9)
		style.border_color = SsokTheme.BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", style)
		label.add_theme_font_size_override("font_size", SsokTheme.font_size(16))
		label.add_theme_color_override("font_color", SsokTheme.TEXT)
	# Width and height stay in UI pixels, independent of camera distance.
	card.custom_minimum_size.x = minf(380.0 * SsokTheme.ui_scale, area.size.x)
	card.size = Vector2(card.custom_minimum_size.x, 0)
	projected_anchor = camera.unproject_position(anchor)
	if camera.is_position_behind(anchor):
		projected_anchor = area.get_center() - (projected_anchor - area.get_center())
		if projected_anchor.is_equal_approx(area.get_center()):
			projected_anchor.y = area.position.y
	projected_anchor = projected_anchor.clamp(area.position, area.end)
	var desired: Vector2 = projected_anchor + Vector2(24, -card.size.y - 24)
	# Place toward the freer side rather than across the world marker.
	if desired.x + card.size.x > area.end.x:
		desired.x = projected_anchor.x - card.size.x - 24
	card.position = desired.clamp(area.position, (area.end - card.size).max(area.position))
	leader_end = projected_anchor.clamp(card.position, card.position + card.size)
	queue_redraw()


func _draw() -> void:
	if card != null:
		draw_line(projected_anchor, leader_end, SsokTheme.ACCENT, 1.5, true)


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
	var lines: PackedStringArray = []
	for index: int in rules.size():
		var rule: Dictionary = rules[index]
		var sample: Dictionary = samples[index] if index < samples.size() else {}
		var value: Variant = sample.get("value", _assembly_value if index == 0 else null)
		var scale: float = 0.01 if rule.metric == "sonar_distance" else 1.0
		var unit: String = "m" if rule.metric in ["height", "x", "sonar_distance"] else ("m/s" if rule.metric == "speed" else "")
		var metric: String = tr({"height": "Flag height", "x": "Distance driven", "sonar_distance": "Distance to wall", "speed": "Speed", "upright": "Upright", "wall_contact": "Wall contact"}.get(rule.metric, rule.metric))
		var current: String = "%.3f %s" % [float(value) * scale, unit] if value != null else tr("Measurement unavailable")
		var target: String = "≥ %.3f %s" % [float(rule.min) * scale, unit] if rule.max >= 50.0 else "%.3f–%.3f %s" % [float(rule.min) * scale, float(rule.max) * scale, unit]
		lines.append(tr("%s: %s / Target: %s") % [metric, current, target])
		lines.append(tr("Hold: %.1f / %.1f s") % [float(sample.get("held_seconds", 0.0)), float(rule.hold_seconds)])
	label.text = "\n".join(lines)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()
