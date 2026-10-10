class_name AgentTracePanel
extends VBoxContainer

## Robot camera preview and concise agent trace for the AI tab.
## Shows reported summaries, tool calls and results only; never model reasoning.

signal enable_requested
signal observe_requested
signal step_requested(ticks: int)
signal stop_requested
signal goal_requested(goal: String)

const FORWARD_TICKS: int = 20
const MAX_EVENTS: int = 40
const SUMMARY_LIMIT: int = 280
const LINE_LIMIT: int = 240
const HASH_PREVIEW: int = 12
const EVENT_KEYS: Array[String] = ["seq", "kind", "tool", "args", "result", "error", "summary", "provider", "image_sha256", "hash", "frame_id", "tick", "state"]
const STATE_NAMES: Dictionary = {"disabled": "Off", "settling": "Settling", "ready": "Ready", "driving": "Driving", "capturing": "Capturing", "stopped": "Stopped", "fault": "Fault"}
const GOAL_MAX_CHARS: int = 1000
const GOAL_MODEL: String = "gpt-6-astra"
const GOAL_MAX_ACTIONS: int = 8
const GOAL_MAX_FRAMES: int = 9
const GOAL_TIME_LIMIT: int = 300
# Goal statuses are localization keys; anything else is dropped so provider text never reaches the panel.
const GOAL_STATUSES: Array[String] = ["AI operator: connected.", "AI operator: not connected.", "Goal sent. Waiting for the operator.", "Running the goal. Stop is always available.", "Goal run ended. Check the camera frame for the result.", "Goal run stopped.", "Goal run reached its limit and stopped.", "Goal run failed. Check the recent events.", "Operator disconnected during the run."]

var _snapshot: Dictionary = {}
var _history: Array[Dictionary] = []
var _dispatch: Dictionary = {}
var _texture: ImageTexture
var _frame_sha: String = ""
var _goal_connected: bool = false
var _goal_busy: bool = false
var _goal_pending: bool = false
var _goal_status: String = ""

var _scroll: ScrollContainer
var _stop_button: Button
var _enable_button: Button
var _capture_button: Button
var _forward_button: Button
var _goal_field: LineEdit
var _run_button: Button
var _goal_status_label: Label
var _status_label: Label
var _readiness_label: Label
var _bridge_label: Label
var _preview: Panel
var _image: TextureRect
var _placeholder: Label
var _frame_label: Label
var _hash_warning: Label
var _hash_box: VBoxContainer
var _hash_field: LineEdit
var _summary_label: Label
var _dispatch_label: Label
var _tool_label: Label
var _history_label: Label


