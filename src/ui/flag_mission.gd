class_name FlagMission
extends PanelContainer

signal starter_requested
signal run_requested
signal stop_requested
signal practice_requested
signal connect_arm_requested
signal wiring_requested
signal retry_requested

class ReadyAction extends ActionLeaf:
	func tick(actor: Node, _blackboard: Blackboard) -> int:
		var mission: FlagMission = actor as FlagMission
		return SUCCESS if mission._can_observe_run() else FAILURE


class RaisedAction extends ActionLeaf:
	func tick(actor: Node, _blackboard: Blackboard) -> int:
		var mission: FlagMission = actor as FlagMission
		return SUCCESS if mission._observed_flag_raised() else RUNNING


const FLAG_COLOR: Color = Color(0.98, 0.41, 0.19)
const SOUND_SNAP: AudioStream = preload("res://assets/kenney/interface-sounds/drop_001.ogg")
const SOUND_SELECT: AudioStream = preload("res://assets/kenney/interface-sounds/select_001.ogg")
const SOUND_SUCCESS: AudioStream = preload("res://assets/kenney/interface-sounds/confirmation_001.ogg")

var _assembly: AssemblyMode
var _run_mode: RunMode
var _chart: StateChart
var _tree: BeehaveTree
var _phase: StringName = &"Intro"
var _arm_index: int = -1
var _servo_index: int = -1
var _wired: bool = false
var _wire_pin: int = -1
var goal_rule: Dictionary = StageDefinition.rule("height", "arm_link", 0.155, 100.0, 0.2)
## Stage sessions show the flag only in the flag stage; other robots with an arm link stay plain.
var show_visual: bool = true
var _practice: Button
var _maximum_tip_height: float = 0.0
var _previous_height: float = NAN
var _height_change: float = NAN
var _initial_tip_height: float = 0.0
var _lowest_tip_height: float = 0.0
var _steady_seconds: float = 0.0
var _running_seconds: float = 0.0
var _flag: MeshInstance3D
var _title: Label
var _message: Label
var _action: Button
var _preferences: InterfacePreferences
var _sound: AudioStreamPlayer


func configure(assembly: AssemblyMode, run_mode: RunMode, visual_parent: Node3D) -> void:
	_assembly = assembly
	_run_mode = run_mode
	_flag = MeshInstance3D.new()
	_flag.name = "FlagMissionVisual"
	_flag.mesh = _flag_mesh()
	_flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flag.visible = false
	visual_parent.add_child(_flag)
	_assembly.link_added.connect(func(_link: Dictionary) -> void: _play(SOUND_SNAP))
	_assembly.graph_changed.connect(observe_graph)
	observe_graph()


func _ready() -> void:
	name = "FlagMission"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	add_child(layout)
	_title = Label.new()
	_title.text = "Raise the flag"
	_title.add_theme_font_size_override("font_size", SsokTheme.font_size(20))
	_title.add_theme_color_override("font_color", SsokTheme.ACCENT)
	layout.add_child(_title)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.y = 42
	layout.add_child(_message)
	_action = SsokTheme.button("Try the flag mission", "play")
	_action.pressed.connect(_on_action_pressed)
	layout.add_child(_action)
	_practice = SsokTheme.button("Build this arm yourself", "code-xml")
	_practice.pressed.connect(func() -> void: practice_requested.emit())
	layout.add_child(_practice)
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -13.0
	add_child(_sound)
	_preferences = get_node("/root/Preferences") as InterfacePreferences
	_preferences.changed.connect(_apply_sound_preferences)
	_apply_sound_preferences()
	_build_chart()
	_build_tree()
	_refresh_text()


func _build_chart() -> void:
	_chart = StateChart.new()
	_chart.name = "MissionChart"
	_chart.warn_on_sending_unknown_events = false
	var flow := CompoundState.new()
	flow.name = "MissionFlow"
	flow.initial_state = NodePath("Intro")
	for state_name: StringName in [&"Intro", &"Assembly", &"Wire", &"Ready", &"Running", &"Success"]:
		var state := AtomicState.new()
		state.name = state_name
		state.state_entered.connect(_on_state_entered.bind(state_name))
		flow.add_child(state)
	_add_transition(flow, &"Intro", &"begin", &"Assembly")
	_add_transition(flow, &"Assembly", &"arm_connected", &"Wire")
	_add_transition(flow, &"Wire", &"wired", &"Ready")
	_add_transition(flow, &"Ready", &"run", &"Running")
	_add_transition(flow, &"Running", &"goal_observed", &"Success")
	_add_transition(flow, &"Running", &"stopped", &"Ready")
	_add_transition(flow, &"Success", &"retry", &"Ready")
	for state_name: StringName in [&"Wire", &"Ready", &"Running", &"Success"]:
		_add_transition(flow, state_name, &"arm_removed", &"Assembly")
	for state_name: StringName in [&"Ready", &"Running", &"Success"]:
		_add_transition(flow, state_name, &"wire_removed", &"Wire")
	_chart.add_child(flow)
	add_child(_chart)


