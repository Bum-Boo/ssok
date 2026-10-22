extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + message)


func _settle() -> void:
	for frame: int in 10:
		await process_frame


func _space(main: Node3D, context: String) -> void:
	var display: StageGoalDisplay = main.goal_display
	var hud: StageHud = main.stage_hud
	var area: Rect2 = main._camera_framing_rect().grow(-8)
	var required: Vector2 = display.card.get_combined_minimum_size()
	var fits: bool = area.size.x >= required.x and area.size.y >= required.y
	_check(display.label.autowrap_mode == TextServer.AUTOWRAP_OFF, context + " no wrapping")
	_check(display.card.size.x >= 260 * SsokTheme.ui_scale, context + " scaled minimum width")
	_check(display.card.visible == fits, context + " hide exactly when available area cannot fit " + str(area) + str(required))
	_check(display.card.size.is_equal_approx(required), context + " natural size independent of area")
	for line: String in display.label.text.split("\n"):
		var width: float = display.label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, display.label.get_theme_font_size("font_size")).x
		_check(width <= display.label.size.x + 1, context + " complete text width")
	if fits:
		_check(area.encloses(display.card.get_global_rect()), context + " clamped inside free area")
		_check(hud._goal_summary.is_empty(), context + " workflow hint restored")
	else:
		_check(hud.hint_label.visible and not hud.hint_label.text.is_empty(), context + " fallback remains visible")
		_check(hud.hint_label.text == display._summary, context + " primary rule current / target summary")
		var summary_width: float = hud.hint_label.get_theme_font("font").get_string_size(hud.hint_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hud.hint_label.get_theme_font_size("font_size")).x
		_check(summary_width <= hud.hint_label.size.x + 1, context + " full fallback width " + str(summary_width) + " available=" + str(hud.hint_label.size.x))
		_check(hud.hint_label.get_line_count() == 1, context + " one fallback line")
		_check(hud.hint_label.tooltip_text == display.label.text, context + " all rule details in tooltip")
		_check(hud.hint_label.size.x >= 100 and hud.goal_card.get_global_rect().encloses(hud.hint_label.get_global_rect()), context + " fallback inside strip with readable width")


func _run() -> void:
	var prefs: InterfacePreferences = root.get_node("Preferences")
	for level: Dictionary in StageLevels.all():
		var main: Node3D = load("res://scenes/main.tscn").instantiate()
		main.session = {"mode": "stage", "level": level}
		root.add_child(main)
		await _settle()
		var display: StageGoalDisplay = main.goal_display
		var hud: StageHud = main.stage_hud
		var anchor: Vector3 = display.anchor
		for locale: String in SsokLocale.LOCALES:
			SsokLocale.select_locale(locale, false)
			for scale: float in [1.0, 1.3, 2.0]:
				for appearance: String in ["light", "dark"]:
					prefs.values.text_scale = scale
					prefs.values.appearance = appearance
					prefs.changed.emit()
					for dimensions: Vector2i in [Vector2i(1152, 648), Vector2i(1440, 900)]:
						root.size = dimensions
						await _settle()
						var context: String = level.id + locale + str(scale) + appearance + str(dimensions)
						_space(main, context + " closed")
						for panel: Control in [main._side_panel, main._ui_root.get_node("PartsLibrary")]:
							main._toggle_overlay(panel)
							await _settle()
							_space(main, context + " panel " + panel.name)
							panel.hide()
							await _settle()
							_space(main, context + " restored")
						var width: float = display.card.size.x
						display.anchor = Vector3(-100, 0, 0)
						await _settle()
						_space(main, context + " offscreen")
						_check(is_equal_approx(width, display.card.size.x), context + " edge keeps natural width")
						display.anchor = anchor
						# Exercise both fit boundaries even when real panels leave ample space.
						var required: Vector2 = display.card.size
						for shortage: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
							var constrained := Rect2(Vector2(30, 200), required + Vector2(16, 16) - shortage)
							display.area_provider = func() -> Rect2: return constrained
							await _settle()
							_check(not display.card.visible and hud.hint_label.visible, context + " width/height shortage uses summary")
							_check(hud.hint_label.text == display._summary, context + " shortage summary current")
							hud.show_workflow({"current": 3, "completed": [true, true, true, false]})
							await _settle()
							_check(hud.hint_label.text == display._summary and hud.hint_label.visible, context + " guide cannot erase fallback")
							display.area_provider = main._camera_framing_rect
							await _settle()
							_space(main, context + " recovered")
		main.free()
		await _settle()
	print("workshop_goal_space_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