func _init() -> void:
	name = "AI"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Stop and status stay pinned above the scrolling area.
	var top_row: HBoxContainer = HBoxContainer.new()
	_stop_button = SsokTheme.button("Stop")
	_stop_button.tooltip_text = "Stop the robot now."
	_stop_button.pressed.connect(stop_requested.emit)
	top_row.add_child(_stop_button)
	var status_title: Label = _section("Status")
	status_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(status_title)
	_status_label = _dynamic_label()
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_status_label)
	add_child(top_row)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# A permanent bar keeps the width, and so the 4:3 preview height, independent of content height.
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)

	# Manual actions wrap onto more rows instead of clipping at large text sizes.
	var actions: HFlowContainer = HFlowContainer.new()
	_enable_button = _action_button("Enable", "Mount the virtual camera on the current robot.", actions)
	_enable_button.pressed.connect(enable_requested.emit)
	_capture_button = _action_button("Capture", "Capture one camera frame.", actions)
	_capture_button.pressed.connect(observe_requested.emit)
	_forward_button = _action_button("Forward", "Drive forward 20 ticks, then stop.", actions)
	_forward_button.pressed.connect(_on_forward_pressed)
	content.add_child(actions)

	content.add_child(_section("Goal"))
	# Field, disclosure and Run stack at full width; provider, data and limits precede Run in scroll order.
	_goal_field = LineEdit.new()
	# Learner text stays raw; text_submitted is left unconnected so Enter never sends it.
	_goal_field.max_length = GOAL_MAX_CHARS
	_goal_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_goal_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_field.text_changed.connect(_on_goal_text_changed)
	content.add_child(_goal_field)
	var disclosure: Label = _dynamic_label(&"SectionLabel")
	SsokLocale.bind(disclosure, "Run with AI asks the connected operator to request %s from OpenAI with its existing Codex ChatGPT login. Sent: the goal, camera PNGs, public frame context, short summaries and tool results.", [GOAL_MODEL])
	content.add_child(disclosure)
	var limits: Label = _dynamic_label(&"SectionLabel")
	SsokLocale.bind(limits, "Per run: up to %d actions, %d images and %d seconds. Usage counts toward that ChatGPT account, with no fixed cost or model-request cap.", [GOAL_MAX_ACTIONS, GOAL_MAX_FRAMES, GOAL_TIME_LIMIT])
	content.add_child(limits)
	_run_button = SsokTheme.button("Run with AI")
	_run_button.clip_text = false
	_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_button.tooltip_text = "Send this goal to the connected AI operator."
	_run_button.pressed.connect(_on_run_pressed)
	content.add_child(_run_button)
	_goal_status_label = _dynamic_label()
	content.add_child(_goal_status_label)

	content.add_child(_section("Camera"))
	_preview = Panel.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.resized.connect(_fit_preview)
	_image = TextureRect.new()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
	_preview.add_child(_image)
	_placeholder = _dynamic_label(&"SectionLabel")
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	SsokLocale.bind(_placeholder, "No frame yet. Capture to see the robot camera.")
	_preview.add_child(_placeholder)
	content.add_child(_preview)
	_frame_label = _dynamic_label()
	_frame_label.visible = false
	content.add_child(_frame_label)
	_hash_warning = _dynamic_label()
	_hash_warning.visible = false
	SsokLocale.bind(_hash_warning, "Frame bytes do not match the reported hash.")
	content.add_child(_hash_warning)
	_hash_box = VBoxContainer.new()
	_hash_box.visible = false
	_hash_box.add_child(_section("Image SHA-256"))
	_hash_field = LineEdit.new()
	_hash_field.editable = false
	_hash_field.select_all_on_focus = true
	_hash_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hash_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hash_box.add_child(_hash_field)
	content.add_child(_hash_box)

	content.add_child(_section("Agent summary"))
	content.add_child(_note("Written by the agent, not an observed result."))
	_summary_label = _dynamic_label()
	SsokLocale.bind(_summary_label, "No agent decision yet.")
	content.add_child(_summary_label)
	_dispatch_label = _dynamic_label(&"SectionLabel")
	_dispatch_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_dispatch_label.visible = false
	content.add_child(_dispatch_label)

	content.add_child(_section("Last tool call"))
	_tool_label = _dynamic_label()
	_tool_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	SsokLocale.bind(_tool_label, "No tool call yet.")
	content.add_child(_tool_label)

	content.add_child(_section("Recent events, newest first"))
	_history_label = _dynamic_label()
	_history_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	SsokLocale.bind(_history_label, "No events yet.")
	content.add_child(_history_label)

	# Guidance prose follows the data; button tooltips repeat the essentials.
	_readiness_label = _dynamic_label()
	content.add_child(_readiness_label)
	_bridge_label = _dynamic_label(&"SectionLabel")
	content.add_child(_bridge_label)
	content.add_child(_note("Virtual sensor fixture on the robot, not a catalog part."))
	_refresh_state()


func _notification(what: int) -> void:
	# The shared theme has no read-only LineEdit look; reuse its normal field style.
	if what == NOTIFICATION_THEME_CHANGED and _hash_field != null:
		_hash_field.add_theme_stylebox_override(&"read_only", get_theme_stylebox(&"normal", &"LineEdit"))
		_hash_field.add_theme_color_override(&"font_uneditable_color", get_theme_color(&"font_color", &"LineEdit"))


