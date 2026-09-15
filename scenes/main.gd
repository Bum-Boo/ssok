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
var mode_button: CheckButton
var run_button: Button
var answer_button: Button
var biped_button: Button
var navigation: BlenderCamera
var manual_controller: ManualController
var motion_program: RobotMotionProgram
var control_source: OptionButton
var stop_button: Button
var motion_lab_button: Button
var motion_lab: MotionLabPanel
var _manual_status: Label
var _help_label: Label
var _delete_dialog: ConfirmationDialog
var _applied_motion_fingerprint: String = ""

var _ui_root: Control
var _spawn_count := 0


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
	runtime.line_started.connect(func(n: int) -> void: _set_status("running line %d" % n))
	runtime.finished.connect(func() -> void: _set_status("finished"))
	runtime.failed.connect(func(n: int, msg: String) -> void: _set_status("line %d: %s" % [n, msg], true))
	add_child(runtime)
	manual_controller = ManualController.new()
	add_child(manual_controller)
	motion_program = BipedMotion.new()
	add_child(motion_program)
	manual_controller.movement_changed.connect(func(throttle: float, turn: float) -> void: motion_program.set_move_input(Vector2(turn, throttle)))
	manual_controller.state_changed.connect(_refresh_manual_status)

	_build_ui()
	_build_palette()
	_build_help_hud()
	_refresh_control_ui()
	_set_status("Edit mode - select a part, then G to move or R to rotate; connections snap at ports")
	get_viewport().gui_release_focus()


func _process(_delta: float) -> void:
	_refresh_manual_status()


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

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -372
	panel.offset_top = 12
	panel.offset_right = -12
	panel.offset_bottom = -12
	_ui_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var title := Label.new()
	title.text = "ssok - robot workshop"
	title.label_settings = SsokTheme.title_settings()
	box.add_child(title)

	mode_button = CheckButton.new()
	mode_button.text = "Run mode (physics)"
	mode_button.focus_mode = Control.FOCUS_NONE
	mode_button.toggled.connect(_on_mode_toggled)
	box.add_child(mode_button)

	control_source = OptionButton.new()
	control_source.add_item("Control: WASD / gamepad movement", CONTROL_MANUAL)
	control_source.add_item("Control: Learner code", CONTROL_CODE)
	control_source.focus_mode = Control.FOCUS_NONE
	control_source.item_selected.connect(_on_control_source_selected)
	box.add_child(control_source)

	_manual_status = Label.new()
	_manual_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_manual_status.add_theme_font_size_override("font_size", 13)
	box.add_child(_manual_status)

	code_edit = CodeEdit.new()
	code_edit.text = ServoArmPreset.ANSWER_CODE
	code_edit.gutters_draw_line_numbers = true
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(code_edit)

	run_button = Button.new()
	run_button.text = "Run code"
	run_button.focus_mode = Control.FOCUS_NONE
	run_button.pressed.connect(_on_run_pressed)
	box.add_child(run_button)
	stop_button = Button.new()
	stop_button.text = "Stop input / code"
	stop_button.focus_mode = Control.FOCUS_NONE
	stop_button.pressed.connect(_on_stop_pressed)
	box.add_child(stop_button)
	motion_lab_button = Button.new()
	motion_lab_button.text = "AI motion lab"
	motion_lab_button.focus_mode = Control.FOCUS_NONE
	motion_lab_button.pressed.connect(_open_motion_lab)
	box.add_child(motion_lab_button)
	motion_lab = MotionLabPanel.new()
	motion_lab.theme = _ui_root.theme
	motion_lab.configure(_motion_snapshot, _motion_policy, _motion_editing, _apply_motion_policy)
	add_child(motion_lab)
	motion_lab.panel_closed.connect(_close_motion_lab)
	assembly.graph_changed.connect(motion_lab.refresh_apply_state)
	assembly.graph_changed.connect(_on_motion_graph_changed)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete selected part?"
	_delete_dialog.dialog_text = "Remove the part and its connections? Ctrl+Z restores them."
	_delete_dialog.confirmed.connect(_on_delete_pressed)
	add_child(_delete_dialog)


## A one-line control reminder pinned to the top of the assembly view.
func _build_help_hud() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 204
	panel.offset_right = -384
	panel.offset_bottom = -12
	_ui_root.add_child(panel)

	_help_label = Label.new()
	_help_label.label_settings = SsokTheme.dim_settings()
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_help_label)