func _add_transition(flow: CompoundState, from_state: StringName, event: StringName, to_state: StringName) -> void:
	var transition := Transition.new()
	transition.name = event
	transition.event = event
	transition.to = NodePath("../../" + String(to_state))
	flow.get_node(NodePath(from_state)).add_child(transition)


func _build_tree() -> void:
	_tree = BeehaveTree.new()
	_tree.name = "ObservedTask"
	_tree.actor = self
	_tree.process_thread = BeehaveTree.ProcessThread.MANUAL
	var sequence := SequenceComposite.new()
	sequence.add_child(ReadyAction.new())
	sequence.add_child(RaisedAction.new())
	_tree.add_child(sequence)
	add_child(_tree)


func _on_state_entered(state_name: StringName) -> void:
	_phase = state_name
	if state_name == &"Success":
		_height_change = _maximum_tip_height - _previous_height if is_finite(_previous_height) else NAN
		_previous_height = _maximum_tip_height
		_play(SOUND_SUCCESS)
	_refresh_text()
	if state_name == &"Assembly" or state_name == &"Wire":
		observe_graph()


func observe_graph() -> void:
	if _assembly == null:
		return
	_arm_index = -1
	_servo_index = -1
	_wired = false
	_wire_pin = -1
	var graph: ConnectionGraph = _assembly.graph
	for link: Dictionary in graph.links:
		var a_index: int = link.a_part
		var b_index: int = link.b_part
		var a_id: StringName = graph.parts[a_index].part_def.id
		var b_id: StringName = graph.parts[b_index].part_def.id
		if a_id == &"servo" and b_id == &"arm_link" and link.a_port == &"output_shaft" and link.b_port == &"mount_base":
			_servo_index = a_index
			_arm_index = b_index
			break
		if b_id == &"servo" and a_id == &"arm_link" and link.b_port == &"output_shaft" and link.a_port == &"mount_base":
			_servo_index = b_index
			_arm_index = a_index
			break
	if _servo_index >= 0:
		var mapping: Dictionary = Wiring.pin_map(graph)
		for pin: int in mapping:
			var channel: Dictionary = mapping[pin]
			if channel.part == _servo_index:
				_wired = true
				_wire_pin = pin
				break
	if _chart != null and _chart.is_inside_tree():
		if _phase == &"Intro" and _arm_index >= 0:
			_chart.send_event(&"begin")
		elif _arm_index < 0 and _phase in [&"Wire", &"Ready", &"Running", &"Success"]:
			_tree.interrupt()
			_chart.send_event(&"arm_removed")
		elif not _wired and _phase in [&"Ready", &"Running", &"Success"]:
			_tree.interrupt()
			_chart.send_event(&"wire_removed")
		elif _arm_index >= 0 and _phase == &"Assembly":
			_chart.send_event(&"arm_connected")
		elif _wired and _phase == &"Wire":
			_chart.send_event(&"wired")
	_update_visual()
	_refresh_text()


func on_run_mode_changed(running: bool) -> void:
	if not running:
		_tree.interrupt()
		if _phase == &"Running":
			_chart.send_event(&"stopped")
		return
	if _phase == &"Ready" and _can_observe_run():
		var point: Vector3 = _tip_position()
		_initial_tip_height = point.y
		_maximum_tip_height = point.y
		_lowest_tip_height = point.y
		_steady_seconds = 0.0
		_running_seconds = 0.0
		_chart.send_event(&"run")


func on_stop_pressed() -> void:
	if _phase == &"Running":
		_tree.interrupt()
		_chart.send_event(&"stopped")