func set_state(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_refresh_state()


func set_goal_status(connected: bool, busy: bool, status: String = "") -> void:
	_goal_connected = connected
	_goal_busy = busy
	_goal_pending = false
	_goal_status = status if status in GOAL_STATUSES else ""
	if _goal_status != status:
		push_warning("AgentTracePanel ignored an unknown goal status key.")
	_refresh_state()


func set_frame(png: PackedByteArray, metadata: Dictionary) -> void:
	var frame_id: String = str(metadata.get("frame_id", "?"))
	var image: Image = Image.new()
	if png.is_empty() or image.load_png_from_buffer(png) != OK:
		_image.texture = null
		_frame_sha = ""
		_hash_field.text = ""
		_placeholder.visible = true
		SsokLocale.bind(_placeholder, "Frame %s could not be decoded.", [frame_id])
		_frame_label.visible = false
		_hash_warning.visible = false
		_hash_box.visible = false
		_refresh_dispatch()
		return
	if _texture != null and Vector2i(_texture.get_size()) == image.get_size() and _texture.get_format() == image.get_format():
		_texture.update(image)
	else:
		_texture = ImageTexture.create_from_image(image)
	_image.texture = _texture
	_placeholder.visible = false
	# The shown hash is computed from the received bytes, not trusted from metadata.
	_frame_sha = _sha256(png)
	SsokLocale.bind(_frame_label, "Captured frame %s at tick %s", [frame_id, str(metadata.get("tick", "?"))])
	_frame_label.visible = true
	_hash_field.text = _frame_sha
	_hash_box.visible = true
	var reported: String = str(metadata.get("sha256", "")).strip_edges().to_lower()
	_hash_warning.visible = not reported.is_empty() and reported != _frame_sha
	_refresh_dispatch()


func append_event(event: Dictionary) -> void:
	# Only reviewed keys are kept so hidden reasoning fields never reach the panel.
	var entry: Dictionary = {}
	for key: String in EVENT_KEYS:
		if event.has(key):
			entry[key] = event[key]
	_history.push_front(entry)
	if _history.size() > MAX_EVENTS:
		_history.resize(MAX_EVENTS)
	var kind: String = str(entry.get("kind", ""))
	if kind == "dispatch" or kind == "trace_dispatch":
		_dispatch = entry
		_refresh_dispatch()
	elif kind == "tool" or entry.has("tool"):
		_show_tool(entry)
	_render_history()


func _refresh_state() -> void:
	var web: bool = OS.has_feature("web")
	var enabled: bool = _snapshot.get("enabled", false) == true
	var state: String = str(_snapshot.get("state", "disabled"))
	var supported: bool = _snapshot.get("robot_supported", false) == true
	var can_step: bool = _snapshot.get("can_step", false) == true
	var has_frame: bool = _has_id(_snapshot.get("frame_id"))
	var fault: String = str(_snapshot.get("fault", "")).strip_edges()
	var goal_active: bool = _goal_busy or _goal_pending
	_enable_button.disabled = web or goal_active or not supported or (enabled and state not in ["stopped", "fault"])
	_capture_button.disabled = web or goal_active or not enabled or state not in ["ready", "stopped"]
	_forward_button.disabled = web or goal_active or not enabled or state != "ready" or not can_step
	if STATE_NAMES.has(state):
		SsokLocale.bind(_status_label, str(STATE_NAMES[state]))
	else:
		SsokLocale.bind(_status_label, "Unknown state: %s", [state])
	_readiness_label.visible = true
	if web:
		SsokLocale.bind(_readiness_label, "Desktop only. The AI camera is not available on Web.")
	elif state == "fault":
		if fault.is_empty():
			SsokLocale.bind(_readiness_label, "Fault. Enable again to retry.")
		else:
			SsokLocale.bind(_readiness_label, "Fault: %s. Enable again to retry.", [fault])
	elif not supported:
		SsokLocale.bind(_readiness_label, "Needs a robot with two wired DC wheels.")
	elif not enabled:
		SsokLocale.bind(_readiness_label, "Enable to mount the virtual camera on the current robot.")
	elif state == "settling":
		SsokLocale.bind(_readiness_label, "Settling. Wait for the robot to rest.")
	elif state == "capturing":
		SsokLocale.bind(_readiness_label, "Capturing a frame.")
	elif state == "driving":
		SsokLocale.bind(_readiness_label, "Driving forward. Stop is always available.")
	elif state == "ready":
		if has_frame:
			SsokLocale.bind(_readiness_label, "Ready. Forward drives %d ticks, then stops.", [FORWARD_TICKS])
		else:
			SsokLocale.bind(_readiness_label, "Capture a frame before moving.")
	elif state == "stopped":
		SsokLocale.bind(_readiness_label, "Stopped. Capture a frame or Enable again.")
	else:
		_readiness_label.visible = false
	_bridge_label.visible = not web
	if _snapshot.get("bridge_listening", false) == true:
		SsokLocale.bind(_bridge_label, "External agent bridge: listening on this computer.")
	else:
		SsokLocale.bind(_bridge_label, "External agent bridge: off. The camera works without it.")
	_refresh_goal()


func _refresh_goal() -> void:
	var web: bool = OS.has_feature("web")
	var supported: bool = _snapshot.get("robot_supported", false) == true
	var blank: bool = _goal_field.text.strip_edges().is_empty()
	_run_button.disabled = web or not supported or not _goal_connected or _goal_busy or _goal_pending or blank
	_goal_status_label.visible = not web
	if _goal_pending:
		SsokLocale.bind(_goal_status_label, "Goal sent. Waiting for the operator.")
	elif not _goal_status.is_empty():
		SsokLocale.bind(_goal_status_label, _goal_status)
	elif _goal_busy:
		SsokLocale.bind(_goal_status_label, "Running the goal. Stop is always available.")
	elif _goal_connected:
		SsokLocale.bind(_goal_status_label, "AI operator: connected.")
	else:
		SsokLocale.bind(_goal_status_label, "AI operator: not connected.")


func _refresh_dispatch() -> void:
	if _dispatch.is_empty():
		return
	var summary: String = str(_dispatch.get("summary", "")).strip_edges()
	if summary.is_empty():
		SsokLocale.bind(_summary_label, "No summary was reported.")
	else:
		_set_raw(_summary_label, _clip(summary, SUMMARY_LIMIT))
	var provider: String = str(_dispatch.get("provider", "")).strip_edges()
	if provider.is_empty():
		provider = "-"
	# A matching hash only ties the receipt to this PNG; it does not prove delivery or model use.
	var reported: String = str(_dispatch.get("image_sha256", _dispatch.get("hash", ""))).strip_edges().to_lower()
	_dispatch_label.visible = true
	if reported.is_empty():
		SsokLocale.bind(_dispatch_label, "Reported receipt from %s: no image", [provider])
	elif reported == _frame_sha:
		SsokLocale.bind(_dispatch_label, "Reported receipt from %s: image %s matches the frame shown. This does not prove it was sent or read.", [provider, reported.left(HASH_PREVIEW)])
	else:
		SsokLocale.bind(_dispatch_label, "Reported receipt from %s: image %s does not match the frame shown", [provider, reported.left(HASH_PREVIEW)])


func _show_tool(entry: Dictionary) -> void:
	var lines: PackedStringArray = [str(entry.get("tool", "?"))]
	for key: String in ["args", "result", "error"]:
		if entry.has(key):
			lines.append(_clip(key + " " + JSON.stringify(entry[key], "", true), LINE_LIMIT))
	_set_raw(_tool_label, "\n".join(lines))


func _render_history() -> void:
	var lines: PackedStringArray = []
	for entry: Dictionary in _history:
		var rest: Dictionary = entry.duplicate()
		var kind: String = str(rest.get("kind", "event"))
		rest.erase("kind")
		lines.append(_clip(kind + " " + JSON.stringify(rest, "", true), LINE_LIMIT))
	_set_raw(_history_label, "\n".join(lines))


func _fit_preview() -> void:
	# Keep the camera area 4:3 at whatever width the tab provides.
	var height: float = floorf(_preview.size.x * 0.75)
	if not is_equal_approx(_preview.custom_minimum_size.y, height):
		_preview.custom_minimum_size.y = height


func _on_forward_pressed() -> void:
	step_requested.emit(FORWARD_TICKS)


func _on_goal_text_changed(_text: String) -> void:
	_refresh_goal()


func _on_run_pressed() -> void:
	# One click sends one goal; Run stays disabled until set_goal_status answers.
	if _run_button.disabled:
		return
	_goal_pending = true
	_goal_status = ""
	_refresh_state()
	goal_requested.emit(_goal_field.text)


func _section(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"SectionLabel"
	return label


func _note(text: String) -> Label:
	var label: Label = _section(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _dynamic_label(variation: StringName = &"") -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _action_button(text: String, tip: String, row: Container) -> Button:
	var control: Button = SsokTheme.button(text)
	control.tooltip_text = tip
	# Full labels set the minimum width only with clipping and trimming both off, so the flow row wraps rather than truncating.
	control.clip_text = false
	control.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return control


func _set_raw(label: Label, text: String) -> void:
	# Raw text must drop any binding, or a language switch would restore the old message.
	if label.has_meta("localized_source"):
		label.remove_meta("localized_source")
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text


func _has_id(value: Variant) -> bool:
	if value == null:
		return false
	if value is int or value is float:
		return value >= 0
	return not str(value).is_empty()


func _sha256(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _clip(text: String, limit: int) -> String:
	return text if text.length() <= limit else text.left(limit - 1) + "…"
