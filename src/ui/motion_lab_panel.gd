class_name MotionLabPanel
extends Window

signal panel_closed

const SAVE_PATH: String = "user://motion_lab_best.json"
const TERMINAL_STATES: Array[String] = ["completed", "failed", "cancelled"]
const METRIC_KEYS: Array[String] = ["forward_m", "lateral_m", "yaw_rad", "min_upright", "min_height_m", "score"]

var client: MotionLabClient
var endpoint_edit: LineEdit
var token_edit: LineEdit
var goal_edit: TextEdit
var direction: OptionButton
var rounds: SpinBox
var allow_paid: CheckBox
var connect_button: Button
var disconnect_button: Button
var start_button: Button
var cancel_button: Button
var apply_button: Button
var save_button: Button
var load_button: Button
var status_label: Label
var result_label: Label
var history_label: Label
var provider_label: Label
var best: Dictionary = {}
var best_fingerprint: String = ""

var _snapshot_provider: Callable
var _policy_provider: Callable
var _editing_provider: Callable
var _apply_policy: Callable
var _server: Dictionary = {}
var _job: Dictionary = {}
var _search_fingerprint: String = ""
var _poll_timer: Timer
var _cancel_pending: bool = false
var _start_uncertain: bool = false
var _forget_dialog: ConfirmationDialog
var workflow_tabs: TabContainer


func configure(snapshot_provider: Callable, policy_provider: Callable, editing_provider: Callable, apply_policy: Callable) -> void:
	_snapshot_provider = snapshot_provider
	_policy_provider = policy_provider
	_editing_provider = editing_provider
	_apply_policy = apply_policy


func _ready() -> void:
	visible = false
	title = "ssok - AI motion lab"
	size = Vector2i(720, 750)
	min_size = Vector2i(560, 500)
	transient = true
	exclusive = true
	close_requested.connect(_close_panel)
	client = MotionLabClient.new()
	add_child(client)
	client.response_received.connect(_on_response)
	client.request_failed.connect(_on_failure)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.7
	_poll_timer.one_shot = true
	_poll_timer.timeout.connect(_poll)
	add_child(_poll_timer)
	_build_controls()
	get_tree().root.size_changed.connect(_fit_open_panel, CONNECT_DEFERRED)
	refresh_apply_state()


func open_panel() -> void:
	popup_centered(_fitted_size())
	refresh_apply_state()
	if workflow_tabs.current_tab == 1:
		goal_edit.grab_focus()


func _fitted_size() -> Vector2i:
	var available: Vector2i = get_tree().root.size - Vector2i(48, 48)
	return Vector2i(mini(780, available.x), mini(820, available.y))


func _fit_open_panel() -> void:
	if visible:
		size = _fitted_size()
		move_to_center()