func _physics_process(_delta: float) -> void:
	_update_visual()
	if _phase != &"Running":
		return
	_running_seconds += get_physics_process_delta_time()
	match _tree.tick():
		BeehaveNode.SUCCESS:
			_chart.send_event(&"goal_observed")
		BeehaveNode.FAILURE:
			_tree.interrupt()
			_chart.send_event(&"stopped")
	if _running_seconds > 10.0 and _phase == &"Running":
		SsokLocale.bind(_message, "The flag has not reached its mark. Change an angle and try again.")


func _can_observe_run() -> bool:
	if _assembly == null or _run_mode == null or not _run_mode.is_built() or _arm_index < 0 or not _wired:
		return false
	var drive: ServoDrive = _run_mode.servos.get(_servo_index)
	return drive != null


func _observed_flag_raised() -> bool:
	var drive: ServoDrive = _run_mode.servos.get(_servo_index)
	if drive == null or not drive.powered:
		return false
	var height: float = _tip_position().y
	_lowest_tip_height = minf(_lowest_tip_height, height)
	_maximum_tip_height = maxf(_maximum_tip_height, height)
	if height >= goal_rule.min and height <= goal_rule.max:
		_steady_seconds += get_physics_process_delta_time()
	else:
		_steady_seconds = 0.0
	return _steady_seconds >= goal_rule.hold_seconds


func _tip_position() -> Vector3:
	var definition: PartDef = _assembly.graph.parts[_arm_index].part_def
	var local_tip: Vector3 = Vector3(0, definition.mesh.get_aabb().end.y, 0)
	var part_transform: Transform3D = _run_mode.part_global_transform(_arm_index) if _run_mode.is_built() else _assembly.graph.parts[_arm_index].transform
	return part_transform * local_tip


func _update_visual() -> void:
	if _flag == null:
		return
	_flag.visible = show_visual and _arm_index >= 0
	if _flag.visible:
		_flag.global_position = _tip_position()


func _on_action_pressed() -> void:
	_play(SOUND_SELECT)
	match _phase:
		&"Intro":
			_chart.send_event(&"begin")
			if _assembly.graph.parts.is_empty():
				starter_requested.emit()
		&"Assembly":
			connect_arm_requested.emit()
		&"Wire":
			wiring_requested.emit()
		&"Ready":
			run_requested.emit()
		&"Running":
			stop_requested.emit()
		&"Success":
			_chart.send_event(&"retry")
			retry_requested.emit()


func _refresh_text() -> void:
	if _message == null or _action == null:
		return
	var description: String
	var button: String
	match _phase:
		&"Assembly":
			description = "Connect the arm to the servo. You can start with the finished example."
			button = "Connect the arm"
		&"Wire":
			description = "Connect the servo to a board pin. The program uses your actual wiring."
			button = "Open wiring"
		&"Ready":
			description = "Run the code. Watch the flag move down and return to its mark."
			button = "Run code"
		&"Running":
			description = "The flag is moving. The real arm position decides success."
			button = "Stop"
		&"Success":
			description = "The flag reached its mark and stayed there. Change one angle and try again."
			button = "Try again"
		_:
			description = "Build a small robot, wire its motor, and raise the flag."
			button = "Try the flag mission"
	SsokLocale.bind(_message, description)
	if _phase == &"Ready" and _wire_pin >= 0:
		SsokLocale.bind(_message, "Your servo uses pin %d. Use the same pin in your code, then run.", [_wire_pin])
	elif _phase == &"Success" and is_finite(_height_change):
		SsokLocale.bind(_message, "Flag height: %.1f cm · change from last run: %+.1f cm. Try a different angle.", [_maximum_tip_height * 100.0, _height_change * 100.0])
	_action.text = button


func _play(stream: AudioStream) -> void:
	if DisplayServer.get_name() == "headless" or _sound == null or stream == null or _preferences.effects_gain() <= 0.0:
		return
	_sound.stop()
	_sound.stream = stream
	_sound.play()


func _apply_sound_preferences() -> void:
	if _sound == null:
		return
	var gain: float = _preferences.effects_gain()
	_sound.volume_db = -13.0 + linear_to_db(maxf(0.0001, gain))
	if gain <= 0.0:
		_sound.stop()


func _exit_tree() -> void:
	if _sound != null:
		_sound.stop()
		_sound.stream = null


func _flag_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.albedo_color = FLAG_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	for point: Vector3 in [Vector3(0, 0, 0), Vector3(0, 0.025, 0), Vector3(0.025, 0.019, 0)]:
		surface.add_vertex(point)
	return surface.commit()
