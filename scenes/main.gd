extends Node3D

## Slice-1 prototype shell: assembly view on the left, learner code on the right,
## one toggle between kinematic assembly and physics run mode (ADR 0003).

const PART_COLORS := {
	&"base": Color(0.35, 0.35, 0.4),
	&"servo": Color(0.15, 0.35, 0.85),
	&"arm_link": Color(0.95, 0.55, 0.15),
	&"board": Color(0.1, 0.55, 0.3),
}

const PARTS_DIR := "res://assets/parts"
const CONTROL_MANUAL: int = 0
const CONTROL_CODE: int = 1

var assembly: AssemblyMode
var run_mode: RunMode
var runtime: MiniRuntime
var code_edit: CodeEdit
var status: Label
var mode_button: Button
var run_button: Button
var answer_button: Button
var biped_button: Button
var learned_biped_button: Button
var humanoid_button: Button
var kit_bridge_button: Button
var modular_button: Button
var navigation: BlenderCamera
var manual_controller: ManualController
var motion_program: RobotMotionProgram
var control_source: OptionButton
var stop_button: Button
var motion_lab_button: Button
var motion_lab: MotionLabPanel
var pickup_lab: PickupLabPanel
var tutorial: TutorialPanel
var _highlighted_line: int = -1
var stages: StagePanel
var flag_mission: FlagMission
var tutorial_button: Button
var _manual_status: Label
var _movement_instructions: Label
var _help_label: Label
var _delete_dialog: ConfirmationDialog
var _applied_motion_fingerprint: String = ""
var _applied_pickup_fingerprint: String = ""
var _follow_body: RigidBody3D
var _follow_position: Vector3
var _follow_offset: Vector3 = Vector3.ZERO

var _ui_root: Control
var language_picker: OptionButton
var _spawn_count := 0
var program_tabs: TabContainer
var part_search: LineEdit
var part_category: OptionButton
var part_buttons: Array[Button] = []
var delete_button: Button
var _workspace_state: Label
var _side_panel: PanelContainer
var _empty_panel: PanelContainer
var _help_panel: PanelContainer
var _no_parts: Label
var _transform_buttons: Array[Button] = []
var projects: ProjectPanel
var projects_button: Button
var project_title: String = "My robot"
var blocks: BlockProgramPanel
var wiring_panel: WiringPanel
var examples_menu: MenuButton
var _starter_controls: Array[Control] = []
var _parts_scroll: ScrollContainer
var _clean_workspace: String = ""
var _pending_starter: Callable
var _replace_dialog: ConfirmationDialog


func _ready() -> void:
	var camera := $Camera3D as Camera3D
	camera.look_at_from_position(Vector3(0.2, 0.18, 0.26), Vector3(0.05, 0.09, 0))
	camera.fov = 45.0
	navigation = BlenderCamera.new(camera)
	add_child(navigation)
	_dress_scene()

	assembly = AssemblyMode.new()
	add_child(assembly)
	navigation.bounds_provider = _selection_bounds
	navigation.scene_bounds_provider = _scene_bounds
	assembly.status_changed.connect(_set_status)
	assembly.transform_active_changed.connect(func(active: bool) -> void: navigation.navigation_enabled = not active)
	assembly.graph_changed.connect(func() -> void: _mark_ports(assembly))

	run_mode = RunMode.new()
	add_child(run_mode)

	runtime = MiniRuntime.new()
	runtime.hardware = run_mode
	runtime.line_started.connect(func(n: int) -> void:
		_set_status("running line %d", false, [n])
		if is_instance_valid(code_edit):
			if _highlighted_line >= 0 and _highlighted_line < code_edit.get_line_count():
				code_edit.set_line_background_color(_highlighted_line, Color.TRANSPARENT)
			_highlighted_line = n - 1
			if n > 0 and n <= code_edit.get_line_count():
				code_edit.set_line_background_color(n - 1, Color(0.18, 0.3, 0.4, 0.6))
			if is_instance_valid(blocks):
				blocks.highlight_line(n))
	runtime.finished.connect(func() -> void:
		if stages != null and stages.evaluator.success:
			_set_status("Challenge cleared. Change your build and try another solution.")
		elif stages != null and stages.evaluator.status in ["not_met", "cancelled", "indeterminate"]:
			stages._show_result()
		else:
			_set_status("finished"))
	runtime.failed.connect(func(n: int, msg: String) -> void:
		_show_code_failure(n, msg, int(runtime.last_failure.get("column", 1)))
		if is_instance_valid(stages):
			stages.on_program_error())
	add_child(runtime)
	manual_controller = ManualController.new()
	add_child(manual_controller)
	motion_program = BipedMotion.new()
	add_child(motion_program)
	manual_controller.movement_changed.connect(func(throttle: float, turn: float) -> void: motion_program.set_move_input(Vector2(turn, throttle)))
	manual_controller.state_changed.connect(_refresh_manual_status)
	manual_controller.sprint_changed.connect(func(pressed: bool) -> void:
		if motion_program is HumanoidMotion:
			motion_program.set_sprint_requested(pressed))
	manual_controller.interaction_requested.connect(func() -> void:
		if motion_program is HumanoidMotion:
			motion_program.interact())

	_build_ui()
	add_child(preload("res://src/ui/web_clipboard.gd").new())
	add_child(preload("res://src/ui/browser_evidence.gd").new())
	_build_palette()
	_build_help_hud()
	_ui_root.move_child(flag_mission, _ui_root.get_child_count() - 1)
	_layout_flag_mission()
	navigation.framing_rect_provider = _camera_framing_rect
	get_viewport().size_changed.connect(_adapt_layout)
	_adapt_layout()
	_refresh_control_ui()
	_set_status("Edit mode - select a part, then G to move or R to rotate; connections snap at ports")
	get_viewport().gui_release_focus()
	_clean_workspace = _workspace_key()


func _process(_delta: float) -> void:
	_refresh_manual_status()
	_follow_running_robot()


func _follow_running_robot() -> void:
	if not run_mode.is_built() or not motion_program.is_supported():
		_follow_body = null
		return
	var body_part: int = int(motion_program.get("body_part"))
	if body_part < 0 or body_part >= run_mode.bodies.size():
		return
	var body: RigidBody3D = run_mode.bodies[body_part]
	if not is_instance_valid(_follow_body) or _follow_body != body:
		_follow_body = body
		_follow_position = body.global_position
		return
	var moved: Vector3 = body.global_position - _follow_position
	_follow_position = body.global_position
	moved.y = 0.0
	if not moved.is_finite():
		return
	_follow_offset += moved
	navigation.track_displacement(moved)


func _selection_bounds() -> AABB:
	if mode_button != null and mode_button.button_pressed:
		return _scene_bounds()
	var bounds: AABB = assembly.get_selection_bounds()
	return assembly.get_scene_bounds() if bounds.size.is_zero_approx() else bounds


