class_name StageGoalDisplay
extends Control

## Screen-space annotation only; scored values come from the existing evaluator.
signal summary_changed(text: String, detail: String)

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
var _summary: String = ""
var _published_summary: String = ""
var _published_detail: String = ""


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
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	card.add_child(label)
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
	# Never trade legibility for space: use the natural text width or the scaled floor.
	card.custom_minimum_size.x = 260.0 * SsokTheme.ui_scale
	card.size = card.get_combined_minimum_size()
	card.visible = area.size.x >= card.size.x and area.size.y >= card.size.y
	var summary: String = "" if card.visible else _summary
	var detail: String = "" if card.visible else label.text
	if summary != _published_summary or detail != _published_detail:
		_published_summary = summary
		_published_detail = detail
		summary_changed.emit(summary, detail)
	if not card.visible:
		queue_redraw()
		return
	projected_anchor = camera.unproject_position(anchor)
	var offscreen: bool = camera.is_position_behind(anchor) or not area.has_point(projected_anchor)
	if camera.is_position_behind(anchor):
		var direction: Vector2 = area.get_center() - projected_anchor
		if direction.is_zero_approx():
			direction = Vector2.UP
		var half: Vector2 = area.size * 0.5
		var scale: float = minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
		projected_anchor = area.get_center() + direction * scale
	projected_anchor = projected_anchor.clamp(area.position, area.end)
	var desired: Vector2 = projected_anchor + Vector2(24, -card.size.y - 24)
	# Place toward the freer side rather than across the world marker.
	if desired.x + card.size.x > area.end.x:
		desired.x = projected_anchor.x - card.size.x - 24
	if offscreen:
		desired = projected_anchor - card.size * 0.5
	card.position = desired.clamp(area.position, (area.end - card.size).max(area.position))
	leader_end = projected_anchor.clamp(card.position, card.position + card.size)
	queue_redraw()


func _draw() -> void:
	if card != null and card.visible:
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
		if index == 0:
			_summary = lines[-1]
		lines.append(tr("Hold: %.1f / %.1f s") % [float(sample.get("held_seconds", 0.0)), float(rule.hold_seconds)])
	label.text = "\n".join(lines)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()
