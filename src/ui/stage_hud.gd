class_name StageHud
extends Control

## In-stage 2D layer: a compact goal card, the opening briefing and the result window.
## Success is shown only from the evaluator's observed outcome, never from the program ending.

signal start_pressed
signal retry_requested
signal next_requested
signal list_requested
signal exit_pressed

var level: Dictionary = {}
var goal_card: PanelContainer
var measure_label: Label
var hint_label: Label
var problem_label: Label
var briefing: Control
var result: Control
var start_button: Button
var next_button: Button
var retry_button: Button
var _result_title: Label
var _result_detail: Label
var _result_icon: TextureRect
var _has_next: bool = false
var _rule: Dictionary = {}


func configure(stage_level: Dictionary, has_next: bool) -> void:
	level = stage_level
	_has_next = has_next
	var stage: Dictionary = StageLevels.stage_definition(level)
	_rule = stage.rules[0] if not stage.is_empty() else {}


func _ready() -> void:
	name = "StageHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_goal_card()
	briefing = _modal("Briefing")
	_build_briefing(briefing.get_meta("box"))
	result = _modal("Result")
	_build_result(result.get_meta("box"))
	result.visible = false
	show_briefing()


func _build_goal_card() -> void:
	goal_card = PanelContainer.new()
	goal_card.name = "GoalCard"
	goal_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(goal_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	goal_card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	var back: Button = SsokTheme.button("", "arrow-left")
	back.name = "ExitButton"
	back.tooltip_text = "Back to the stage list"
	back.custom_minimum_size.x = 36
	back.pressed.connect(func() -> void: exit_pressed.emit())
	top.add_child(back)
	var number := Label.new()
	number.add_theme_color_override("font_color", SsokTheme.ACCENT)
	number.add_theme_font_size_override("font_size", SsokTheme.font_size(13))
	SsokLocale.bind(number, "STAGE %s", [level.get("number", "")])
	top.add_child(number)
	var title := Label.new()
	title.text = level.get("title", "")
	title.add_theme_font_size_override("font_size", SsokTheme.font_size(18))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var hint_button: Button = SsokTheme.button("Hint", "sparkles")
	hint_button.name = "HintButton"
	hint_button.toggle_mode = true
	hint_button.toggled.connect(func(show: bool) -> void: hint_label.visible = show)
	top.add_child(hint_button)
	var again: Button = SsokTheme.button("", "book-open")
	again.name = "BriefingButton"
	again.tooltip_text = "Show the mission again"
	again.pressed.connect(show_briefing)
	top.add_child(again)
	var goal := Label.new()
	goal.text = level.get("goal", "")
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(goal)
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
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var parts: Array = MenuScreen.card(460)
	parts[0].custom_minimum_size.x = 460
	parts[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(parts[0])
	parts[1].add_theme_constant_override("separation", 12)
	layer.set_meta("box", parts[1])
	return layer


func _build_briefing(box: VBoxContainer) -> void:
	var number: Label = MenuScreen.text(box, "", 14, false, SsokTheme.ACCENT)
	SsokLocale.bind(number, "STAGE %s", [level.get("number", "")])
	MenuScreen.text(box, level.get("title", ""), 28)
	MenuScreen.text(box, level.get("story", ""), 16)
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	box.add_child(steps)
	var steps_list: Array = level.get("steps", [])
	for index: int in steps_list.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		steps.add_child(row)
		var badge := Label.new()
		badge.text = str(index + 1)
		badge.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		badge.custom_minimum_size.x = 22
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", SsokTheme.ACCENT)
		row.add_child(badge)
		var step := Label.new()
		step.text = steps_list[index]
		step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(step)
	start_button = MenuScreen.primary(SsokTheme.button("Start", "play"))
	start_button.name = "StartButton"
	start_button.custom_minimum_size.y = 46
	start_button.pressed.connect(func() -> void:
		briefing.visible = false
		start_pressed.emit())
	box.add_child(start_button)


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
		retry_requested.emit())
	box.add_child(retry_button)
	var list: Button = SsokTheme.button("Stage list", "map")
	list.name = "ListButton"
	list.custom_minimum_size.y = 44
	list.pressed.connect(func() -> void: list_requested.emit())
	box.add_child(list)


## Empty text hides the line. Only errors the learner can fix are shown here.
func show_problem(text: String, arguments: Array = [], translated_arguments: Array[int] = []) -> void:
	problem_label.visible = not text.is_empty()
	if problem_label.visible:
		SsokLocale.bind(problem_label, text, arguments, translated_arguments)


func show_briefing() -> void:
	result.visible = false
	briefing.visible = true
	start_button.grab_focus.call_deferred()


func show_success(detail: String, arguments: Array = []) -> void:
	briefing.visible = false
	result.visible = true
	_result_icon.texture = SsokTheme.icon("trophy")
	_result_icon.modulate = SsokTheme.ACCENT
	SsokLocale.bind(_result_title, "Stage cleared!")
	SsokLocale.bind(_result_detail, detail, arguments)
	next_button.visible = _has_next
	retry_button.text = "Try another way"
	(next_button if _has_next else retry_button).grab_focus.call_deferred()


func show_failure(message: String) -> void:
	briefing.visible = false
	result.visible = true
	_result_icon.texture = SsokTheme.icon("rotate-ccw")
	_result_icon.modulate = SsokTheme.TEXT_DIM
	SsokLocale.bind(_result_title, "Not yet")
	SsokLocale.bind(_result_detail, message)
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
	var width: float = clampf(area.size.x, 280.0, 560.0)
	goal_card.size = Vector2(width, 0)
	goal_card.position = area.position
	goal_card.reset_size()
	goal_card.size.x = width