func _build_controls() -> void:
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	_label(layout, "Motion search - wired biped", 22)
	_label(layout, "Propose parameters -> simulate -> compare -> explicitly apply. This does not train GPT weights. Other robot programs are not supported yet.")
	workflow_tabs = TabContainer.new()
	workflow_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(workflow_tabs)
	var box: VBoxContainer = _tab_page("1. Connect")
	_label(box, "Bridge origin (loopback HTTP / deployed HTTPS)")
	endpoint_edit = LineEdit.new()
	endpoint_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	endpoint_edit.text = "http://127.0.0.1:8765"
	box.add_child(endpoint_edit)
	_label(box, "Bridge bearer token - RAM only. Never enter an OpenAI API key here.")
	token_edit = LineEdit.new()
	token_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	token_edit.secret = true
	token_edit.placeholder_text = tr("Token from your local bridge terminal")
	token_edit.max_length = 256
	box.add_child(token_edit)
	endpoint_edit.text_changed.connect(func(_value: String) -> void: _invalidate_connection())
	token_edit.text_changed.connect(func(_value: String) -> void: _invalidate_connection())
	var connection_actions: HBoxContainer = HBoxContainer.new()
	box.add_child(connection_actions)
	connect_button = _button(connection_actions, "Check connection", check_connection)
	disconnect_button = _button(connection_actions, "Disconnect / forget", _confirm_forget)
	disconnect_button.tooltip_text = "Recover from an unavailable bridge. Forgetting does not cancel a remote job."
	_forget_dialog = ConfirmationDialog.new()
	_forget_dialog.title = "Forget local search status?"
	_forget_dialog.dialog_text = "This only disconnects the local UI. It does NOT cancel a search on the bridge.\nA submitted job may still run and API charges may continue.\nCheck or stop the bridge before starting another paid search.\nLocal connection status and pending results will be cleared."
	_forget_dialog.confirmed.connect(_forget_confirmed)
	add_child(_forget_dialog)
	provider_label = _label(box, "Not connected. OPENAI_API_KEY is configured only on the bridge.")
	box = _tab_page("2. Search")
	_label(box, "Goal (sent to the bridge/model along with this assembly snapshot)")
	goal_edit = TextEdit.new()
	goal_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	goal_edit.text = tr("Walk forward while staying upright and reducing drift")
	goal_edit.custom_minimum_size.y = 72
	goal_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(goal_edit)
	direction = OptionButton.new()
	for label: String in ["Evaluate: forward (W)", "Evaluate: backward (S)", "Evaluate: turn left (A)", "Evaluate: turn right (D)"]:
		direction.add_item(label)
	box.add_child(direction)
	_label(box, "Direction fixes the measured objective; language does not replace the scoring rule. One direction is evaluated per search.")
	var controls: HBoxContainer = HBoxContainer.new()
	box.add_child(controls)
	_label(controls, "Proposal rounds (1-4)")
	rounds = SpinBox.new()
	rounds.min_value = 1
	rounds.max_value = 4
	rounds.value = 2
	controls.add_child(rounds)
	allow_paid = CheckBox.new()
	allow_paid.text = "Allow paid OpenAI requests for this search"
	box.add_child(allow_paid)
	_label(box, "Mock mode uses deterministic fixtures, not GPT. Live requests may incur costs; cancelling an in-flight API request may still be billed.")
	var actions: HBoxContainer = HBoxContainer.new()
	box.add_child(actions)
	start_button = _button(actions, "Start search", start_search)
	start_button.theme_type_variation = &"PrimaryButton"
	cancel_button = _button(actions, "Cancel search", cancel_search)
	status_label = _label(layout, "Load Answer: biped, configure the bridge, then check the connection.")
	status_label.add_theme_color_override("font_color", SsokTheme.ACCENT)
	box = _tab_page("3. Results")
	history_label = _label(box, "Evaluation history appears here (baseline, then candidates).")
	box.add_child(HSeparator.new())
	result_label = _label(box, "No measured result yet.")
	var result_actions := VBoxContainer.new()
	box.get_parent().get_parent().add_child(result_actions)
	apply_button = _button(result_actions, "Apply best to WASD program (edit mode only)", apply_best)
	apply_button.theme_type_variation = &"PrimaryButton"
	var files: HBoxContainer = HBoxContainer.new()
	result_actions.add_child(files)
	save_button = _button(files, "Save best locally", save_best)
	load_button = _button(files, "Load saved best", load_best)
	_label(box, "Save/load: user://motion_lab_best.json. Stores bounded parameters, numeric metrics and assembly/controller IDs; no token, goal, model text or API key.")
	_button(layout, "Close", _close_panel)


