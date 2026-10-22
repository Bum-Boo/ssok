class_name StageHud
extends Control

## Scene-wide task strip and a compact result card.
## Success is shown only from the evaluator's observed outcome, never from the program ending.

signal start_pressed
signal retry_requested
signal next_requested
signal list_requested
signal exit_pressed
signal phase_requested(index: int)
signal parts_requested
signal program_requested
signal help_requested
signal run_requested

var level: Dictionary = {}
var goal_card: PanelContainer
var measure_label: Label
var hint_label: Label
var problem_label: Label
var briefing: Control
var result: Control
var next_button: Button
var retry_button: Button
var _result_title: Label
var _result_detail: Label
var _result_icon: TextureRect
var _has_next: bool = false
var _rule: Dictionary = {}
var chips: Array[Button] = []
var chip_grid: GridContainer
var help_action: Button
var run_action: Button


func configure(stage_level: Dictionary, has_next: bool) -> void:
	level = stage_level
	_has_next = has_next
	var stage: Dictionary = StageLevels.stage_definition(level) if level.has("stage_id") else {}
	_rule = stage.rules[0] if not stage.is_empty() else {}


func _ready() -> void:
	name = "StageHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_goal_card()
	# Keep the old public handle for integrations, with no opening modal.
	briefing = Control.new()
	briefing.visible = false
	add_child(briefing)
	result = _modal("Result")
	_build_result(result.get_meta("box"))
	result.visible = false



