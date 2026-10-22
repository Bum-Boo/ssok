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


func _label_size(label: Label) -> int:
	return label.label_settings.font_size if label.label_settings != null else label.get_theme_font_size("font_size")


func _find_label(node: Node, source: String) -> Label:
	if node is Label and node.text == source:
		return node
	for child: Node in node.get_children():
		var found: Label = _find_label(child, source)
		if found != null:
			return found
	return null


func _panel_heading(node: Node, source: String, context: String) -> void:
	var label: Label = _find_label(node, source)
	_check(label != null, context + " heading exists: " + source)
	if label == null:
		return
	_check(_label_size(label) == SsokTheme.font_size(16), context + " middle panel heading: " + source)
	var font: FontVariation = label.label_settings.font if label.label_settings != null else null
	_check(font != null and font.variation_embolden > 0 and font == SsokLocale.ui_bold_font and font.variation_face_index == SsokLocale.ui_font.variation_face_index, context + " bold heading follows live locale: " + source)
	if font != null:
		var glyphs_present: bool = true
		for character: String in tr(source):
			if not character.strip_edges().is_empty():
				glyphs_present = glyphs_present and font.has_char(character.unicode_at(0))
		_check(glyphs_present, context + " bold heading has translated glyphs: " + source)


func _no_large_labels(node: Node, context: String) -> void:
	if node is Label:
		_check(_label_size(node) <= SsokTheme.font_size(16), context + " panel contains no large label: " + node.text.left(45))
	for child: Node in node.get_children():
		_no_large_labels(child, context)


func _run() -> void:
	var prefs: InterfacePreferences = root.get_node("Preferences")
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = {"mode": "stage", "level": StageLevels.all()[0]}
	root.add_child(main)
	if main.session.get("mode") == "stage":
		var fixture: Dictionary = StageLevels.stage_definition(main.session.level)
		main._load_preset(StageLevels.starting_graph(main.session.level, fixture), fixture.author_solution.source, "")
	await _settle()
	for dimensions: Vector2i in [Vector2i(1152, 648), Vector2i(1440, 900)]:
		root.size = dimensions
		for appearance: String in ["light", "dark"]:
			prefs.values.appearance = appearance
			for locale: String in SsokLocale.LOCALES:
				SsokLocale.select_locale(locale, false)
				for scale: float in [1.0, 1.3, 2.0]:
					prefs.values.text_scale = scale
					prefs.changed.emit()
					await _settle()
					var context: String = str(dimensions) + appearance + locale + str(scale)
					var hud: StageHud = main.stage_hud
					_check(hud.goal_card.get_theme_stylebox("panel").bg_color == Color(SsokTheme.BG, 0.94), context + " strip preserves appearance palette")
					var tag: Label = hud.find_child("GoalTag", true, false)
					var goal: Label = hud.find_child("GoalSentence", true, false)
					var hint: Label = hud.hint_label
					_check(_label_size(goal) == roundi(28 * scale), context + " goal is large at chosen scale")
					_check(_label_size(tag) == roundi(14 * scale) and tag.get_theme_color("font_color") == SsokTheme.TEXT_DIM, context + " category tag is small and dim")
					_check(tag.get_global_rect().end.x <= goal.get_global_rect().position.x, context + " tag precedes goal")
					_check(_label_size(hint) == roundi(14 * scale) and hint.get_theme_color("font_color") == SsokTheme.TEXT_DIM, context + " hint stays small and dim")
					for chip: Button in hud.chips:
						_check(chip.get_theme_font_size("font_size") == roundi(16 * scale), context + " chip stays middle")
					_check(goal.max_lines_visible == 1 and goal.autowrap_mode == TextServer.AUTOWRAP_OFF and goal.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, context + " goal trims on one line without shrinking")
					_check(tr(goal.tooltip_text) == tr(goal.text), context + " goal tooltip retains complete translation")
					_check(goal.size.x > 0 and hud.goal_card.get_global_rect().encloses(goal.get_global_rect()), context + " large goal stays inside strip")
					_panel_heading(main._side_panel, "Robot program", context)
					_panel_heading(main._side_panel, "Python-style servo program", context)
					_panel_heading(main._side_panel, "Build a program with blocks", context)
					_panel_heading(main._side_panel, "Connect a motor to a board pin", context)
					_panel_heading(main._side_panel, "Move your robot", context)
					_panel_heading(main._side_panel, "Stages and free building", context)
					_panel_heading(main._ui_root.get_node("PartsLibrary"), "Parts library", context)
					_panel_heading(main.projects, "Keep building. Pick up where you left off.", context)
					_panel_heading(main.tutorial, "Tutorial", context)
					_check(_label_size(main.tutorial.heading) == roundi(16 * scale), context + " help step heading is middle")
					for window: Window in [main.settings, main.projects, main.tutorial]:
						_check(window.get_theme_font_size("title_font_size") == roundi(16 * scale), context + " window title is middle: " + window.title)
						var font: FontVariation = window.get_theme_font("title_font") as FontVariation
						_check(font != null and font.variation_embolden > 0, context + " window title is bold: " + window.title)
					for panel: Node in [main._side_panel, main._ui_root.get_node("PartsLibrary"), main.projects, main.settings, main.tutorial]:
						_no_large_labels(panel, context)
					main._toggle_overlay(main._side_panel)
					main.program_tabs.current_tab = 2
					await _settle()
					var before: String = main.blocks._source_at_load
					main.blocks.highlight_line(3)
					var marked: bool = false
					for row: Control in main.blocks.rows.get_children():
						_check(row.modulate == Color.WHITE, context + " executing block never tints input")
						marked = marked or row.get_meta("executing", false)
					_check(marked, context + " execution still highlights current block")
					_check(main.blocks._source_at_load == before and not main.blocks.has_draft(), context + " emphasis preserves learner program")
					_check(_primary_count(main._ui_root) == 1, context + " editor has one filled action")
					main.blocks.highlight_line(-1)
					main._side_panel.hide()
					for success: bool in [true, false]:
						if success:
							hud.show_success("Stage cleared!")
						else:
							hud.show_failure("Not yet")
						_check(_label_size(hud._result_title) == roundi(28 * scale), context + " result heading remains large")
						_check(_primary_count(main._ui_root) == 1, context + " result has one filled action")
						hud.retry_button.pressed.emit()
					await _settle()
	main.free()
	print("workshop_emphasis_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