func _tab_page(title_text: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title_text
	workflow_tabs.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	return content


func _label(parent: Node, text: String, font_size: int = 14) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button


func check_connection() -> void:
	if _active() or client.is_busy() or _start_uncertain:
		return
	_server.clear()
	var issue: String = client.configure(endpoint_edit.text, token_edit.text)
	if not issue.is_empty():
		_status(issue)
		return
	_status("Checking bridge...")
	client.check_status()
	refresh_apply_state()


func start_error() -> String:
	if _start_uncertain:
		return "Previous start outcome is unknown. Confirm bridge status, then use Disconnect / forget before reconnecting."
	if client.is_busy() or _active():
		return "A search or connection request is already active"
	if _server.is_empty():
		return "Check the bridge connection first"
	if _server.provider == "openai":
		if not allow_paid.button_pressed:
			return "Paid OpenAI requests require explicit consent for this search"
		if _server.get("key_configured") != true:
			return "Set OPENAI_API_KEY on the bridge, not in Godot"
	if not _snapshot_provider.is_valid() or MotionSnapshot.fingerprint(_snapshot_provider.call()).is_empty():
		return "Load a valid wired biped assembly before searching"
	if goal_edit.text.strip_edges().is_empty() or goal_edit.text.length() > 2000:
		return "Goal must contain 1..2000 characters"
	return MotionPolicy.validate(_policy_provider.call()) if _policy_provider.is_valid() else "No compatible motion program is configured"


func start_search() -> void:
	var issue: String = start_error()
	if not issue.is_empty():
		_status(issue)
		return
	var snapshot: Dictionary = _snapshot_provider.call()
	_search_fingerprint = MotionSnapshot.fingerprint(snapshot)
	var commands: Array[Vector2] = [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]
	var command: Vector2 = commands[direction.selected]
	var payload: Dictionary = {"goal": goal_edit.text.strip_edges(), "graph": snapshot,
		"policy": _policy_provider.call(), "command": [command.x, command.y], "program_id": MotionPolicy.PROGRAM_ID,
		"rounds": int(rounds.value), "allow_paid": allow_paid.button_pressed}
	_job.clear()
	best.clear()
	best_fingerprint = ""
	history_label.text = "Evaluating the current policy as a baseline..."
	SsokLocale.bind(result_label, "No eligible result yet. Fallen or nonfinite candidates cannot be applied.")
	_cancel_pending = false
	_start_uncertain = false
	_status("Starting isolated baseline and candidate evaluations...")
	client.start_search(payload)
	allow_paid.button_pressed = false
	refresh_apply_state()


func cancel_search() -> void:
	_poll_timer.stop()
	_cancel_pending = true
	if _job.has("id") and _active():
		client.cancel_job(_job.id)
		_status("Cancellation requested. An already-sent API request may still be billed.")
	elif client.current_request() == "start":
		_status("Waiting for the search ID, then sending cancellation. Do not start another search.")
	refresh_apply_state()


func _poll() -> void:
	if _active() and not client.is_busy():
		client.poll_job(_job.id)


func _on_response(kind: String, data: Dictionary) -> void:
	if kind == "status":
		if data.get("provider") not in ["mock", "openai"] or not data.get("model") is String or data.get("program_id") != MotionPolicy.PROGRAM_ID:
			_on_failure(kind, "Unexpected bridge capabilities; no search was started")
			return
		_server = data
		_refresh_provider()
		workflow_tabs.current_tab = 1
		_status("Connected. Only the selected direction will be evaluated; improvement is not guaranteed.")
	else:
		if not _accept_job(data):
			_on_failure(kind, "Invalid bridge result; no policy was applied")
			return
		workflow_tabs.current_tab = 2
		if _cancel_pending and _active() and kind != "cancel":
			client.cancel_job(_job.id)
		elif _active():
			_poll_timer.start()
	refresh_apply_state()


func _accept_job(data: Dictionary) -> bool:
	var id_pattern: RegEx = RegEx.new()
	id_pattern.compile("^[a-f0-9]{32}$")
	if not data.get("id") is String or id_pattern.search(data.id) == null:
		return false
	if not _job.is_empty() and data.id != _job.id:
		return false
	if data.get("state") not in ["queued", "baseline", "proposing", "evaluating", "cancelling", "completed", "failed", "cancelled"]:
		return false
	if not data.get("history") is Array or data.history.size() > 5:
		return false
	for entry: Variant in data.history:
		if not entry is Dictionary or not MotionPolicy.validate(entry.get("policy")).is_empty() or not _valid_metrics(entry.get("metrics")):
			return false
		if entry.metrics.get("graph_fingerprint") != _search_fingerprint:
			return false
	_job = data
	if data.get("best") is Dictionary:
		if not _valid_metrics(data.best.get("metrics")) or not MotionPolicy.validate(data.best.get("policy")).is_empty() or data.best.metrics.get("graph_fingerprint") != _search_fingerprint:
			best.clear()
			best_fingerprint = ""
			return false
		if _valid_best(data.best):
			best = _clean_best(data.best)
			best_fingerprint = _search_fingerprint
			_show_best()
	_show_history(data.history)
	var usage: Dictionary = data.get("usage", {}) if data.get("usage", {}) is Dictionary else {}
	var issue: String = str(data.get("error", "")).left(300)
	if not token_edit.text.is_empty():
		issue = issue.replace(token_edit.text, "[redacted]")
	_status("%s | evaluations: %d | API calls: %s | tokens: %s%s", [String(data.state).to_upper(), data.history.size(), str(data.get("api_calls", 0)).left(12), str(usage.get("total_tokens", 0)).left(12), " | " + issue if not issue.is_empty() else ""], [0])
	return true


func _on_failure(kind: String, message: String) -> void:
	_poll_timer.stop()
	message = tr(message)
	if kind == "start":
		_start_uncertain = true
		message += tr(" Start outcome is unknown: a submitted bridge job may still run or be billed. No retry until explicit Disconnect / forget.")
	if kind == "status":
		_server.clear()
		SsokLocale.bind(provider_label, "Not connected. Check the bridge process and bearer token.")
	_status(message + (tr(" Search may still be running on the bridge; Cancel can be retried.") if _active() else ""))
	refresh_apply_state()


func _confirm_forget() -> void:
	_forget_dialog.popup_centered()


func _forget_confirmed() -> void:
	client.abort_request()
	_poll_timer.stop()
	_server.clear()
	_job.clear()
	best.clear()
	best_fingerprint = ""
	_search_fingerprint = ""
	_cancel_pending = false
	_start_uncertain = false
	_forget_dialog.hide()
	allow_paid.button_pressed = false
	SsokLocale.bind(provider_label, "Disconnected. Edit connection details and check the bridge again.")
	SsokLocale.bind(result_label, "No local result retained. Any remote job was NOT cancelled by disconnecting.")
	history_label.text = "Local history forgotten; check the bridge before starting another paid search."
	_status("Local status cleared only. A remote search may still run or be billed; no new request was sent.")
	refresh_apply_state()


func _active() -> bool:
	return not _job.is_empty() and _job.get("state") not in TERMINAL_STATES


func _invalidate_connection() -> void:
	_server.clear()
	if allow_paid != null:
		allow_paid.button_pressed = false
	SsokLocale.bind(provider_label, "Connection details changed. Check connection again.")
	refresh_apply_state()


func apply_error() -> String:
	if _active() or client.is_busy() or _start_uncertain:
		return "Wait for the search to finish or cancel it before applying"
	if not _valid_best(best):
		return "No finite, non-fallen evaluated policy is available"
	if not _editing_provider.is_valid() or not _editing_provider.call():
		return "Return to edit mode before applying a policy"
	if not _snapshot_provider.is_valid() or best_fingerprint.is_empty() or best_fingerprint != MotionSnapshot.fingerprint(_snapshot_provider.call()):
		return "Assembly changed since evaluation; search again for this exact graph"
	return ""


func apply_best() -> bool:
	var issue: String = apply_error()
	if not issue.is_empty():
		_status(issue)
		return false
	if not _apply_policy.is_valid() or not _apply_policy.call(best.policy, best_fingerprint):
		_status("Application rejected; nothing was changed")
		return false
	_status("Applied to the WASD joint program. Close this window and enter Run mode to try it. Source code and assembly are unchanged.")
	return true


func refresh_apply_state() -> void:
	if apply_button == null:
		return
	var busy: bool = client.is_busy() or _active() or _start_uncertain
	endpoint_edit.editable = not busy
	token_edit.editable = not busy
	connect_button.disabled = busy
	start_button.disabled = busy
	cancel_button.disabled = not (_active() or client.current_request() == "start")
	apply_button.disabled = not apply_error().is_empty()
	apply_button.tooltip_text = apply_error()
	save_button.disabled = not _valid_best(best) or best_fingerprint.is_empty() or busy
	load_button.disabled = busy


func _valid_best(value: Variant) -> bool:
	if not value is Dictionary or not MotionPolicy.validate(value.get("policy")).is_empty():
		return false
	if not _valid_metrics(value.get("metrics")):
		return false
	var metrics: Dictionary = value.metrics
	return metrics.finite and not metrics.fallen


func _valid_metrics(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var metrics: Dictionary = value
	if metrics.get("program_id") != MotionPolicy.PROGRAM_ID:
		return false
	if typeof(metrics.get("finite")) != TYPE_BOOL or typeof(metrics.get("fallen")) != TYPE_BOOL:
		return false
	for key: String in METRIC_KEYS:
		if typeof(metrics.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(metrics[key])):
			return false
	return true


func _show_history(history: Array) -> void:
	var rows: PackedStringArray = []
	for index: int in range(history.size()):
		var metrics: Dictionary = history[index].metrics
		var name: String = tr("Baseline") if index == 0 else tr("Candidate %d") % index
		rows.append(tr("%s: score %.3f | forward %+.2f mm | yaw %+.1f deg | fallen %s | finite %s") % [name, metrics.score, metrics.forward_m * 1000.0, rad_to_deg(metrics.yaw_rad), tr(str(metrics.fallen)), tr(str(metrics.finite))])
	history_label.text = "\n".join(rows) if not rows.is_empty() else "Baseline evaluation is pending."


func _clean_best(value: Dictionary) -> Dictionary:
	var metrics: Dictionary = {"finite": true, "fallen": false, "program_id": MotionPolicy.PROGRAM_ID}
	for key: String in METRIC_KEYS:
		metrics[key] = float(value.metrics[key])
	return {"policy": value.policy.duplicate(), "metrics": metrics}


func _show_best() -> void:
	var metrics: Dictionary = best.metrics
	SsokLocale.bind(result_label, "Measured best: score %.4f | finite: true | fallen: false\nForward %+.4f m | lateral %+.4f m | yaw %+.3f rad\nMinimum upright %.3f | minimum height %.4f m\n%s\nA better score is not proof of walking. One direction is not a guarantee for all WASD commands.", [metrics.score, metrics.forward_m, metrics.lateral_m, metrics.yaw_rad, metrics.min_upright, metrics.min_height_m, JSON.stringify(best.policy)])


func save_best() -> bool:
	if not _valid_best(best) or best_fingerprint.is_empty() or _active() or client.is_busy() or _start_uncertain:
		_status("No completed, safe result to save")
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_status("Could not save the result under user://")
		return false
	var record: Dictionary = {"version": 1, "graph_fingerprint": best_fingerprint, "best": _clean_best(best)}
	file.store_string(JSON.stringify(record, "", true, true))
	file.close()
	_status("Saved bounded policy and measured metrics to %s; no credentials or prompt text.", [SAVE_PATH])
	return true


func load_best() -> bool:
	if _active() or client.is_busy() or _start_uncertain:
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or file.get_length() > 8192:
		_status("No valid saved result at %s", [SAVE_PATH])
		return false
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var fingerprint_pattern: RegEx = RegEx.new()
	fingerprint_pattern.compile("^[a-f0-9]{64}$")
	if not value is Dictionary or value.size() != 3 or value.get("version") != 1 or not value.get("graph_fingerprint") is String or fingerprint_pattern.search(value.graph_fingerprint) == null or not _valid_best(value.get("best")):
		_status("Saved result is invalid; nothing was loaded")
		return false
	best = _clean_best(value.best)
	best_fingerprint = value.graph_fingerprint
	_show_best()
	workflow_tabs.current_tab = 2
	_status("Loaded local parameters and recorded metrics (not re-evaluated). Apply requires the exact same assembly in edit mode.")
	refresh_apply_state()
	return true


func _status(message: String, arguments: Array = [], translated_arguments: Array[int] = []) -> void:
	SsokLocale.bind(status_label, message, arguments, translated_arguments)


func _refresh_provider() -> void:
	if _server.provider == "mock":
		SsokLocale.bind(provider_label, "MOCK - no GPT calls; real Godot physics evaluations.")
	else:
		SsokLocale.bind(provider_label, "OPENAI - %s; key configured: %s. Explicit paid consent required.", [String(_server.model).left(80), str(_server.get("key_configured") == true)], [1])


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		for index: int in range(3):
			workflow_tabs.set_tab_title(index, tr(["1. Connect", "2. Search", "3. Results"][index]))
		token_edit.placeholder_text = tr("Token from your local bridge terminal")
		if not _server.is_empty():
			_refresh_provider()
		if not _job.is_empty():
			_show_history(_job.history)
		refresh_apply_state()


func _close_panel() -> void:
	if _active() or client.current_request() == "start":
		cancel_search()
	hide()
	panel_closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		set_input_as_handled()
		_close_panel()
