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


func _primary_count(node: Node) -> int:
	var count: int = 1 if node is Button and node.is_visible_in_tree() and node.theme_type_variation == &"PrimaryButton" else 0
	for child: Node in node.get_children():
		count += _primary_count(child)
	return count


func _run() -> void:
	var prefs: InterfacePreferences = root.get_node("Preferences")
	root.size = Vector2i(1152, 648)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = {"mode": "stage", "level": StageLevels.all()[0]}
	root.add_child(main)
	await _settle()
	for appearance: String in ["light", "dark"]:
		prefs.values.appearance = appearance
		prefs.changed.emit()
		for locale: String in SsokLocale.LOCALES:
			SsokLocale.select_locale(locale, false)
			await _settle()
			_check(main.stage_hud.goal_card.get_theme_stylebox("panel").bg_color == Color(SsokTheme.BG, 0.94), appearance + locale + " strip preserves appearance palette")
			var title: Label = main.stage_hud._top.get_child(1)
			var goal: Label = main.stage_hud.find_child("GoalSentence", true, false)
			var hint: Label = main.stage_hud.hint_label
			_check(title.get_theme_font_size("font_size") > goal.get_theme_font_size("font_size") and goal.get_theme_font_size("font_size") > hint.get_theme_font_size("font_size"), appearance + locale + " title > goal > hint")
			_check(hint.get_theme_color("font_color") == SsokTheme.TEXT_DIM, appearance + locale + " hint stays dim")
			main._toggle_overlay(main._side_panel)
			main.program_tabs.current_tab = 2
			await _settle()
			var before: String = main.blocks._source_at_load
			main.blocks.highlight_line(3)
			var marked: bool = false
			for row: Control in main.blocks.rows.get_children():
				_check(row.modulate == Color.WHITE, appearance + locale + " executing block never tints input")
				marked = marked or row.get_meta("executing", false)
			_check(marked, appearance + locale + " execution still highlights current block")
			_check(main.blocks._source_at_load == before and not main.blocks.has_draft(), appearance + locale + " emphasis preserves learner program")
			_check(_primary_count(main._ui_root) == 1, appearance + locale + " editor has one filled action")
			main.blocks.highlight_line(-1)
			main._side_panel.hide()
		main.stage_hud.show_success("Stage cleared!")
		_check(_primary_count(main._ui_root) == 1, appearance + " success has one filled action")
		main.stage_hud.retry_button.pressed.emit()
		await _settle()
		main.stage_hud.show_failure("Not yet")
		_check(_primary_count(main._ui_root) == 1, appearance + " retry has one filled action")
		main.stage_hud.retry_button.pressed.emit()
		await _settle()
	main.free()
	print("workshop_emphasis_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