func _scene_bounds() -> AABB:
	if run_mode == null or not run_mode.is_built():
		return assembly.get_scene_bounds()
	var bounds: AABB = AABB()
	var first: bool = true
	for body: RigidBody3D in run_mode.bodies:
		for child: Node in body.get_children():
			if child is MeshInstance3D:
				var visual: MeshInstance3D = child as MeshInstance3D
				var part_bounds: AABB = visual.global_transform * visual.mesh.get_aabb()
				bounds = part_bounds if first else bounds.merge(part_bounds)
				first = false
	return bounds


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.theme = SsokTheme.build()
	layer.add_child(_ui_root)
	flag_mission = FlagMission.new()
	flag_mission.theme = _ui_root.theme
	flag_mission.configure(assembly, run_mode, self)
	flag_mission.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	flag_mission.offset_left = 452
	flag_mission.offset_right = -382
	flag_mission.offset_top = 86
	flag_mission.offset_bottom = 252
	flag_mission.starter_requested.connect(func() -> void: _request_starter(_on_microbit_arm_pressed))
	flag_mission.practice_requested.connect(func() -> void:
		_request_starter(_practice_flag_arm))
	flag_mission.connect_arm_requested.connect(func() -> void:
		if not mode_button.button_pressed and assembly.graph.parts.size() >= 3:
			assembly.connect_parts(2, &"mount_base", 1, &"output_shaft"))
	flag_mission.wiring_requested.connect(func() -> void: program_tabs.current_tab = 3)
	flag_mission.run_requested.connect(_on_run_pressed)
	flag_mission.stop_requested.connect(_on_stop_pressed)
	flag_mission.retry_requested.connect(func() -> void:
		if mode_button.button_pressed:
			mode_button.button_pressed = false
		code_edit.grab_focus())
	_ui_root.add_child(flag_mission)

	var top := PanelContainer.new()
	top.name = "WorkspaceHeader"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 12
	top.offset_bottom = 74
	_ui_root.add_child(top)
	var bar := HBoxContainer.new()
	top.add_child(bar)
	var brand := Label.new()
	brand.text = "ssok"
	brand.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	brand.add_theme_font_size_override("font_size", 24)
	brand.add_theme_color_override("font_color", SsokTheme.ACCENT)
	brand.custom_minimum_size.x = 94
	bar.add_child(brand)
	projects_button = SsokTheme.button("Projects", "folder-open")
	projects_button.pressed.connect(_open_projects)
	bar.add_child(projects_button)
	_workspace_state = Label.new()
	_workspace_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace_state.theme_type_variation = &"SectionLabel"
	bar.add_child(_workspace_state)
	mode_button = SsokTheme.button("Run mode (physics)", "play")
	mode_button.toggle_mode = true
	mode_button.toggled.connect(_on_mode_toggled)
	bar.add_child(mode_button)
	stop_button = SsokTheme.button("Stop", "square")
	stop_button.tooltip_text = "Stop input / code"
	stop_button.pressed.connect(_on_stop_pressed)
	bar.add_child(stop_button)
	motion_lab_button = SsokTheme.button("AI motion lab", "flask-conical")
	motion_lab_button.pressed.connect(_open_motion_lab)
	bar.add_child(motion_lab_button)
	tutorial_button = SsokTheme.button("", "book-open")
	tutorial_button.name = "TutorialButton"
	tutorial_button.custom_minimum_size.x = 36
	tutorial_button.tooltip_text = "Tutorial"
	tutorial_button.focus_mode = Control.FOCUS_ALL
	tutorial_button.pressed.connect(_open_tutorial)
	bar.add_child(tutorial_button)
	language_picker = OptionButton.new()
	language_picker.name = "LanguagePicker"
	language_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_picker.focus_mode = Control.FOCUS_ALL
	for language_name: String in SsokLocale.NAMES:
		language_picker.add_item(language_name)
	language_picker.select(SsokLocale.LOCALES.find(SsokLocale.normalize(TranslationServer.get_locale())))
	language_picker.tooltip_text = tr("Language")
	language_picker.item_selected.connect(_on_language_selected)
	bar.add_child(language_picker)

	_side_panel = PanelContainer.new()
	_side_panel.name = "ProgramPanel"
	_side_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_side_panel.offset_left = -364
	_side_panel.offset_top = 86
	_side_panel.offset_right = -12
	_side_panel.offset_bottom = -58
	_ui_root.add_child(_side_panel)
	var box := VBoxContainer.new()
	_side_panel.add_child(box)
	var title := Label.new()
	title.text = "Robot program"
	title.label_settings = SsokTheme.title_settings()
	box.add_child(title)
	control_source = OptionButton.new()
	control_source.add_item("Control: WASD / gamepad movement", CONTROL_MANUAL)
	control_source.add_item("Control: Learner code", CONTROL_CODE)
	control_source.focus_mode = Control.FOCUS_ALL
	control_source.item_selected.connect(_on_control_source_selected)
	box.add_child(control_source)

	program_tabs = TabContainer.new()
	program_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(program_tabs)
	var code_box := VBoxContainer.new()
	code_box.name = "Code"
	program_tabs.add_child(code_box)
	var caption := Label.new()
	caption.text = "Python-style servo program"
	caption.theme_type_variation = &"SectionLabel"
	code_box.add_child(caption)
	code_edit = CodeEdit.new()
	code_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	code_edit.tooltip_text = "Esc leaves the code editor. Tab moves between controls."
	code_edit.text = ServoArmPreset.ANSWER_CODE
	code_edit.gutters_draw_line_numbers = true
	code_edit.highlight_current_line = true
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_edit.custom_minimum_size.y = 100
	var syntax := CodeHighlighter.new()
	syntax.number_color = Color("e6bb84")
	syntax.function_color = Color("86b9ef")
	syntax.symbol_color = Color("a3afbe")
	syntax.add_keyword_color("from", Color("c9a1ee"))
	syntax.add_keyword_color("import", Color("c9a1ee"))
	syntax.add_keyword_color("Servo", SsokTheme.ACCENT)
	syntax.add_color_region("#", "", Color("8193a7"), true)
	code_edit.syntax_highlighter = syntax
	code_box.add_child(code_edit)
	var controls_scroll := ScrollContainer.new()
	controls_scroll.follow_focus = true
	controls_scroll.name = "Controls"
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	program_tabs.add_child(controls_scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.add_child(controls)
	var controls_title := Label.new()
	controls_title.text = "Move your robot"
	controls_title.label_settings = SsokTheme.title_settings()
	controls.add_child(controls_title)
	_manual_status = Label.new()
	_manual_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(_manual_status)
	var instructions := Label.new()
	_movement_instructions = instructions
	instructions.text = "W / S   Forward / backward\nA / D   Turn left / right\nSpace   Brake\nEsc   Stop input"
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(instructions)
	var note := Label.new()
	note.text = "Choose WASD control, then enable Run mode. Click the 3D view before using the keyboard."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.theme_type_variation = &"SectionLabel"
	controls.add_child(note)
	blocks = BlockProgramPanel.new()
	blocks.name = "Blocks"
	program_tabs.add_child(blocks)
	blocks.source_requested.connect(func() -> void: blocks.read_source(code_edit.text))
	blocks.apply_source = _apply_blocks
	blocks.read_source(code_edit.text)
	wiring_panel = WiringPanel.new()
	wiring_panel.name = "Wiring"
	wiring_panel.assembly = assembly
	wiring_panel.can_edit = func() -> bool: return not mode_button.button_pressed
	program_tabs.add_child(wiring_panel)
	stages = StagePanel.new()
	stages.name = "Stages"
	stages.assembly = assembly
	stages.run_mode = run_mode
	stages.attempt_terminated.connect(func() -> void: runtime.stop())
	stages.source = func() -> String: return code_edit.text
	stages.pending_blocks = blocks.has_draft
	stages.outcome_changed.connect(func(message: String) -> void: _set_status(message))
	stages.context_provider = func() -> Dictionary:
		var context: Dictionary = StageDefinition.runtime_context(run_mode, assembly.graph, stages._resource_identity)
		context.board = blocks.profile.id
		context.board_api = blocks.profile.api.duplicate(true)
		context.pin_constants = blocks.profile.pin_constants.duplicate(true)
		context.sleep_unit_seconds = blocks.profile.sleep_unit_seconds
		return context
	stages.stage_requested.connect(func(stage: Dictionary) -> void:
		_request_starter(func() -> void:
			_load_preset(ProjectStore.graph_from(stage.scene), stage.scene.source, "Challenge loaded. Build your own solution.")
			stages.load_goal(stage)
			flag_mission.visible = stage.id == "raise-flag"))
	stages.lab_requested.connect(func() -> void:
		_ensure_assembly_mode()
		flag_mission.visible = false)
	program_tabs.add_child(stages)
	program_tabs.current_tab = 2
	run_button = SsokTheme.button("Run code", "play")
	run_button.theme_type_variation = &"PrimaryButton"
	run_button.add_theme_color_override("icon_normal_color", SsokTheme.BG_SUNKEN)
	run_button.pressed.connect(_on_run_pressed)
	box.add_child(run_button)
	motion_lab = MotionLabPanel.new()
	motion_lab.theme = _ui_root.theme
	motion_lab.configure(_motion_snapshot, _motion_policy, _motion_editing, _apply_motion_policy)
	add_child(motion_lab)
	motion_lab.panel_closed.connect(_close_motion_lab)
	pickup_lab = PickupLabPanel.new()
	pickup_lab.theme = _ui_root.theme
	pickup_lab.configure(_motion_snapshot, _motion_editing, _apply_pickup_policy)
	add_child(pickup_lab)
	pickup_lab.panel_closed.connect(_close_motion_lab)
	tutorial = TutorialPanel.new()
	tutorial.theme = _ui_root.theme
	add_child(tutorial)
	tutorial.panel_closed.connect(_close_tutorial)
	projects = ProjectPanel.new()
	projects.theme = _ui_root.theme
	projects.configure(_project_document, _prepare_project_document)
	add_child(projects)
	projects.panel_closed.connect(_close_projects)
	projects.project_loaded.connect(_load_project)
	projects.project_saved.connect(func(record: Dictionary) -> void:
		project_title = record.title
		_clean_workspace = _workspace_key())
	assembly.graph_changed.connect(motion_lab.refresh_apply_state)
	assembly.graph_changed.connect(_on_motion_graph_changed)
	assembly.graph_changed.connect(_refresh_workspace)
	assembly.selection_changed.connect(func(_part: PartNode) -> void: _refresh_workspace())
	assembly.transform_active_changed.connect(func(_active: bool) -> void: _refresh_workspace())

	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 12
	footer.offset_right = -12
	footer.offset_top = -46
	footer.offset_bottom = -8
	_ui_root.add_child(footer)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(status)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.theme = _ui_root.theme
	_delete_dialog.title = "Delete selected part?"
	_delete_dialog.dialog_text = "Remove the part and its connections? Ctrl+Z restores them."
	_delete_dialog.confirmed.connect(_on_delete_pressed)
	add_child(_delete_dialog)
	_replace_dialog = ConfirmationDialog.new()
	_replace_dialog.theme = _ui_root.theme
	_replace_dialog.title = "Keep your changes?"
	_replace_dialog.dialog_text = "This example will replace your assembly and code. Save a snapshot to keep your changes."
	_replace_dialog.ok_button_text = "Replace without saving"
	_replace_dialog.add_button("Save and switch", false, "save")
	_replace_dialog.confirmed.connect(_replace_with_starter)
	_replace_dialog.custom_action.connect(func(action: StringName) -> void:
		if action != &"save":
			return
		var record: Dictionary = _prepare_project_document()
		if record.has("error"):
			_set_status(record.error, true)
			return
		var result: Dictionary = ProjectStore.save(record)
		if result.has("error"):
			_set_status(result.error, true)
			return
		_replace_dialog.hide()
		_replace_with_starter())
	add_child(_replace_dialog)


func _build_help_hud() -> void:
	var tools_panel := PanelContainer.new()
	tools_panel.name = "ViewportTools"
	tools_panel.position = Vector2(260, 86)
	_ui_root.add_child(tools_panel)
	var tools := HBoxContainer.new()
	tools_panel.add_child(tools)
	for command: Array in [["Move", "move", &"translate"], ["Rotate", "rotate-3d", &"rotate"]]:
		var button := SsokTheme.button("", command[1])
		button.custom_minimum_size.x = 36
		button.tooltip_text = command[0]
		button.pressed.connect(_begin_toolbar_transform.bind(command[2]))
		_transform_buttons.append(button)
		tools.add_child(button)
	var frame := SsokTheme.button("", "maximize")
	frame.custom_minimum_size.x = 36
	frame.tooltip_text = "Frame robot"
	frame.pressed.connect(func() -> void: navigation.frame_bounds(_scene_bounds()))
	tools.add_child(frame)
	var help := SsokTheme.button("", "gamepad-2")
	help.custom_minimum_size.x = 36
	help.tooltip_text = "Controls"
	help.toggle_mode = true
	help.toggled.connect(func(show: bool) -> void: _help_panel.visible = show)
	tools.add_child(help)
	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_help_panel.offset_left = 260
	_help_panel.offset_right = -376
	_help_panel.offset_bottom = -70
	_help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help_panel.visible = false
	_ui_root.add_child(_help_panel)
	_help_label = Label.new()
	_help_label.label_settings = SsokTheme.dim_settings()
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_panel.add_child(_help_label)

	_empty_panel = PanelContainer.new()
	_empty_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_empty_panel.offset_left = -220
	_empty_panel.offset_right = 100
	_empty_panel.offset_top = -92
	_empty_panel.offset_bottom = 92
	_ui_root.add_child(_empty_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_empty_panel.add_child(box)
	var title := Label.new()
	title.text = "Raise a flag with your robot."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var detail := Label.new()
	detail.text = "Start with the servo arm, or build your own from the parts library."
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)
	var start := SsokTheme.button("Try the servo arm", "box")
	start.theme_type_variation = &"PrimaryButton"
	start.add_theme_color_override("icon_normal_color", SsokTheme.BG_SUNKEN)
	start.pressed.connect(func() -> void: flag_mission._action.pressed.emit())
	box.add_child(start)
	_refresh_workspace()


func _build_palette() -> void:
	var panel := PanelContainer.new()
	panel.name = "PartsLibrary"
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 12
	panel.offset_top = 86
	panel.offset_right = 248
	panel.offset_bottom = -58
	_ui_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Parts library"
	title.label_settings = SsokTheme.title_settings()
	box.add_child(title)
	part_search = LineEdit.new()
	part_search.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	part_search.placeholder_text = tr("Search parts...")
	part_search.clear_button_enabled = true
	part_search.right_icon = SsokTheme.icon("search")
	part_search.text_changed.connect(func(_query: String) -> void: _filter_parts())
	box.add_child(part_search)
	part_category = OptionButton.new()
	for category: String in ["All parts", "Structure", "Actuators", "Electronics", "Construction kit"]:
		part_category.add_item(category)
	part_category.focus_mode = Control.FOCUS_ALL
	part_category.item_selected.connect(func(_index: int) -> void: _filter_parts())
	box.add_child(part_category)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	_parts_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var parts_box := VBoxContainer.new()
	parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_box.add_theme_constant_override("separation", 3)
	scroll.add_child(parts_box)
	for definition: PartDef in _load_part_defs():
		var category: int = _part_category(definition)
		var icon_name: String = ["box", "box", "cog", "cpu"][category]
		var button := SsokTheme.button(definition.display_name, icon_name)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.theme_type_variation = &"QuietButton"
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = definition.display_name
		button.set_meta("part_definition", definition)
		button.set_meta("category", category)
		button.pressed.connect(_on_palette_pressed.bind(definition))
		parts_box.add_child(button)
		part_buttons.append(button)
	_no_parts = Label.new()
	_no_parts.text = "No matching parts"
	_no_parts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_parts.visible = false
	parts_box.add_child(_no_parts)
	box.add_child(HSeparator.new())
	var examples := Label.new()
	examples.text = "STARTER ROBOTS"
	examples.theme_type_variation = &"SectionLabel"
	box.add_child(examples)
	examples_menu = MenuButton.new()
	examples_menu.text = "Load an example"
	examples_menu.custom_minimum_size.y = 36
	for starter: String in ["Answer: servo arm", "Answer: biped", "Answer: humanoid (experimental)", "Answer: construction-kit humanoid", "Answer: kit bridge", "Answer: learned biped"]:
		examples_menu.get_popup().add_item(starter)
	examples_menu.get_popup().id_pressed.connect(_load_example_id)
	box.add_child(examples_menu)
	answer_button = SsokTheme.button("Answer: servo arm", "box")
	answer_button.pressed.connect(func() -> void: _request_starter(_on_microbit_arm_pressed))
	box.add_child(answer_button)
	biped_button = SsokTheme.button("Answer: biped", "box")
	biped_button.pressed.connect(func() -> void: _request_starter(_on_biped_pressed))
	box.add_child(biped_button)
	humanoid_button = SsokTheme.button("Answer: humanoid (experimental)", "box")
	humanoid_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	humanoid_button.tooltip_text = "Answer: humanoid (experimental)"
	humanoid_button.pressed.connect(func() -> void: _request_starter(_on_humanoid_pressed))
	box.add_child(humanoid_button)
	modular_button = SsokTheme.button("Answer: construction-kit humanoid", "box")
	modular_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	modular_button.tooltip_text = "Answer: construction-kit humanoid"
	modular_button.pressed.connect(func() -> void: _request_starter(_on_modular_pressed))
	box.add_child(modular_button)
	kit_bridge_button = SsokTheme.button("Answer: kit bridge", "box")
	kit_bridge_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	kit_bridge_button.tooltip_text = "Answer: kit bridge"
	kit_bridge_button.pressed.connect(func() -> void: _request_starter(_on_kit_bridge_pressed))
	box.add_child(kit_bridge_button)
	learned_biped_button = SsokTheme.button("Answer: learned biped", "box")
	learned_biped_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	learned_biped_button.tooltip_text = "Answer: learned biped"
	learned_biped_button.pressed.connect(func() -> void: _request_starter(_on_learned_biped_pressed))
	box.add_child(learned_biped_button)
	_starter_controls = [answer_button, biped_button, humanoid_button, modular_button, kit_bridge_button, learned_biped_button]
	delete_button = SsokTheme.button("Delete selected", "trash")
	delete_button.theme_type_variation = &"QuietButton"
	delete_button.pressed.connect(_on_delete_pressed)
	box.add_child(delete_button)


func _load_example_id(index: int) -> void:
	var actions: Array[Callable] = [_on_microbit_arm_pressed, _on_biped_pressed, _on_humanoid_pressed, _on_modular_pressed, _on_kit_bridge_pressed, _on_learned_biped_pressed]
	if index >= 0 and index < actions.size():
		_request_starter(actions[index])


func _workspace_key() -> String:
	var draft: String = JSON.stringify(blocks.instructions, "", true, true) if blocks != null and blocks.has_draft() else ""
	return (JSON.stringify(MotionSnapshot.encode(assembly.graph), "", true, true) + "\n" + code_edit.text + "\n" + draft).sha256_text()


func _request_starter(action: Callable) -> void:
	if projects.visible or tutorial.visible or motion_lab.visible or pickup_lab.visible:
		return
	_pending_starter = action
	if _workspace_key() != _clean_workspace:
		runtime.stop()
		manual_controller.set_enabled(false)
		motion_program.set_enabled(false)
		_replace_dialog.popup_centered()
	else:
		_replace_with_starter()


func _replace_with_starter() -> void:
	if _pending_starter.is_valid():
		var action: Callable = _pending_starter
		_pending_starter = Callable()
		action.call()


func _adapt_layout() -> void:
	if examples_menu == null:
		return
	_layout_flag_mission()
	var compact: bool = get_viewport().get_visible_rect().size.y < 800
	examples_menu.visible = compact
	for starter: Control in _starter_controls:
		starter.visible = not compact


func _layout_flag_mission() -> void:
	if flag_mission == null:
		return
	var width: float = get_viewport().get_visible_rect().size.x
	flag_mission.offset_left = 452.0 if width >= 1200.0 else 260.0
	flag_mission.offset_right = -382.0 if width >= 1200.0 else -376.0
	flag_mission.offset_top = 86.0 if width >= 1200.0 else 142.0
	flag_mission.offset_bottom = 252.0 if width >= 1200.0 else 328.0


func _camera_framing_rect() -> Rect2:
	var library: Rect2 = (_ui_root.get_node("PartsLibrary") as Control).get_global_rect()
	var program: Rect2 = _side_panel.get_global_rect()
	var tools: Rect2 = (_ui_root.get_node("ViewportTools") as Control).get_global_rect()
	var top_left: Vector2 = Vector2(library.end.x + 12.0, tools.end.y + 12.0)
	var bottom_right: Vector2 = Vector2(program.position.x - 12.0, program.end.y - 12.0)
	return Rect2(top_left, bottom_right - top_left)


func _part_category(definition: PartDef) -> int:
	if not definition.board_profile_id.is_empty() or definition.id in [&"motor_driver", &"tb6612_driver"]:
		return 3
	var id: String = String(definition.resource_path.get_file().get_basename())
	if id in ["servo", "tt_motor"] or definition.actuator_torque_nm > 0.0:
		return 2
	if id in ["arduino_uno", "board", "hc_sr04", "learning_hc_sr04", "humanoid_board", "modular_controller", "kit_controller", "kit_controller_16", "kit_optical_sensor"]:
		return 3
	return 1


func _filter_parts() -> void:
	if part_search == null:
		return
	var query: String = part_search.text.strip_edges().to_lower()
	var count: int = 0
	for button: Button in part_buttons:
		var definition: PartDef = button.get_meta("part_definition")
		var matches: bool = query.is_empty() or query in definition.display_name.to_lower() or query in tr(definition.display_name).to_lower() or query in definition.resource_path.get_file()
		var category_matches: bool = part_category.selected == 0 or part_category.selected == button.get_meta("category")
		if part_category.selected == 4:
			category_matches = String(definition.id).begins_with("kit_")
		button.visible = matches and category_matches
		count += int(button.visible)
	_no_parts.visible = count == 0


func _refresh_workspace() -> void:
	if _workspace_state == null:
		return
	SsokLocale.bind(_workspace_state, "%d parts / %d connections", [assembly.graph.parts.size(), assembly.graph.links.size()])
	if blocks != null and runtime != null:
		var graph_profile: BoardProfile = BoardProfile.new()
		for entry: Dictionary in assembly.graph.parts:
			if not entry.part_def.board_profile_id.is_empty():
				graph_profile = BoardProfile.for_id(entry.part_def.board_profile_id)
				break
		if graph_profile.id != blocks.profile.id:
			blocks.set_profile(graph_profile)
		runtime.sleep_scale = graph_profile.sleep_unit_seconds
	if _empty_panel != null:
		_empty_panel.visible = assembly.graph.parts.is_empty() and not mode_button.button_pressed
	var can_edit: bool = not mode_button.button_pressed and not assembly.transform_active and assembly.selected_part != null
	if delete_button != null:
		delete_button.disabled = not can_edit
	for button: Button in _transform_buttons:
		button.disabled = not can_edit
	for part: PartNode in assembly._part_nodes:
		if String(part.part_def.id).begins_with("kit_"):
			var hints: MultiMeshInstance3D = part.get_node_or_null("PortHints") as MultiMeshInstance3D
			if hints != null:
				hints.visible = part == assembly.selected_part or assembly.transform_active


func _begin_toolbar_transform(kind: StringName) -> void:
	if not mode_button.button_pressed and assembly.selected_part != null:
		get_viewport().gui_release_focus()
		assembly.begin_transform(kind)


func _load_part_defs() -> Array[PartDef]:
	var definitions: Array[PartDef] = []
	for directory: String in [PARTS_DIR, HumanoidPreset.CATALOG, "res://assets/modular_humanoid/parts/", "res://assets/construction_kit/parts/", YawBipedPreset.CATALOG]:
		var names: PackedStringArray = ResourceLoader.list_directory(directory)
		names.sort()
		for file_name: String in names:
			if not file_name.ends_with(".tres") or file_name.contains("/"):
				continue
			var definition: PartDef = load(directory.path_join(file_name)) as PartDef
			if definition != null:
				definitions.append(definition)
	return definitions


func _on_palette_pressed(definition: PartDef) -> void:
	_ensure_assembly_mode()
	var column := _spawn_count % 4
	var row := _spawn_count / 4
	_spawn_count += 1
	var position := Vector3(-0.1 + 0.07 * column, ServoArmPreset.FLOOR_TOP + 0.03, 0.08 + 0.07 * row)
	var part := assembly.spawn_part(definition, Transform3D(Basis.IDENTITY, position))
	if part == null:
		return
	_colorize(part)
	_mark_ports(part)
	assembly.select_part(part)
	_set_status("Added %s - G to move, R to rotate, Enter to confirm", false, [definition.display_name], [0])
	get_viewport().gui_release_focus()


func _on_delete_pressed() -> void:
	if mode_button.button_pressed or assembly.transform_active:
		_set_status("Return to edit mode and finish the current transform before deleting")
		return
	if assembly.remove_selected():
		_set_status("part removed")
	else:
		_set_status("click a part first, then delete it")


func _on_answer_pressed() -> void:
	_load_preset(ServoArmPreset.build(), ServoArmPreset.ANSWER_CODE, "answer loaded - the finished servo arm")


func _on_biped_pressed() -> void:
	_load_preset(BipedPreset.build(), BipedPreset.ANSWER_CODE, "Biped loaded - Run mode for WASD / stick movement, or Run code for the stepping example")


func _on_learned_biped_pressed() -> void:
	_load_preset(YawBipedPreset.build(), "# This example uses a frozen learned policy in manual control.\n# Switch to learner code to program the graph-wired motors yourself.\n", "Learned biped loaded. Choose Run mode, then hold W to walk forward.")
	control_source.select(CONTROL_MANUAL)
	program_tabs.current_tab = 1
	_refresh_control_ui()


func _on_humanoid_pressed() -> void:
	_load_preset(HumanoidPreset.build(), "# Humanoid joints use the virtual controller's wired pins.\n", "Humanoid loaded. W/S walk, Shift sprint trial, E pick up or release. A/D turning is not supported yet.")
	control_source.select(CONTROL_MANUAL)
	program_tabs.current_tab = 1


func _on_modular_pressed() -> void:
	var graph: ConnectionGraph = ConstructionKitHumanoidPreset.build()
	_load_preset(graph, ConstructionKitHumanoidPreset.answer_code(graph), "Construction-kit humanoid loaded. Each beam, plate, bracket and connector is a separate part. Select a part to inspect its holes; G moves it.")
	part_category.select(4)
	_filter_parts()
	control_source.select(CONTROL_MANUAL)
	program_tabs.current_tab = 1


func _on_kit_bridge_pressed() -> void:
	_load_preset(ConstructionKitHumanoidPreset.build_bridge(), "", "Kit bridge loaded: the same beams, plates and fasteners, assembled into a different structure.")
	part_category.select(4)
	_filter_parts()


func _load_preset(graph: ConnectionGraph, code: String, message: String) -> void:
	_ensure_assembly_mode()
	assembly.load_graph(graph)
	_colorize(assembly)
	_mark_ports(assembly)
	code_edit.text = code
	var profile: BoardProfile = BoardProfile.new()
	for part: Dictionary in graph.parts:
		if not part.part_def.board_profile_id.is_empty():
			profile = BoardProfile.for_id(part.part_def.board_profile_id)
			break
	blocks.set_profile(profile)
	runtime.sleep_scale = profile.sleep_unit_seconds
	blocks.reset_source(code)
	stages.clear_goal()
	_clean_workspace = _workspace_key()
	navigation.frame_bounds(assembly.get_scene_bounds())
	_set_status(message)
	get_viewport().gui_release_focus()


func _ensure_assembly_mode() -> void:
	if mode_button.button_pressed:
		mode_button.button_pressed = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB \
			and not event.is_command_or_control_pressed() and not event.alt_pressed \
			and get_viewport().gui_get_focus_owner() == null \
			and not (projects.visible or tutorial.visible or motion_lab.visible or pickup_lab.visible or _replace_dialog.visible or _delete_dialog.visible):
		projects_button.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and get_viewport().gui_get_focus_owner() == code_edit:
		program_tabs.get_tab_bar().grab_focus()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if mode_button.button_pressed and event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT and get_viewport().gui_get_hovered_control() == null:
			get_viewport().gui_release_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if key_event.is_command_or_control_pressed() and key_event.keycode == KEY_S:
		_open_projects()
		get_viewport().set_input_as_handled()
		return
	if focus != null:
		if key_event.keycode == KEY_ESCAPE:
			get_viewport().gui_release_focus()
			get_viewport().set_input_as_handled()
		return
	if mode_button.button_pressed:
		if key_event.keycode == KEY_ESCAPE:
			_on_stop_pressed()
			get_viewport().set_input_as_handled()
		return
	if assembly.transform_active:
		return
	if key_event.keycode == KEY_DELETE:
		_on_delete_pressed()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_X and not key_event.ctrl_pressed and not key_event.alt_pressed:
		if assembly.selected_part != null:
			_delete_dialog.popup_centered()
			get_viewport().set_input_as_handled()


func _on_mode_toggled(run: bool) -> void:
	runtime.stop()
	manual_controller.set_enabled(false)
	motion_program.set_enabled(false)
	assembly.cancel_transform()
	if run:
		run_mode.build(assembly.graph)
		_colorize(run_mode)
		assembly.visible = false
		assembly.process_mode = Node.PROCESS_MODE_DISABLED
		manual_controller.configure(run_mode)
		motion_program.configure(run_mode, assembly.graph)
		_apply_control_source()
		flag_mission.on_run_mode_changed(true)
	else:
		flag_mission.on_run_mode_changed(false)
		stages.on_stop()
		navigation.track_displacement(-_follow_offset)
		_follow_offset = Vector3.ZERO
		_follow_body = null
		manual_controller.configure(null)
		motion_program.configure(null, null)
		run_mode.teardown()
		assembly.visible = true
		assembly.process_mode = Node.PROCESS_MODE_INHERIT
		_set_status("Edit mode - G move / R rotate / X,Y,Z constrain / Esc cancel")
	_refresh_control_ui()
	get_viewport().gui_release_focus()


func _on_run_pressed() -> void:
	if runtime.is_running() or motion_lab.visible or tutorial.visible or pickup_lab.visible:
		return
	if blocks.has_draft() and not blocks._apply():
		return
	var validation: Dictionary = runtime.validate(code_edit.text, false)
	if not validation.is_empty():
		_show_code_failure(validation.line, runtime._translated_error(validation), int(validation.get("column", 1)))
		return
	program_tabs.current_tab = 0
	control_source.select(CONTROL_CODE)
	manual_controller.set_enabled(false)
	if not mode_button.button_pressed:
		mode_button.button_pressed = true
	_apply_control_source()
	flag_mission.on_run_mode_changed(true)
	validation = runtime.validate(code_edit.text)
	if not validation.is_empty():
		_show_code_failure(validation.line, runtime._translated_error(validation), int(validation.get("column", 1)))
		return
	if not stages.on_run():
		runtime.stop()
		_refresh_control_ui()
		return
	runtime.run(code_edit.text)
	_refresh_control_ui()


func _show_code_failure(line: int, message: String, column: int) -> void:
	_set_status("line %d: %s", true, [line, message])
	for index: int in code_edit.get_line_count():
		code_edit.set_line_background_color(index, Color(0.6, 0.15, 0.1, 0.5) if index == line - 1 else Color.TRANSPARENT)
	code_edit.set_caret_line(clampi(line - 1, 0, code_edit.get_line_count() - 1))
	code_edit.set_caret_column(maxi(0, column - 1))
	blocks.highlight_line(line)


func _on_control_source_selected(_index: int) -> void:
	program_tabs.current_tab = 1 if control_source.selected == CONTROL_MANUAL else 0
	_apply_control_source()
	get_viewport().gui_release_focus()


func _apply_control_source() -> void:
	runtime.stop()
	var manual: bool = mode_button.button_pressed and control_source.selected == CONTROL_MANUAL and not motion_lab.visible and not tutorial.visible and not pickup_lab.visible
	motion_program.set_enabled(manual and motion_program.is_supported())
	manual_controller.set_enabled(manual and motion_program.is_supported())
	if mode_button.button_pressed:
		if manual:
			if motion_program is HumanoidMotion or motion_program is BundledBipedMotion or not motion_program.is_supported():
				_on_program_status_changed(motion_program.get_status())
			else:
				_set_status("W/S forward/back · A/D turn · left stick · Space stop")
		else:
			_set_status("Code control - press Run code; movement inputs are disabled")
	_refresh_control_ui()


func _on_stop_pressed() -> void:
	flag_mission.on_stop_pressed()
	stages.on_stop()
	runtime.stop()
	manual_controller.set_enabled(false)
	motion_program.set_enabled(false)
	control_source.select(CONTROL_CODE)
	_set_status("Input stopped - servos hold their last targets; return to edit mode to reset the robot")
	_refresh_control_ui()


func _open_motion_lab() -> void:
	if motion_program is BundledBipedMotion:
		_set_status(BundledBipedMotion.HELP)
		return
	if tutorial.visible or _delete_dialog.visible or motion_lab.visible or pickup_lab.visible or projects.visible:
		return
	runtime.stop()
	manual_controller.set_enabled(false)
	motion_program.set_enabled(false)
	assembly.cancel_transform()
	assembly.process_mode = Node.PROCESS_MODE_DISABLED
	navigation.navigation_enabled = false
	get_viewport().gui_release_focus()
	if motion_program is HumanoidMotion:
		pickup_lab.open_panel()
	else:
		motion_lab.open_panel()


func _close_motion_lab() -> void:
	assembly.process_mode = Node.PROCESS_MODE_DISABLED if mode_button.button_pressed else Node.PROCESS_MODE_INHERIT
	navigation.navigation_enabled = true
	get_viewport().gui_release_focus()
	_set_status("Motion lab closed. Movement remains stopped; select WASD control or toggle Run mode when ready.")
	_refresh_control_ui()


func _open_tutorial() -> void:
	if motion_lab.visible or _delete_dialog.visible or tutorial.visible or pickup_lab.visible or projects.visible:
		return
	runtime.stop()
	manual_controller.set_enabled(false)
	motion_program.set_enabled(false)
	assembly.cancel_transform()
	assembly.process_mode = Node.PROCESS_MODE_DISABLED
	navigation.navigation_enabled = false
	get_viewport().gui_release_focus()
	tutorial.open_panel()
	_refresh_control_ui()


func _close_tutorial() -> void:
	assembly.process_mode = Node.PROCESS_MODE_DISABLED if mode_button.button_pressed else Node.PROCESS_MODE_INHERIT
	navigation.navigation_enabled = true
	get_viewport().gui_release_focus()
	_set_status("Tutorial closed. Input remains stopped; select WASD control or toggle Run mode when ready.")
	_refresh_control_ui()


func _motion_snapshot() -> Dictionary:
	return MotionSnapshot.encode(assembly.graph)


func _project_document() -> Dictionary:
	return ProjectStore.document(project_title, assembly.graph, code_edit.text)


func _prepare_project_document() -> Dictionary:
	if blocks.has_draft() and not blocks._apply():
		return {"error": "Resolve the block editor error before saving or exporting. Your changes are kept."}
	return _project_document()


func _apply_blocks(source: String) -> bool:
	if code_edit.text != blocks._source_at_load:
		SsokLocale.bind(blocks.feedback, "Code changed after these blocks were loaded. Read from code before applying.")
		return false
	code_edit.text = source
	_set_status("Code updated. Run code to try your program.")
	return true


func _open_projects() -> void:
	if tutorial.visible or _delete_dialog.visible or motion_lab.visible or pickup_lab.visible or projects.visible:
		return
	runtime.stop()
	manual_controller.set_enabled(false)
	motion_program.set_enabled(false)
	assembly.cancel_transform()
	assembly.process_mode = Node.PROCESS_MODE_DISABLED
	navigation.navigation_enabled = false
	projects.open_panel()


func _close_projects() -> void:
	assembly.process_mode = Node.PROCESS_MODE_DISABLED if mode_button.button_pressed else Node.PROCESS_MODE_INHERIT
	navigation.navigation_enabled = true
	projects_button.grab_focus()
	_refresh_control_ui()


func _load_project(record: Dictionary) -> void:
	if not ProjectStore.valid(record):
		return
	project_title = record.title
	_load_preset(ProjectStore.graph_from(record), record.source, "Project opened. Code runs only when you press Run code.")
	control_source.select(CONTROL_CODE)
	_refresh_control_ui()


func _motion_policy() -> Dictionary:
	return MotionPolicy.read(motion_program as BipedMotion)


func _motion_editing() -> bool:
	return not mode_button.button_pressed and not assembly.transform_active


func _apply_pickup_policy(policy: Dictionary, fingerprint: String) -> bool:
	if not _motion_editing() or not motion_program is HumanoidMotion or fingerprint != MotionSnapshot.fingerprint(_motion_snapshot()):
		return false
	if not PickupPolicy.apply(motion_program, policy):
		return false
	_applied_pickup_fingerprint = fingerprint
	control_source.select(CONTROL_MANUAL)
	_refresh_control_ui()
	return true


func _apply_motion_policy(policy: Dictionary, fingerprint: String) -> bool:
	if not _motion_editing() or fingerprint != MotionSnapshot.fingerprint(_motion_snapshot()):
		return false
	if not MotionPolicy.validate(policy).is_empty():
		return false
	runtime.stop()
	manual_controller.set_enabled(false)
	motion_program.set_enabled(false)
	if not MotionPolicy.apply(motion_program as BipedMotion, policy):
		return false
	_applied_motion_fingerprint = fingerprint
	control_source.select(CONTROL_MANUAL)
	_set_status("Evaluated parameters applied to the WASD program; assembly and learner source are unchanged")
	_refresh_control_ui()
	return true


func _on_motion_graph_changed() -> void:
	var humanoid: bool = false
	var learned: bool = false
	var construction: bool = KitHumanoidMotion.recognizes(assembly.graph)
	for entry: Dictionary in assembly.graph.parts:
		humanoid = humanoid or entry.part_def.id in [&"humanoid_torso", &"modular_torso_frame"]
		learned = learned or entry.part_def.id == &"yaw_biped_body"
	if learned != (motion_program is BundledBipedMotion) or construction != (motion_program is KitHumanoidMotion) or (humanoid or construction) != (motion_program is HumanoidMotion):
		motion_program.set_enabled(false)
		remove_child(motion_program)
		motion_program.queue_free()
		motion_program = BundledBipedMotion.new() if learned else (KitHumanoidMotion.new() if construction else (HumanoidMotion.new() if humanoid else BipedMotion.new()))
		add_child(motion_program)
		motion_program.status_changed.connect(_on_program_status_changed)
	motion_lab_button.disabled = learned
	if not _applied_pickup_fingerprint.is_empty() and _applied_pickup_fingerprint != MotionSnapshot.fingerprint(_motion_snapshot()):
		if motion_program is HumanoidMotion:
			PickupPolicy.apply(motion_program, PickupPolicy.defaults())
		_applied_pickup_fingerprint = ""
	if _applied_motion_fingerprint.is_empty() or _applied_motion_fingerprint == MotionSnapshot.fingerprint(_motion_snapshot()):
		return
	MotionPolicy.apply(motion_program as BipedMotion, MotionPolicy.defaults())
	_applied_motion_fingerprint = ""
	_set_status("Assembly changed: evaluated motion parameters reset to the experimental defaults. Search again for this graph.")


func _on_program_status_changed(_message: String) -> void:
	var translated_arguments: Array[int] = []
	for index: int in range(motion_program._status_arguments.size()):
		translated_arguments.append(index)
	_set_status(motion_program._status, false, motion_program._status_arguments, translated_arguments)
	_refresh_manual_status()


func _refresh_control_ui() -> void:
	_refresh_workspace()
	if control_source == null:
		return
	var running: bool = mode_button.button_pressed
	stop_button.disabled = not running
	_refresh_manual_status()
	if wiring_panel != null:
		wiring_panel.refresh_actions()
	if _help_label != null:
		var camera_help: String = "MMB orbit · Shift+MMB pan · wheel zoom · Numpad 1/3/7 views · Numpad . frame"
		var edit_help: String = "LMB select · G move / R rotate · X/Y/Z axis · number: mm / degrees · Enter/LMB confirm · Esc/RMB cancel · Ctrl+Z undo"
		var run_help: String = "W/S forward/back · A/D turn · left stick · Space/gamepad A brake · Esc stop input"
		if motion_program is HumanoidMotion:
			run_help = "Humanoid loaded. W/S walk, Shift sprint trial, E pick up or release. A/D turning is not supported yet."
		elif motion_program is BundledBipedMotion:
			run_help = BundledBipedMotion.HELP
		if control_source.selected == CONTROL_CODE:
			run_help = "Code control · Run code to start · Stop input / code to cancel · Esc stops"
		_help_label.text = tr(camera_help) + "\n" + tr(run_help if running else edit_help)


func _refresh_manual_status() -> void:
	if _manual_status == null:
		return
	if motion_program is BundledBipedMotion:
		_movement_instructions.visible = false
		_manual_status.text = tr(BundledBipedMotion.HELP)
		if control_source.selected == CONTROL_CODE:
			_manual_status.text = tr("Code owns the motors. Keyboard/gamepad control is off.")
		elif mode_button.button_pressed and not motion_program.is_supported():
			_manual_status.text = tr(BundledBipedMotion.MISMATCH)
		return
	if motion_program is HumanoidMotion:
		_movement_instructions.visible = false
		_manual_status.text = tr("Humanoid experiment: W/S walk, Shift running experiment (unstable), E pick/release. The gripper needs contact with both hands. AI lab: parallel pickup search; no GPT weight training.")
		if mode_button.button_pressed:
			_manual_status.text += "\n\n" + motion_program.get_status()
		return
	_movement_instructions.visible = true
	if not mode_button.button_pressed:
		_manual_status.text = "Choose a control source, then enter Run mode.\nPart dimensions are fixed; G uses mm and R uses degrees."
	elif control_source.selected == CONTROL_CODE:
		_manual_status.text = "Code owns the motors. Keyboard/gamepad control is off."
	elif not motion_program.is_supported():
		_manual_status.text = tr(motion_program.get_status()) + "\n" + tr("Load Answer: biped for the movement example.")
	else:
		var devices: PackedInt32Array = Input.get_connected_joypads()
		var gamepad: String = tr("Keyboard ready · no gamepad detected")
		if not devices.is_empty():
			var active_device: int = manual_controller.get_active_gamepad()
			gamepad = tr("Gamepad: %s") % Input.get_joy_name(active_device if active_device in devices else devices[0])
		var command: Vector2 = manual_controller.get_move_input()
		_manual_status.text = tr("Biped demo: experimental gait (slow / drift)\nForward %+.2f · Turn %+.2f\n%s") % [command.y, command.x, gamepad]


func _set_status(text: String, is_error: bool = false, arguments: Array = [], translated_arguments: Array[int] = []) -> void:
	SsokLocale.bind(status, text, arguments, translated_arguments)
	status.tooltip_text = status.text
	status.modulate = Color(1, 0.4, 0.4) if is_error else Color.WHITE


func _on_language_selected(index: int) -> void:
	var error: Error = SsokLocale.select_locale(SsokLocale.LOCALES[index])
	if error != OK:
		_set_status("Language changed, but the preference could not be saved.", true)
	get_viewport().gui_release_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		language_picker.select(SsokLocale.LOCALES.find(SsokLocale.normalize(TranslationServer.get_locale())))
		language_picker.tooltip_text = tr("Language")
		_refresh_control_ui()
		_filter_parts()
		part_search.placeholder_text = tr("Search parts...")
		program_tabs.set_tab_title(0, tr("Code"))
		program_tabs.set_tab_title(1, tr("Controls"))
		program_tabs.set_tab_title(2, tr("Blocks"))
		program_tabs.set_tab_title(3, tr("Wiring"))
		program_tabs.set_tab_title(4, tr("Stages"))


func _dress_scene() -> void:
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.50, 0.64, 0.86)
	sky_material.sky_horizon_color = Color(0.84, 0.89, 0.95)
	sky_material.ground_horizon_color = Color(0.84, 0.89, 0.95)
	sky_material.ground_bottom_color = Color(0.42, 0.44, 0.47)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.35
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var floor_mesh := $Floor/MeshInstance3D as MeshInstance3D
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.52, 0.49, 0.44)
	floor_material.roughness = 0.9
	floor_mesh.material_override = floor_material