func _build_palette() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = 192
	panel.offset_bottom = -12
	_ui_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var title := Label.new()
	title.text = "Parts"
	title.label_settings = SsokTheme.title_settings()
	box.add_child(title)

	# The part list scrolls so the action buttons below stay reachable as parts are added.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var parts_box := VBoxContainer.new()
	parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(parts_box)
	for definition: PartDef in _load_part_defs():
		var button := Button.new()
		button.text = definition.display_name
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_palette_pressed.bind(definition))
		parts_box.add_child(button)

	box.add_child(HSeparator.new())
	var delete_button := Button.new()
	delete_button.text = "Delete selected"
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.pressed.connect(_on_delete_pressed)
	box.add_child(delete_button)

	answer_button = Button.new()
	answer_button.text = "Answer: servo arm"
	answer_button.focus_mode = Control.FOCUS_NONE
	answer_button.pressed.connect(_on_answer_pressed)
	box.add_child(answer_button)

	biped_button = Button.new()
	biped_button.text = "Answer: biped"
	biped_button.focus_mode = Control.FOCUS_NONE
	biped_button.pressed.connect(_on_biped_pressed)
	box.add_child(biped_button)


func _load_part_defs() -> Array[PartDef]:
	var definitions: Array[PartDef] = []
	var dir := DirAccess.open(PARTS_DIR)
	if dir == null:
		push_error("cannot open %s" % PARTS_DIR)
		return definitions
	var names := Array(dir.get_files())
	names.sort()
	for file_name: String in names:
		# Exported PCKs list resources as "*.tres.remap".
		var resource_name := file_name.trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		var definition := load(PARTS_DIR.path_join(resource_name)) as PartDef
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
	_colorize(part)
	_mark_ports(part)
	assembly.select_part(part)
	_set_status("Added %s - G to move, R to rotate, Enter to confirm" % definition.display_name)
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


func _load_preset(graph: ConnectionGraph, code: String, message: String) -> void:
	_ensure_assembly_mode()
	assembly.load_graph(graph)
	_colorize(assembly)
	_mark_ports(assembly)
	code_edit.text = code
	navigation.frame_bounds(assembly.get_scene_bounds())
	_set_status(message)
	get_viewport().gui_release_focus()


func _ensure_assembly_mode() -> void:
	if mode_button.button_pressed:
		mode_button.button_pressed = false


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
	if focus is TextEdit or focus is LineEdit:
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
	else:
		manual_controller.configure(null)
		motion_program.configure(null, null)
		run_mode.teardown()
		assembly.visible = true
		assembly.process_mode = Node.PROCESS_MODE_INHERIT
		_set_status("Edit mode - G move / R rotate / X,Y,Z constrain / Esc cancel")
	_refresh_control_ui()
	get_viewport().gui_release_focus()


func _on_run_pressed() -> void:
	if runtime.is_running() or motion_lab.visible:
		return
	control_source.select(CONTROL_CODE)
	manual_controller.set_enabled(false)
	if not mode_button.button_pressed:
		mode_button.button_pressed = true
	_apply_control_source()
	runtime.run(code_edit.text)
	_refresh_control_ui()


func _on_control_source_selected(_index: int) -> void:
	_apply_control_source()
	get_viewport().gui_release_focus()


func _apply_control_source() -> void:
	runtime.stop()
	var manual: bool = mode_button.button_pressed and control_source.selected == CONTROL_MANUAL and not motion_lab.visible
	motion_program.set_enabled(manual and motion_program.is_supported())
	manual_controller.set_enabled(manual and motion_program.is_supported())
	if mode_button.button_pressed:
		if manual:
			_set_status("W/S forward/back · A/D turn · left stick · Space stop" if motion_program.is_supported() else motion_program.get_status())
		else:
			_set_status("Code control - press Run code; movement inputs are disabled")
	_refresh_control_ui()


func _on_stop_pressed() -> void:
	runtime.stop()
	manual_controller.set_enabled(false)
	motion_program.set_enabled(false)
	control_source.select(CONTROL_CODE)
	_set_status("Input stopped - servos hold their last targets; return to edit mode to reset the robot")
	_refresh_control_ui()


