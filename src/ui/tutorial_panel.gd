class_name TutorialPanel
extends Window

signal panel_closed

const STEPS: Array[Dictionary] = [
	{
		"title": "Build with interchangeable parts",
		"icon": "box",
		"body": "Choose Answer: construction-kit humanoid or Answer: kit bridge. Both use the same 20 mm-pitch beams, plates, brackets and connectors. Select one part, move it with G and snap a matching hole to another part. The Blender file includes a parts tray, assembled examples and an exploded view; no torso or limb is one joined frame.",
		"hint": "The kit uses ssok's own virtual dimensions, not a certified commercial standard. Motors are complete units; structural beams, plates and covers remain separate.",
	},
	{
		"title": "Start with a robot",
		"icon": "box",
		"body": "Close this guide to try each step, then reopen the book icon to continue. Your place is kept until the app closes.\n\nIn the left library, choose Answer: biped for movement, or Answer: servo arm for a simple coding example. Loading a starter replaces the current assembly and code.",
		"hint": "Look around: middle mouse to orbit, Shift + middle mouse to pan, wheel to zoom.",
	},
	{
		"title": "Add and connect parts",
		"icon": "cpu",
		"body": "In edit mode, search the Parts library or use its category filter, then click a part to add it. Select it in the 3D view and press G to move it near a compatible yellow port. Confirm to snap.\n\nMechanical connections hold parts together. Electrical connections map servos to board pins; code must use the pins actually wired in your robot.",
		"hint": "Ctrl + Z undoes an addition, deletion or transform. Selection alone does not disconnect parts.",
	},
	{
		"title": "Edit with familiar shortcuts",
		"icon": "move",
		"body": "Select a part, then press G to move or R to rotate. Press X, Y or Z to constrain the world axis. Type a distance in millimetres or an angle in degrees.\n\nTry G, X, 10, Enter to move 10 mm. Enter confirms; Esc cancels and restores connections. This is object editing, not Blender mesh or vertex editing.",
		"hint": "Use Frame robot to fit the view. Part scaling is not supported; the vertical axis is Y.",
	},
	{
		"title": "Drive with WASD",
		"icon": "gamepad-2",
		"body": "Load the biped example, choose Control: WASD / gamepad movement on the right, then enable Run mode at the top. Click the 3D view before driving.\n\nW / S moves forward / backward; A / D turns. A gamepad's left stick sends the same commands. Space brakes; Esc or Stop disables input. The experimental biped gait can be slow or drift; other robots need their own joint program.",
		"hint": "Opening this guide stops code and movement input, not physics. After closing, select WASD control again or toggle Run mode to resume.",
	},
	{
		"title": "Run your own servo code",
		"icon": "code-xml",
		"body": "For a first code exercise, load the servo arm example and inspect its program in the Code tab. Run code enables physics and gives your program control of the wired servos.\n\nCode and WASD never drive the robot at the same time. Typing in an editor does not move the robot. Stop cancels the program; return to edit mode to restore the assembled pose.",
		"hint": "The editor supports a small Python-style servo language, not the full Python runtime. Loading an example replaces your current code.",
	},
	{
		"title": "Explore the AI motion lab",
		"icon": "flask-conical",
		"body": "Open AI motion lab: Connect checks the optional external bridge; Search sets a goal and trial count; Results compares measured trials. Start with the bridge's mock mode without paid model calls.\n\nLive GPT calls require a server-side API key, model access and explicit paid consent. This searches bounded gait parameters, not model training. Apply a valid best result only in edit mode with the same robot assembly.",
		"hint": "This guide never connects to a service, starts a trial or grants paid consent. Close it when you are ready to explore.",
	},
	{
		"title": "Try the physics humanoid",
		"icon": "gamepad-2",
		"body": "Choose Answer: humanoid (experimental), enable Run mode and click the 3D view. W/S walks; hold Shift for a sprint trial. Gamepad B requests sprint and X interacts. A/D turning is not supported yet.\n\nStand close to the box and press E. The robot crouches, reaches with both arms and grips only after both hands contact the box. Press E again to release it under gravity.",
		"hint": "This is a simplified ten-joint physics prototype, not trained human motion. Sprinting is not stable yet and can fall. Stop, code control or opening this guide releases the box. Reset in edit mode after a fall. The pickup lab searches bounded parameters.",
	},
	{
		"title": "Modular humanoid and pickup lab",
		"icon": "flask-conical",
		"body": "Choose Answer: construction-kit humanoid, then open AI motion lab. Start locally or connect Luna, increase parallel trials from 1 to 4, select a measured result and save it. Saved scenarios must be replayed before applying; paid API calls need explicit consent.",
		"hint": "This guide never connects to a service, starts a trial or grants paid consent. Close it when you are ready to explore.",
	},
]