## Batch the per-hole hints so a kit with hundreds of attachment points stays usable.
static func _mark_ports(root: Node) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.2, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.1)
	var sphere := SphereMesh.new()
	sphere.radius = 0.0025
	sphere.height = 0.005
	sphere.radial_segments = 8
	sphere.rings = 4
	var groups: Dictionary = {}
	for marker in root.find_children("*", "Marker3D", true, false):
		if marker.has_meta(&"ssok_port_marker"):
			continue
		marker.set_meta(&"ssok_port_marker", true)
		var part: Node3D = marker.get_parent() as Node3D
		if not groups.has(part):
			groups[part] = []
		groups[part].append(marker.transform)
	for part: Node3D in groups:
		var hints := MultiMeshInstance3D.new()
		hints.name = "PortHints"
		hints.visible = not (part is PartNode and String(part.part_def.id).begins_with("kit_"))
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = sphere
		multi.instance_count = groups[part].size()
		for index: int in range(multi.instance_count):
			multi.set_instance_transform(index, groups[part][index])
		hints.multimesh = multi
		hints.material_override = material
		part.add_child(hints)


## Fallback tint for placeholder meshes that ship without materials.
static func _colorize(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh.get_surface_count() > 0 and mesh.mesh.surface_get_material(0) != null:
			continue
		var owner_name := String(mesh.get_parent().name)
		for part_id: StringName in PART_COLORS:
			if owner_name.begins_with(String(part_id)):
				var material := StandardMaterial3D.new()
				material.albedo_color = PART_COLORS[part_id]
				mesh.material_override = material
				break


func _practice_flag_arm() -> void:
	var graph: ConnectionGraph = ServoArmPreset.build_microbit()
	graph.links.pop_back()
	graph.links.remove_at(1)
	graph.parts[2].transform.origin = Vector3(-0.13, 0.11, 0)
	_load_preset(graph, ServoArmPreset.microbit_code(), "Connect the loose arm, then wire its servo to a board pin.")
	flag_mission.visible = true
	program_tabs.current_tab = 2


func _on_microbit_arm_pressed() -> void:
	_load_preset(ServoArmPreset.build_microbit(), ServoArmPreset.microbit_code(), "answer loaded - the finished servo arm")
	flag_mission.visible = true
