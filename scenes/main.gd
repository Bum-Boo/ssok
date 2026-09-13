extends Node3D

## Slice-1 prototype shell: assembly view on the left, learner code on the right,
## one toggle between kinematic assembly and physics run mode (ADR 0003).

const PART_COLORS := {
	&"base": Color(0.35, 0.35, 0.4),
	&"servo": Color(0.15, 0.35, 0.85),
	&"arm_link": Color(0.95, 0.55, 0.15),
	&"board": Color(0.1, 0.55, 0.3),
}

var assembly: AssemblyMode
var run_mode: RunMode
var runtime: MiniRuntime
var code_edit: CodeEdit
var status: Label
var mode_button: CheckButton
var run_button: Button


func _ready() -> void:
	var camera := $Camera3D as Camera3D
	camera.look_at_from_position(Vector3(0.2, 0.18, 0.26), Vector3(0.05, 0.09, 0))
	camera.fov = 45.0

	assembly = AssemblyMode.new()
	add_child(assembly)
	assembly.load_graph(ServoArmPreset.build())
	_colorize(assembly)

	run_mode = RunMode.new()
	add_child(run_mode)

	runtime = MiniRuntime.new()
	runtime.hardware = run_mode
	runtime.line_started.connect(func(n: int) -> void: _set_status("running line %d" % n))
	runtime.finished.connect(func() -> void: _set_status("finished"))
	runtime.failed.connect(func(n: int, msg: String) -> void: _set_status("line %d: %s" % [n, msg], true))
	add_child(runtime)

	_build_ui()
	_set_status("assembly mode - drag parts; they snap at ports")


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -360
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var title := Label.new()
	title.text = "ssok - servo arm (slice 1)"
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


static func _colorize(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var owner_name := String(mesh.get_parent().name)
		for part_id: StringName in PART_COLORS:
			if owner_name.begins_with(String(part_id)):
				var material := StandardMaterial3D.new()
				material.albedo_color = PART_COLORS[part_id]
				mesh.material_override = material
				break
