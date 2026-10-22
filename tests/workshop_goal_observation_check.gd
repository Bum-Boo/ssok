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
	for frame: int in 8:
		await process_frame


func _space(main: Node3D, context: String) -> void:
	var display: StageGoalDisplay = main.goal_display
	var area: Rect2 = main._camera_framing_rect().grow(-8)
	var required: Vector2 = display.card.get_combined_minimum_size()
	var fits: bool = area.size.x >= required.x and area.size.y >= required.y
	_check(display.card.size.x >= 260 * SsokTheme.ui_scale and display.card.size.is_equal_approx(required), context + " natural width and scaled minimum")
	_check(display.card.visible == fits, context + " observation-specific fit")
	if fits:
		_check(area.encloses(display.card.get_global_rect()), context + " observed edge clamping")
		_check(main.stage_hud._goal_summary.is_empty(), context + " no duplicate summary")
	else:
		_check(main.stage_hud.hint_label.visible and main.stage_hud.hint_label.text == display._summary, context + " observation-specific fallback")
		var hint: Label = main.stage_hud.hint_label
		var width: float = hint.get_theme_font("font").get_string_size(hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint.get_theme_font_size("font_size")).x
		_check(width <= hint.size.x + 1, context + " full current/target summary visible")
		_check(main.stage_hud.hint_label.get_line_count() == 1, context + " observed fallback remains one line")


func _run() -> void:
	var prefs: InterfacePreferences = root.get_node("Preferences")
	for level: Dictionary in StageLevels.all():
		var main: Node3D = load("res://scenes/main.tscn").instantiate()
		main.session = {"mode": "stage", "level": level}
		root.add_child(main)
		await _settle()
		# Feed display fixtures without changing the evaluator or running physics.
		main.set_process(false)
		var display: StageGoalDisplay = main.goal_display
		var anchor: Vector3 = display.anchor
		for locale: String in SsokLocale.LOCALES:
			SsokLocale.select_locale(locale, false)
			for scale: float in [1.0, 1.3, 2.0]:
				prefs.values.text_scale = scale
				prefs.changed.emit()
				for dimensions: Vector2i in [Vector2i(1152, 648), Vector2i(1440, 900)]:
					root.size = dimensions
					for panel_open: bool in [false, true]:
						main._side_panel.visible = panel_open
						var context: String = level.id + locale + str(scale) + str(dimensions) + str(panel_open)
						for status: String in ["idle", "running"]:
							display.show_samples([], status)
							await _settle()
							_space(main, context + status)
							_check(display.label.get_line_count() == display.rules.size(), context + " target-only line per unobserved rule " + status)
							_check(not display.label.text.contains(tr("Hold: %.1f / %.1f s").get_slice("%", 0)) and not display.label.text.contains(tr("Measurement unavailable")), context + " no unobserved current/hold lines")
							for index: int in display.rules.size():
								_check(display.label.text.split("\n")[index].begins_with(tr("Target: %s (%s)").get_slice("%s", 0)), context + " localized target prefix")
						var before_height: float = display.card.size.y
						var before_anchor: Vector2 = display.projected_anchor
						var observed: Array[Dictionary] = []
						for rule: Dictionary in display.rules:
							observed.append({"value": rule.min, "held_seconds": 0.2})
						display.show_samples(observed, "running")
						await _settle()
						_space(main, context + " observed")
						_check(display.samples == observed, context + " unchanged sample values")
						_check(display.label.get_line_count() == 2 * display.rules.size(), context + " observed current/target and hold lines")
						_check(display.card.size.y > before_height, context + " target-only height shrinks")
						_check(display.anchor == anchor, context + " world anchor preserved")
						if display.card.visible:
							_check(display.projected_anchor.is_equal_approx(before_anchor), context + " projected anchor preserved")
						for index: int in display.rules.size():
							var rule: Dictionary = display.rules[index]
							var lines: PackedStringArray = display.label.text.split("\n")
							_check(lines[index * 2 + 1] == tr("Hold: %.1f / %.1f s") % [0.2, float(rule.hold_seconds)], context + " exact observed hold time")
						# Null sonar remains unavailable, while valid zero is still a reading.
						observed[0].value = null
						display.show_samples(observed, "running")
						_check(display.label.text.contains(tr("Measurement unavailable")), context + " missing observation never fabricated")
						observed[0].value = 0.0
						display.show_samples(observed, "running")
						_check(not display.label.text.contains(tr("Measurement unavailable")) and display.label.text.contains("0.000"), context + " valid zero retained")
						display.show_samples([observed[0]], "running")
						_check(display.label.get_line_count() == display.rules.size() + 1, context + " partial observation adds only its own hold line")
						display.show_samples([], "idle")
						await _settle()
						_check(display.label.get_line_count() == display.rules.size() and is_equal_approx(display.card.size.y, before_height), context + " reset restores target-only height")
		main.free()
		await _settle()
	print("workshop_goal_observation_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