func _build_goal_card() -> void:
	goal_card = PanelContainer.new()
	goal_card.name = "GoalCard"
	goal_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(goal_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	goal_card.add_child(box)
	var top := HFlowContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	var back: Button = SsokTheme.button("Stages" if level.has("stage_id") else "Menu", "arrow-left")
	back.name = "ExitButton"
	back.tooltip_text = "Back to the stage list"
	back.custom_minimum_size.x = 36
	back.pressed.connect(func() -> void: exit_pressed.emit())
	top.add_child(back)
	var number := Label.new()
	number.add_theme_color_override("font_color", SsokTheme.ACCENT)
	number.add_theme_font_size_override("font_size", SsokTheme.font_size(13))
	number.text = "Now"
	top.add_child(number)
	var title := Label.new()
	title.text = level.get("title", "")
	title.add_theme_font_size_override("font_size", SsokTheme.font_size(18))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var hint_button: Button = SsokTheme.button("Hint", "sparkles")
	hint_button.name = "HintButton"
	hint_button.toggle_mode = true
	hint_button.clip_text = false
	hint_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hint_button.toggled.connect(func(show: bool) -> void: hint_label.visible = show)
	top.add_child(hint_button)
	for entry: Array in [["Parts library", "box", parts_requested], ["Robot program", "code-xml", program_requested], ["Help", "book-open", help_requested]]:
		var action: Button = SsokTheme.button(entry[0], entry[1])
		action.pressed.connect(func() -> void: entry[2].emit())
		if entry[0] == "Help":
			help_action = action
		top.add_child(action)
	var goal := Label.new()
	goal.text = level.get("goal", "")
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(goal)
	chip_grid = GridContainer.new()
	chip_grid.columns = 4
	chip_grid.add_theme_constant_override("h_separation", 12)
	box.add_child(chip_grid)
	for index: int in 4:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip_grid.add_child(column)
		var chip: Button = SsokTheme.button(WorkshopGuide.NAMES[index])
		chip.pressed.connect(func() -> void: phase_requested.emit(index))
		column.add_child(chip)
		chips.append(chip)
		var detail := Label.new()
		detail.text = WorkshopGuide.HINTS[index]
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.label_settings = SsokTheme.dim_settings()
		column.add_child(detail)
	run_action = MenuScreen.primary(SsokTheme.button("Run code", "play"))
	run_action.pressed.connect(func() -> void: run_requested.emit())
	top.add_child(run_action)
	measure_label = Label.new()
	measure_label.name = "Measurement"
	measure_label.label_settings = SsokTheme.dim_settings()
	measure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SsokLocale.bind(measure_label, "Press Run code to try it.")
	box.add_child(measure_label)
	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.text = level.get("hint", "")
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", SsokTheme.ACCENT)
	hint_label.visible = false
	box.add_child(hint_label)
	problem_label = Label.new()
	problem_label.name = "Problem"
	problem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	problem_label.add_theme_color_override("font_color", SsokTheme.ERROR)
	problem_label.visible = false
	box.add_child(problem_label)


func _modal(node_name: String) -> Control:
	var layer := Control.new()
	layer.name = node_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 16
	center.offset_right = -16
	center.offset_top = 16
	center.offset_bottom = -16
	center.alignment = BoxContainer.ALIGNMENT_END
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var parts: Array = MenuScreen.card(460)
	parts[0].custom_minimum_size.x = 460
	parts[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(parts[0])
	parts[1].add_theme_constant_override("separation", 12)
	layer.set_meta("box", parts[1])
	return layer


func _build_result(box: VBoxContainer) -> void:
	_result_icon = TextureRect.new()
	_result_icon.texture = SsokTheme.icon("trophy")
	_result_icon.custom_minimum_size = Vector2(48, 48)
	_result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_icon.modulate = SsokTheme.ACCENT
	box.add_child(_result_icon)
	_result_title = MenuScreen.text(box, "", 28)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_detail = MenuScreen.text(box, "", 16)
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_button = MenuScreen.primary(SsokTheme.button("Next stage", "chevron-right"))
	next_button.name = "NextButton"
	next_button.custom_minimum_size.y = 44
	next_button.pressed.connect(func() -> void: next_requested.emit())
	box.add_child(next_button)
	retry_button = SsokTheme.button("Try again", "rotate-ccw")
	retry_button.name = "RetryButton"
	retry_button.custom_minimum_size.y = 44
	retry_button.pressed.connect(func() -> void:
		result.visible = false
		run_action.visible = true
		retry_requested.emit())
	box.add_child(retry_button)


## Empty text hides the line. Only errors the learner can fix are shown here.
func show_problem(text: String, arguments: Array = [], translated_arguments: Array[int] = []) -> void:
	problem_label.visible = not text.is_empty()
	if problem_label.visible:
		SsokLocale.bind(problem_label, text, arguments, translated_arguments)


func show_briefing() -> void:
	hint_label.visible = true


func show_workflow(state: Dictionary) -> void:
	for index: int in chips.size():
		chips[index].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chips[index].text = ("✓ " if state.completed[index] else "") + ("→ " if index == state.current else "") + tr(WorkshopGuide.NAMES[index])
		chips[index].add_theme_color_override("font_color", SsokTheme.ACCENT if index == state.current else SsokTheme.TEXT_DIM)


func show_success(detail: String, arguments: Array = []) -> void:
	briefing.visible = false
	result.visible = true
	run_action.visible = false
	_result_icon.texture = SsokTheme.icon("trophy")
	_result_icon.modulate = SsokTheme.ACCENT
	SsokLocale.bind(_result_title, "Stage cleared!")
	SsokLocale.bind(_result_detail, detail, arguments)
	retry_button.theme_type_variation = &"Button" if _has_next else &"PrimaryButton"
	next_button.visible = _has_next
	retry_button.text = "Try again"
	(next_button if _has_next else retry_button).grab_focus.call_deferred()


func show_failure(message: String) -> void:
	briefing.visible = false
	result.visible = true
	run_action.visible = false
	_result_icon.texture = SsokTheme.icon("rotate-ccw")
	_result_icon.modulate = SsokTheme.TEXT_DIM
	SsokLocale.bind(_result_title, "Not yet")
	SsokLocale.bind(_result_detail, message)
	retry_button.theme_type_variation = &"PrimaryButton"
	next_button.visible = false
	retry_button.text = "Try again"
	retry_button.grab_focus.call_deferred()


## `value` is null while nothing is being measured.
func show_measurement(value: Variant) -> void:
	var metric: String = level.get("metric_label", "")
	var rule: Dictionary = _rule
	if value == null or rule.is_empty():
		SsokLocale.bind(measure_label, "Press Run code to try it.")
		return
	var scale: float = 1.0 if rule.metric == "sonar_distance" else 100.0
	if rule.max >= 50.0:
		SsokLocale.bind(measure_label, "%s: %.1f cm (goal: at least %.1f cm)", [metric, float(value) * scale, rule.min * scale], [0])
	else:
		SsokLocale.bind(measure_label, "%s: %.1f cm (goal: %.1f-%.1f cm)", [metric, float(value) * scale, rule.min * scale, rule.max * scale], [0])


func layout(area: Rect2) -> void:
	chip_grid.columns = 2 if area.size.x < 1000.0 or SsokTheme.ui_scale >= 1.5 else 4
	goal_card.position = area.position
	goal_card.size = Vector2(area.size.x, 0)
	goal_card.reset_size()
	goal_card.size.x = area.size.x
