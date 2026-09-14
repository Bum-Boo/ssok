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

var assembly: AssemblyMode
var run_mode: RunMode
var runtime: MiniRuntime
var code_edit: CodeEdit
var status: Label
var mode_button: CheckButton
var run_button: Button
var answer_button: Button
var biped_button: Button

var _ui_root: Control
var _spawn_count := 0


func _ready() -> void:
	var camera := $Camera3D as Camera3D
	camera.look_at_from_position(Vector3(0.2, 0.18, 0.26), Vector3(0.05, 0.09, 0))
	camera.fov = 45.0
	add_child(FlyCamera.new(camera))
	_dress_scene()

	assembly = AssemblyMode.new()
	add_child(assembly)

	run_mode = RunMode.new()
	add_child(run_mode)

	runtime = MiniRuntime.new()
	runtime.hardware = run_mode
	runtime.line_started.connect(func(n: int) -> void: _set_status("running line %d" % n))
	runtime.finished.connect(func() -> void: _set_status("finished"))
	runtime.failed.connect(func(n: int, msg: String) -> void: _set_status("line %d: %s" % [n, msg], true))
	add_child(runtime)

	_build_ui()
	_build_palette()
	_build_help_hud()
	_set_status("assembly mode - pick parts from the left panel; they snap at ports")


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
	title.text = "ssok - servo arm (slice 1)"
	title.label_settings = SsokTheme.title_settings()
	box.add_child(title)

	mode_button = CheckButton.new()
	mode_button.text = "Run mode (physics)"
	mode_button.toggled.connect(_on_mode_toggled)
	box.add_child(mode_button)

	code_edit = CodeEdit.new()
	code_edit.text = ServoArmPreset.ANSWER_CODE
	code_edit.gutters_draw_line_numbers = true
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(code_edit)

	run_button = Button.new()
	run_button.text = "Run code"
	run_button.pressed.connect(_on_run_pressed)
	box.add_child(run_button)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)


## A one-line control reminder pinned to the top of the assembly view.
func _build_help_hud() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 204
	panel.offset_right = -384
	panel.offset_bottom = -12
	_ui_root.add_child(panel)

	var label := Label.new()
	label.text = "Right-drag: look around  ·  hold right + WASD: fly (Space/Shift up/down, Ctrl fast)  ·  wheel: zoom\nLeft-drag a part to move it (Shift: height)  ·  click to select, then arrows move / rings rotate  ·  Delete removes  ·  Answer buttons load a finished robot"
	label.label_settings = SsokTheme.dim_settings()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)


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
		button.pressed.connect(_on_palette_pressed.bind(definition))
		parts_box.add_child(button)

	box.add_child(HSeparator.new())
	var delete_button := Button.new()
	delete_button.text = "Delete selected"
	delete_button.pressed.connect(_on_delete_pressed)
	box.add_child(delete_button)

	answer_button = Button.new()
	answer_button.text = "Answer: servo arm"
	answer_button.pressed.connect(_on_answer_pressed)
	box.add_child(answer_button)

	biped_button = Button.new()
	biped_button.text = "Answer: biped"
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
	_set_status("added %s - drag it onto a matching port" % definition.display_name)


func _on_delete_pressed() -> void:
	_ensure_assembly_mode()
	if assembly.remove_selected():
		_set_status("part removed")
	else:
		_set_status("click a part first, then delete it")


func _on_answer_pressed() -> void:
	_load_preset(ServoArmPreset.build(), ServoArmPreset.ANSWER_CODE, "answer loaded - the finished servo arm")


func _on_biped_pressed() -> void:
	_load_preset(BipedPreset.build(), BipedPreset.ANSWER_CODE, "answer loaded - the biped; run the code to make it step")


func _load_preset(graph: ConnectionGraph, code: String, message: String) -> void:
	_ensure_assembly_mode()
	assembly.load_graph(graph)
	_colorize(assembly)
	_mark_ports(assembly)
	code_edit.text = code
	_set_status(message)


func _ensure_assembly_mode() -> void:
	if mode_button.button_pressed:
		mode_button.button_pressed = false


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_DELETE:
		_on_delete_pressed()


func _on_mode_toggled(run: bool) -> void:
	if run:
		run_mode.build(assembly.graph)
		_colorize(run_mode)
		assembly.visible = false
		assembly.process_mode = Node.PROCESS_MODE_DISABLED
		_set_status("run mode - %d bodies, %d servo(s)" % [run_mode.bodies.size(), run_mode.servos.size()])
	else:
		run_mode.teardown()
		assembly.visible = true
		assembly.process_mode = Node.PROCESS_MODE_INHERIT
		_set_status("assembly mode")


func _on_run_pressed() -> void:
	if runtime.is_running():
		return
	if not mode_button.button_pressed:
		mode_button.button_pressed = true
	runtime.run(code_edit.text)


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