func _open_motion_lab() -> void:
	runtime.stop()
	manual_controller.set_enabled(false)
	motion_program.set_enabled(false)
	assembly.cancel_transform()
	assembly.process_mode = Node.PROCESS_MODE_DISABLED
	navigation.navigation_enabled = false
	get_viewport().gui_release_focus()
	motion_lab.open_panel()


func _close_motion_lab() -> void:
	assembly.process_mode = Node.PROCESS_MODE_DISABLED if mode_button.button_pressed else Node.PROCESS_MODE_INHERIT
	navigation.navigation_enabled = true
	get_viewport().gui_release_focus()
	_set_status("Motion lab closed. Movement remains stopped; select WASD control or toggle Run mode when ready.")
	_refresh_control_ui()


func _motion_snapshot() -> Dictionary:
	return MotionSnapshot.encode(assembly.graph)


func _motion_policy() -> Dictionary:
	return MotionPolicy.read(motion_program as BipedMotion)


func _motion_editing() -> bool:
	return not mode_button.button_pressed and not assembly.transform_active


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
	if _applied_motion_fingerprint.is_empty() or _applied_motion_fingerprint == MotionSnapshot.fingerprint(_motion_snapshot()):
		return
	MotionPolicy.apply(motion_program as BipedMotion, MotionPolicy.defaults())
	_applied_motion_fingerprint = ""
	_set_status("Assembly changed: evaluated motion parameters reset to the experimental defaults. Search again for this graph.")


func _refresh_control_ui() -> void:
	if control_source == null:
		return
	var running: bool = mode_button.button_pressed
	stop_button.disabled = not running
	_refresh_manual_status()
	if _help_label != null:
		var camera_help: String = "MMB orbit · Shift+MMB pan · wheel zoom · Numpad 1/3/7 views · Numpad . frame"
		var edit_help: String = "LMB select · G move / R rotate · X/Y/Z axis · number: mm / degrees · Enter/LMB confirm · Esc/RMB cancel · Ctrl+Z undo"
		var run_help: String = "W/S forward/back · A/D turn · left stick · Space/gamepad A brake · Esc stop input"
		if control_source.selected == CONTROL_CODE:
			run_help = "Code control · Run code to start · Stop input / code to cancel · Esc stops"
		_help_label.text = camera_help + "\n" + (run_help if running else edit_help)


func _refresh_manual_status() -> void:
	if _manual_status == null:
		return
	if not mode_button.button_pressed:
		_manual_status.text = "Choose a control source, then enter Run mode.\nPart dimensions are fixed; G uses mm and R uses degrees."
	elif control_source.selected == CONTROL_CODE:
		_manual_status.text = "Code owns the motors. Keyboard/gamepad control is off."
	elif not motion_program.is_supported():
		_manual_status.text = motion_program.get_status() + "\nLoad Answer: biped for the movement example."
	else:
		var devices: PackedInt32Array = Input.get_connected_joypads()
		var gamepad: String = "Keyboard ready · no gamepad detected"
		if not devices.is_empty():
			var active_device: int = manual_controller.get_active_gamepad()
			gamepad = "Gamepad: " + Input.get_joy_name(active_device if active_device in devices else devices[0])
		var command: Vector2 = manual_controller.get_move_input()
		_manual_status.text = "Biped demo: experimental gait (slow / drift)\nForward %+.2f · Turn %+.2f\n%s" % [command.y, command.x, gamepad]


func _set_status(text: String, is_error: bool = false) -> void:
	status.text = text
	status.modulate = Color(1, 0.4, 0.4) if is_error else Color.WHITE


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
	floor_material.albedo_color = Color(0.55, 0.56, 0.55)
	floor_material.roughness = 0.9
	floor_mesh.material_override = floor_material


## Small translucent spheres on every port so learners can see where parts snap.
static func _mark_ports(root: Node) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.2, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.1)
	var sphere := SphereMesh.new()
	sphere.radius = 0.0025
	sphere.height = 0.005
	for marker in root.find_children("*", "Marker3D", true, false):
		if marker.has_meta(&"ssok_port_marker"):
			continue
		marker.set_meta(&"ssok_port_marker", true)
		var dot := MeshInstance3D.new()
		dot.mesh = sphere
		dot.material_override = material
		marker.add_child(dot)


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