var current_step: int = 0
var heading: Label
var body_label: Label
var hint_label: Label
var step_label: Label
var next_button: Button
var previous_button: Button
var restart_button: Button
var close_button: Button
var _step_icon: TextureRect
var _progress: ProgressBar
var _scroll: ScrollContainer


func _ready() -> void:
	title = "Tutorial"
	size = Vector2i(700, 620)
	min_size = Vector2i(480, 440)
	transient = true
	exclusive = true
	visible = false
	close_requested.connect(close_panel)
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title_label := Label.new()
	title_label.text = "Tutorial"
	title_label.label_settings = SsokTheme.title_settings()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	step_label = Label.new()
	step_label.add_theme_color_override("font_color", SsokTheme.ACCENT)
	header.add_child(step_label)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = STEPS.size()
	_progress.custom_minimum_size.y = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = SsokTheme.ACCENT
	_progress.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = SsokTheme.BORDER
	_progress.add_theme_stylebox_override("background", track)
	layout.add_child(_progress)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	_scroll.add_child(content)
	_step_icon = TextureRect.new()
	_step_icon.custom_minimum_size = Vector2(40, 40)
	_step_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_step_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_step_icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_step_icon.modulate = SsokTheme.ACCENT
	content.add_child(_step_icon)
	heading = _label(content, 25)
	body_label = _label(content, 16)
	var hint_card := PanelContainer.new()
	content.add_child(hint_card)
	hint_label = _label(hint_card, 14)
	hint_label.add_theme_color_override("font_color", SsokTheme.ACCENT)
	layout.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	restart_button = _button(actions, "Restart tutorial", restart)
	restart_button.theme_type_variation = &"QuietButton"
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	previous_button = _button(actions, "Previous", func() -> void: show_step(current_step - 1))
	next_button = _button(actions, "Next", _next)
	next_button.theme_type_variation = &"PrimaryButton"
	next_button.add_theme_color_override("font_focus_color", SsokTheme.BG_SUNKEN)
	close_button = _button(layout, "Close and try it", close_panel)
	close_button.theme_type_variation = &"QuietButton"
	show_step(current_step)


func open_panel() -> void:
	var available: Vector2i = get_tree().root.size - Vector2i(48, 48)
	popup_centered(Vector2i(mini(700, available.x), mini(620, available.y)))
	next_button.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	hide()
	panel_closed.emit()


func show_step(index: int) -> void:
	current_step = clampi(index, 0, STEPS.size() - 1)
	var step: Dictionary = STEPS[current_step]
	SsokLocale.bind(step_label, "Step %d of %d", [current_step + 1, STEPS.size()])
	SsokLocale.bind(heading, step.title)
	SsokLocale.bind(body_label, step.body)
	SsokLocale.bind(hint_label, step.hint)
	_step_icon.texture = SsokTheme.icon(step.icon)
	_progress.value = current_step + 1
	previous_button.disabled = current_step == 0
	restart_button.disabled = current_step == 0
	next_button.text = "Finish tutorial" if current_step == STEPS.size() - 1 else "Next"
	_scroll.scroll_vertical = 0


func restart() -> void:
	show_step(0)
	next_button.grab_focus()


func _next() -> void:
	if current_step == STEPS.size() - 1:
		close_panel()
	else:
		show_step(current_step + 1)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_input_as_handled()
		close_panel()


static func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


static func _button(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = SsokTheme.button(text)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	parent.add_child(button)
	return button
