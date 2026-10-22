extends SceneTree

var checks: int = 0
var failures: int = 0
var _default_strip_max: float = 0
var _min_block_viewport: float = INF


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


func _button_fits(button: Button, context: String) -> void:
	var label: String = button.text if button.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else tr(button.text)
	var width: float = button.get_theme_font("font").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
	if button.icon != null:
		width += button.get_theme_constant("icon_max_width") + (button.get_theme_constant("h_separation") if not label.is_empty() else 0)
	width += button.get_theme_stylebox("normal").get_minimum_size().x
	_check(width <= button.size.x + 1, context + " complete button " + label + " measured=" + str(width) + " size=" + str(button.size) + " minimum=" + str(button.get_combined_minimum_size()))
	_check(not button.tooltip_text.is_empty(), context + " tooltip")


func _run() -> void:
	var prefs: InterfacePreferences = root.get_node("Preferences")
	root.size = Vector2i(1152, 648)
	for mode: String in ["stage", "lab"]:
		var levels: Array = StageLevels.all() if mode == "stage" else [{}]
		for level: Dictionary in levels:
			var main: Node3D = load("res://scenes/main.tscn").instantiate()
			main.session = {"mode": mode, "level": level}
			root.add_child(main)
			await _settle()
			for locale: String in SsokLocale.LOCALES:
				SsokLocale.select_locale(locale, false)
				for scale: float in [1.0, 1.3, 2.0]:
					prefs.values.text_scale = scale
					prefs.changed.emit()
					await _settle()
					var context: String = mode + str(level.get("id", "")) + locale + str(scale)
					var hud: StageHud = main.stage_hud
					var strip: Rect2 = hud.goal_card.get_global_rect()
					if scale == 1.0:
						_default_strip_max = maxf(_default_strip_max, strip.size.y)
					_check(Rect2(Vector2.ZERO, root.size).encloses(strip), context + " strip inside viewport " + str(strip))
					_check(strip.size.y <= (96 if scale == 1.0 else 96 * scale), context + " bounded two rows " + str(strip))
					for row: Container in [hud._top, hud.chip_grid]:
						var previous: Control
						for child: Control in row.get_children():
							if not child.visible:
								continue
							if previous != null:
								_check(not previous.get_global_rect().intersects(child.get_global_rect()), context + " adjacent controls never overlap")
							previous = child
					var goal: Label = hud.find_child("GoalSentence", true, false)
					if scale == 1.0:
						_check(goal.get_theme_font("font").get_string_size(tr(goal.text), HORIZONTAL_ALIGNMENT_LEFT, -1, goal.get_theme_font_size("font_size")).x <= goal.size.x, context + " entire goal visible")
					for button: Button in hud._tool_actions + hud.chips + [hud.run_action]:
						_button_fits(button, context)
						_check(strip.encloses(button.get_global_rect()), context + " button inside strip")
					for panel: Control in [main._side_panel, main._ui_root.get_node("PartsLibrary")]:
						main._toggle_overlay(panel)
						if not panel.visible:
							main._toggle_overlay(panel)
						await _settle()
						var rect: Rect2 = panel.get_global_rect()
						_check(rect.size.y <= root.size.y * 0.6 + 1, context + " editor capped at 60% " + str(rect))
						_check(not rect.intersects(strip), context + " editor does not overlap strip")
						_check(Rect2(Vector2.ZERO, root.size).encloses(rect), context + " editor inside viewport")
						_check(panel.get_node("OverlayScroll").size.y > 80, context + " editor scroll viewport visible")
						panel.hide()
					main._toggle_overlay(main._side_panel)
					main.program_tabs.current_tab = 2
					await _settle()
					_min_block_viewport = minf(_min_block_viewport, main.blocks.scroll.size.y)
					_check(main.blocks.scroll.size.y >= 80, context + " block input viewport visible " + str(main.blocks.scroll.size))
					main._side_panel.hide()
					# Restore full labels after compacting and a dynamic language change.
					root.size = Vector2i(1440, 900)
					await _settle()
					root.size = Vector2i(1152, 648)
					await _settle()
			main.free()
			await _settle()
	print("compact geometry: default strip max=%.0f px; block input viewport min=%.0f px" % [_default_strip_max, _min_block_viewport])
	print("workshop_compact_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
