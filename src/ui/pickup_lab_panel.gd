class_name PickupLabPanel
extends Window

signal panel_closed

const CANDIDATES_PER_ROUND: int = 4
const FEEDBACK_KEYS: Array[String] = ["finite", "fallen", "success", "lift_m", "hold_seconds", "min_upright", "score", "simulation_seconds"]

var client: MotionLabClient
var tabs: TabContainer
var source: OptionButton
var parallel_count: SpinBox
var rounds: SpinBox
var allow_paid: CheckBox
var goal_edit: TextEdit
var endpoint_edit: LineEdit
var token_edit: LineEdit
var start_button: Button
var cancel_button: Button
var save_button: Button
var replay_button: Button
var apply_button: Button
var result_list: ItemList
var saved_list: ItemList
var name_edit: LineEdit
var selected_label: Label
var status_label: Label
var provider_label: Label
var _grid: GridContainer
var _cards: Array[Dictionary] = []
var _lanes: Dictionary = {}
var _pending: Array[Dictionary] = []
var _entries: Array[Dictionary] = []
var _saved: Array[Dictionary] = []
var _selection: Dictionary = {}
var _snapshot: Dictionary = {}
var _snapshot_provider: Callable
var _editing_provider: Callable
var _apply_policy: Callable
var _server: Dictionary = {}
var _active: bool = false
var _round: int = 0
var _round_limit: int = 0
var _sequence: int = 0
var _completed_count: int = 0
var _bridge_mode: bool = false
var _paid_consent: bool = false
var _remote_id: String = ""
var _remote_unknown: bool = false
var _cancel_pending: bool = false
var _poll_timer: Timer
var _forget_dialog: ConfirmationDialog


func configure(snapshot_provider: Callable, editing_provider: Callable, apply_policy: Callable) -> void:
	_snapshot_provider = snapshot_provider
	_editing_provider = editing_provider
	_apply_policy = apply_policy


func _ready() -> void:
	visible = false
	title = "Pickup learning lab"
	min_size = Vector2i(860, 500)
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
	_build_ui()
	_refresh()


func open_panel() -> void:
	var available: Vector2i = get_tree().root.size - Vector2i(48, 48)
	popup_centered(Vector2i(mini(1240, available.x), mini(840, available.y)))
	_refresh_saved()
	_refresh()


func _build_ui() -> void:
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	_label(layout, "Pickup learning lab", 24)
	_label(layout, "Watch independent physics trials, compare outcomes, then save a scenario. Luna proposes controller parameters; GPT weights are not trained.")
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var experiments: VBoxContainer = _page("Experiments")
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 8)
	experiments.add_child(controls)
	source = OptionButton.new()
	source.add_item("Local search (no GPT)")
	source.add_item("GPT-5.6 Luna via bridge")
	controls.add_child(source)
	_label(controls, "Parallel trials")
	parallel_count = _spin(controls, 1, 4, 2)
	parallel_count.value_changed.connect(func(_value: float) -> void: _pump.call_deferred(); _refresh())
	_label(controls, "Rounds")
	rounds = _spin(controls, 1, 4, 2)
	start_button = _button(controls, "Start pickup search", start_search)
	start_button.theme_type_variation = &"PrimaryButton"
	cancel_button = _button(controls, "Cancel search", cancel_search)
	_label(experiments, "Each round tests four candidates. Change parallelism while running (1–4); fewer lanes drain existing trials. More lanes need more CPU/GPU, not more API calls per round.")
	_grid = GridContainer.new()
	_grid.columns = 2
	experiments.add_child(_grid)
	for lane: int in range(4):
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(card)
		var content := VBoxContainer.new()
		card.add_child(content)
		var label: Label = _label(content, "Waiting for a trial")
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(240, 160)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content.add_child(preview)
		_cards.append({"panel": card, "label": label, "preview": preview})
	_label(experiments, "Measured candidates — select any result")
	result_list = ItemList.new()
	result_list.custom_minimum_size.y = 116
	result_list.item_selected.connect(_select_result)
	experiments.add_child(result_list)
	selected_label = _label(experiments, "No measured result yet.")
	var actions := HFlowContainer.new()
	experiments.add_child(actions)
	name_edit = LineEdit.new()
	name_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_edit.placeholder_text = tr("Scenario name")
	name_edit.max_length = 80
	name_edit.custom_minimum_size.x = 200
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(name_edit)
	save_button = _button(actions, "Save selected scenario", save_selected)
	replay_button = _button(actions, "Replay in physics", replay_selected)
	apply_button = _button(actions, "Apply selected pickup", apply_selected)
	var library: VBoxContainer = _page("Saved scenarios")
	_label(library, "Saved scenarios include the exact assembly, bounded policy and recorded metrics, not credentials or prompts. Loading does not prove success; replay to verify again.")
	saved_list = ItemList.new()
	saved_list.custom_minimum_size.y = 260
	library.add_child(saved_list)
	_button(library, "Refresh library", _refresh_saved)
	_button(library, "Select saved scenario", load_selected)
	var connection: VBoxContainer = _page("Luna connection")
	_label(connection, "Bridge origin (loopback HTTP / deployed HTTPS)")
	endpoint_edit = LineEdit.new()
	endpoint_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	endpoint_edit.text = "http://127.0.0.1:8765"
	connection.add_child(endpoint_edit)
	_label(connection, "Bridge bearer token - RAM only. Never enter an OpenAI API key here.")
	token_edit = LineEdit.new()
	token_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	token_edit.secret = true
	token_edit.max_length = 256
	connection.add_child(token_edit)
	endpoint_edit.text_changed.connect(_connection_changed)
	token_edit.text_changed.connect(_connection_changed)
	_button(connection, "Check connection", check_connection)
	_button(connection, "Disconnect / forget", func() -> void: _forget_dialog.popup_centered())
	provider_label = _label(connection, "Not connected. OPENAI_API_KEY is configured only on the bridge.")
	_label(connection, "Pickup goal (sent with measured feedback, never learner source code)")
	goal_edit = TextEdit.new()
	goal_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	goal_edit.text = tr("Pick up the box with both hands and hold it without falling.")
	goal_edit.custom_minimum_size.y = 70
	goal_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	connection.add_child(goal_edit)
	allow_paid = CheckBox.new()
	allow_paid.text = "Allow paid OpenAI requests for this search"
	connection.add_child(allow_paid)
	_label(connection, "At most one Luna request per round, within the shared bridge call budget. Cancellation may still bill an in-flight call. No automatic paid retries; results may fail.")
	_forget_dialog = ConfirmationDialog.new()
	_forget_dialog.title = "Forget local search status?"
	_forget_dialog.dialog_text = "This only disconnects the local UI. It does NOT cancel a search on the bridge.\nA submitted job may still run and API charges may continue.\nCheck or stop the bridge before starting another paid search.\nLocal connection status and pending results will be cleared."
	_forget_dialog.confirmed.connect(_forget_connection)
	add_child(_forget_dialog)
	status_label = _label(layout, "Ready for local physics search. Luna is optional.")
	status_label.add_theme_color_override("font_color", SsokTheme.ACCENT)
	_button(layout, "Close", _close_panel)


func start_search() -> void:
	if _busy():
		return
	var snapshot: Dictionary = _snapshot_provider.call() if _snapshot_provider.is_valid() else {}
	if MotionSnapshot.decode(snapshot) == null:
		_status("Load a valid humanoid assembly before searching.")
		return
	_bridge_mode = source.selected == 1
	if _bridge_mode:
		if _server.is_empty():
			_status("Check the bridge connection first")
			return
		if _server.provider == "openai" and (not allow_paid.button_pressed or not _server.get("key_configured", false)):
			_status("Paid OpenAI requests require explicit consent for this search")
			return
		if goal_edit.text.strip_edges().is_empty() or goal_edit.text.length() > 2000:
			_status("Goal must contain 1..2000 characters")
			return
		if _server.provider == "openai" and int(_server.get("calls_used", 0)) + int(rounds.value) > int(_server.get("max_calls", 0)):
			_status("Requested rounds exceed the remaining bridge API-call budget.")
			return
	_clear_trials()
	_pending.clear()
	_entries.clear()
	_selection.clear()
	result_list.clear()
	_snapshot = snapshot.duplicate(true)
	_round = 0
	_round_limit = int(rounds.value)
	_completed_count = 0
	_sequence = 0
	_paid_consent = allow_paid.button_pressed
	allow_paid.button_pressed = false
	_cancel_pending = false
	_active = true
	_pending.append({"policy": PickupPolicy.defaults(), "provider": "baseline"})
	_status("Evaluating a measured baseline before proposing candidates.")
	_pump.call_deferred()
	_refresh()


func _pump() -> void:
	if not _active:
		return
	for lane: int in range(int(parallel_count.value)):
		if _pending.is_empty():
			break
		if _lanes.has(lane) and _lanes[lane].is_running:
			continue
		if _lanes.has(lane):
			_lanes[lane].free()
		var trial := PickupTrial.new()
		add_child(trial)
		_lanes[lane] = trial
		var candidate: Dictionary = _pending.pop_front()
		_sequence += 1
		var number: int = _sequence
		trial.progress_changed.connect(func(metrics: Dictionary) -> void: _show_progress(lane, number, metrics))
		trial.completed.connect(func(result: Dictionary) -> void: _on_trial_finished(lane, number, candidate.provider, result))
		var issue: String = trial.start_trial(MotionSnapshot.decode(_snapshot), candidate.policy, true)
		if not issue.is_empty():
			cancel_search()
			_status("Pickup trial could not start. Check the assembly and wiring.")
			return
		_cards[lane].preview.texture = trial.viewport.get_texture()
	if _pending.is_empty() and _running_count() == 0 and _remote_id.is_empty() and not client.is_busy():
		_next_round()
	_refresh()


func _next_round() -> void:
	if not _active:
		return
	if _round >= _round_limit:
		_active = false
		_status("Search finished: %d measured trials. Select a result to replay or save.", [_completed_count])
		_refresh()
		_reveal_results.call_deferred()
		return
	_round += 1
	_status("Round %d / %d — preparing four candidates.", [_round, _round_limit])
	if not _bridge_mode:
		_queue_candidates(PickupPolicy.mock_candidates(CANDIDATES_PER_ROUND, _round - 1, _feedback()), "local")
	else:
		client.propose_pickup({"goal": goal_edit.text.strip_edges(), "graph_fingerprint": MotionSnapshot.fingerprint(_snapshot),
			"count": CANDIDATES_PER_ROUND, "round": _round - 1, "history": _feedback(true), "allow_paid": _paid_consent})
	_refresh()


func _queue_candidates(candidates: Array, provider: String) -> void:
	for candidate: Variant in candidates:
		if not candidate is Dictionary or candidate.size() != 2 or not candidate.get("reason") is String or candidate.reason.length() > 400 or not PickupPolicy.validate(candidate.get("policy")).is_empty():
			cancel_search()
			_status("Invalid pickup proposal; nothing was applied.")
			return
	for candidate: Dictionary in candidates:
		_pending.append({"policy": candidate.policy.duplicate(true), "provider": provider})
	_pump.call_deferred()


func _on_trial_finished(_lane: int, number: int, provider: String, result: Dictionary) -> void:
	if not PickupPolicy.validate(result.get("policy")).is_empty() or not PickupPolicy.valid_metrics(result.get("metrics")) or result.metrics.graph_fingerprint != MotionSnapshot.fingerprint(_snapshot):
		cancel_search()
		_status("Invalid pickup result; nothing was saved or applied.")
		return
	_completed_count += 1
	_entries.append({"result": result.duplicate(true), "snapshot": _snapshot.duplicate(true), "provider": provider, "fresh": true, "number": number})
	_rebuild_results()
	if _selection.is_empty() or provider == "replay":
		_select_result(_entries.size() - 1)
	_pump.call_deferred()
	_refresh()


func _show_progress(lane: int, number: int, metrics: Dictionary) -> void:
	SsokLocale.bind(_cards[lane].label, "Trial %d · %s\nLift %.1f cm · hold %.1f s", [number, str(metrics.get("phase", "")), float(metrics.get("lift_m", 0)) * 100.0, float(metrics.get("hold_seconds", 0))], [1])


func _select_result(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_selection = _entries[index].duplicate(true)
	result_list.select(index)
	_show_selection()
	_refresh()


func _show_selection() -> void:
	if _selection.is_empty():
		SsokLocale.bind(selected_label, "No measured result yet.")
		return
	var metrics: Dictionary = _selection.result.metrics
	SsokLocale.bind(selected_label, "Selected trial %d · %s · lift %.1f cm · hold %.1f s · score %.2f\nSource: %s · %s", [int(_selection.get("number", 0)), _outcome(metrics), metrics.lift_m * 100.0, metrics.hold_seconds, metrics.score, _selection.provider, "Fresh physics evaluation" if _selection.fresh else "Saved metrics — replay required before applying"], [1, 5, 6])
	if name_edit.text.strip_edges().is_empty():
		name_edit.text = tr("Pickup scenario %d") % int(_selection.get("number", 1))


func save_selected() -> bool:
	if _selection.is_empty():
		return false
	var saved: Dictionary = PickupScenarioStore.save_scenario(name_edit.text, _selection.snapshot, _selection.result, _selection.provider)
	if saved.has("error"):
		_status(saved.error)
		return false
	_status("Scenario saved locally: %s", [saved.path])
	_refresh_saved()
	return true


func replay_selected() -> void:
	if _selection.is_empty() or _busy():
		return
	_clear_trials()
	_snapshot = _selection.snapshot.duplicate(true)
	_pending.assign([{"policy": _selection.result.policy.duplicate(true), "provider": "replay"}])
	_round = 0
	_round_limit = 0
	_active = true
	_cancel_pending = false
	_pump.call_deferred()
	_status("Replaying the selected assembly and policy in fresh physics.")
	_refresh()


func apply_selected() -> bool:
	if not _can_apply():
		_status("Apply requires a successful fresh trial and the unchanged assembly in edit mode.")
		return false
	if not _apply_policy.is_valid() or not _apply_policy.call(_selection.result.policy, MotionSnapshot.fingerprint(_selection.snapshot)):
		return false
	_status("Pickup policy applied. Close the lab, enter Run mode and press E.")
	return true


func load_selected() -> bool:
	if _busy() or saved_list.get_selected_items().is_empty():
		return false
	var index: int = saved_list.get_selected_items()[0]
	var record: Dictionary = PickupScenarioStore.load_scenario(_saved[index].id)
	if record.is_empty():
		_status("Saved scenario is invalid; nothing was loaded.")
		return false
	_selection = {"snapshot": record.graph, "result": record.result, "provider": record.provider, "fresh": false}
	name_edit.text = record.name
	tabs.current_tab = 0
	_show_selection()
	_status("Loaded a saved scenario without changing the workshop. Replay to verify it.")
	_refresh()
	_reveal_results.call_deferred()
	return true


func _reveal_results() -> void:
	var scroll: ScrollContainer = result_list.get_parent().get_parent() as ScrollContainer
	if visible and tabs.current_tab == 0:
		scroll.ensure_control_visible(apply_button)


func _refresh_saved() -> void:
	_saved = PickupScenarioStore.list_scenarios()
	saved_list.clear()
	for entry: Dictionary in _saved:
		var record: Dictionary = entry.record
		saved_list.add_item("%s · %s" % [record.name, tr(_outcome(record.result.metrics))])


func _rebuild_results() -> void:
	result_list.clear()
	for entry: Dictionary in _entries:
		var metrics: Dictionary = entry.result.metrics
		result_list.add_item(tr("Trial %d · %s · %.1f cm · score %.2f") % [entry.number, tr(_outcome(metrics)), metrics.lift_m * 100.0, metrics.score])
		if not _selection.is_empty() and entry.number == _selection.get("number", -1):
			result_list.select(result_list.item_count - 1)


func _feedback(for_model: bool = false) -> Array:
	var history: Array = []
	for entry: Dictionary in _entries:
		if entry.result.metrics.graph_fingerprint != MotionSnapshot.fingerprint(_snapshot) or entry.result.metrics.get("cancelled", false):
			continue
		var metrics: Dictionary = entry.result.metrics.duplicate(true)
		if for_model:
			metrics.clear()
			for key: String in FEEDBACK_KEYS:
				metrics[key] = entry.result.metrics[key]
		history.append({"policy": entry.result.policy.duplicate(true), "metrics": metrics})
	return history.slice(maxi(0, history.size() - 32))


func cancel_search() -> void:
	_active = false
	_cancel_pending = true
	_pending.clear()
	for trial: PickupTrial in _lanes.values():
		if trial.is_running:
			trial.cancel()
	if not _remote_id.is_empty():
		client.cancel_pickup(_remote_id)
	_status("Local trials stopped. An already-sent Luna request may still be billed.")
	_refresh()


func check_connection() -> void:
	if _busy():
		return
	_server.clear()
	var issue: String = client.configure(endpoint_edit.text, token_edit.text)
	if not issue.is_empty():
		_status(issue)
		return
	client.check_status()
	_refresh()


func _poll() -> void:
	if not _remote_id.is_empty() and not client.is_busy():
		client.poll_pickup(_remote_id)


func _on_response(kind: String, data: Dictionary) -> void:
	if kind == "status":
		if not _valid_capabilities(data):
			_status("Bridge does not support pickup proposals. Update the local bridge.")
			return
		_server = data
		SsokLocale.bind(provider_label, "Provider: %s · shared API calls %d / %d", [data.provider, int(data.get("calls_used", 0)), int(data.get("max_calls", 0))], [0])
		_status("Pickup bridge connected. Local physics will verify every proposal.")
	else:
		if not _valid_job(data):
			_on_failure(kind, "")
			return
		_remote_id = data.id
		if data.state in ["completed", "failed", "cancelled"]:
			_remote_id = ""
			_server.calls_used = int(_server.get("calls_used", 0)) + int(data.get("api_calls", 0))
			SsokLocale.bind(provider_label, "Provider: %s · shared API calls %d / %d", [_server.provider, int(_server.calls_used), int(_server.max_calls)], [0])
			if data.state == "completed" and _active and not _cancel_pending:
				if not data.get("candidates") is Array or data.candidates.size() != CANDIDATES_PER_ROUND:
					_on_failure(kind, "")
					return
				_queue_candidates(data.candidates, "openai" if _server.provider == "openai" else "mock")
			elif not _cancel_pending:
				_active = false
				_status("Pickup proposal failed. Check bridge settings and request limits; no automatic retry.")
		elif _cancel_pending and kind != "pickup_cancel":
			client.cancel_pickup(_remote_id)
		else:
			_poll_timer.start()
	_refresh()


func _valid_capabilities(data: Dictionary) -> bool:
	if data.get("provider") not in ["mock", "openai"] or not data.get("model") is String or data.model != "gpt-5.6-luna" or not data.get("key_configured") is bool:
		return false
	if not _integer_range(data.get("calls_used"), 0, 32) or not _integer_range(data.get("max_calls"), 1, 32) or data.calls_used > data.max_calls:
		return false
	var capability: Variant = data.get("pickup")
	return capability is Dictionary and capability.get("supported") is bool and capability.supported and capability.get("policy_family") is String and capability.policy_family == "humanoid_pickup_v1" and _integer_range(capability.get("max_candidates"), 4, 4)


func _valid_job(data: Dictionary) -> bool:
	if not data.get("id") is String or RegEx.create_from_string("^[a-f0-9]{32}$").search(data.id) == null or (not _remote_id.is_empty() and data.id != _remote_id):
		return false
	if not data.get("graph_fingerprint") is String or data.graph_fingerprint != MotionSnapshot.fingerprint(_snapshot) or data.get("state") not in ["queued", "proposing", "cancelling", "completed", "failed", "cancelled"]:
		return false
	if not data.get("model") is String or data.model != "gpt-5.6-luna" or not data.get("provider") is String or data.provider != _server.get("provider") or not _integer_range(data.get("count"), CANDIDATES_PER_ROUND, CANDIDATES_PER_ROUND) or not _integer_range(data.get("round"), _round - 1, _round - 1):
		return false
	return _integer_range(data.get("api_calls"), 0, 1) and (_server.provider != "mock" or data.api_calls == 0)


static func _integer_range(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


func _on_failure(kind: String, _message: String) -> void:
	_poll_timer.stop()
	_active = false
	if kind == "pickup_start":
		_remote_unknown = true
		_status("Luna submission outcome is unknown. Check the bridge before using Disconnect / forget. No automatic retry.")
	else:
		_status("Pickup proposal failed. Check bridge settings and request limits; no automatic retry.")
	_refresh()


func _forget_connection() -> void:
	cancel_search()
	client.abort_request()
	_poll_timer.stop()
	_remote_id = ""
	_remote_unknown = false
	_server.clear()
	allow_paid.button_pressed = false
	_status("Disconnected locally. Any remote request was NOT cancelled by forgetting.")
	_refresh()


func _connection_changed(_text: String) -> void:
	_server.clear()
	allow_paid.button_pressed = false
	SsokLocale.bind(provider_label, "Connection details changed. Check connection again.")


func _can_apply() -> bool:
	return not _busy() and not _selection.is_empty() and _selection.fresh and _selection.result.metrics.success and _selection.result.metrics.finite and not _selection.result.metrics.fallen and _editing_provider.is_valid() and _editing_provider.call() and _snapshot_provider.is_valid() and MotionSnapshot.fingerprint(_snapshot_provider.call()) == MotionSnapshot.fingerprint(_selection.snapshot)


func _busy() -> bool:
	return _active or client.is_busy() or not _remote_id.is_empty() or _remote_unknown


func _running_count() -> int:
	var count: int = 0
	for trial: PickupTrial in _lanes.values():
		count += int(trial.is_running)
	return count


func _refresh() -> void:
	if start_button == null:
		return
	var busy: bool = _busy()
	start_button.disabled = busy
	cancel_button.disabled = not (_active or not _remote_id.is_empty() or client.current_request() == "pickup_start")
	source.disabled = busy
	rounds.editable = not busy
	goal_edit.editable = not busy
	endpoint_edit.editable = not busy
	token_edit.editable = not busy
	allow_paid.disabled = busy
	save_button.disabled = _selection.is_empty()
	replay_button.disabled = busy or _selection.is_empty()
	apply_button.disabled = not _can_apply()
	for lane: int in range(4):
		_cards[lane].panel.visible = (lane < int(parallel_count.value) and (_active or _entries.is_empty())) or _lanes.has(lane)


func _clear_trials() -> void:
	for trial: PickupTrial in _lanes.values():
		trial.free()
	_lanes.clear()
	for card: Dictionary in _cards:
		card.preview.texture = null
		SsokLocale.bind(card.label, "Waiting for a trial")


func _close_panel() -> void:
	if _active or not _remote_id.is_empty() or client.current_request() == "pickup_start":
		cancel_search()
	_clear_trials()
	hide()
	panel_closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		set_input_as_handled()
		_close_panel()


func _exit_tree() -> void:
	if client != null and not _remote_id.is_empty():
		client.cancel_pickup(_remote_id)
	_clear_trials()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		for index: int in range(3):
			tabs.set_tab_title(index, tr(["Experiments", "Saved scenarios", "Luna connection"][index]))
		name_edit.placeholder_text = tr("Scenario name")
		_rebuild_results()
		_show_selection()
		_refresh_saved()


static func _outcome(metrics: Dictionary) -> String:
	if metrics.phase == "cancelled":
		return "Cancelled"
	return "Pickup succeeded" if metrics.success else "Pickup failed"


func _status(message: String, arguments: Array = []) -> void:
	SsokLocale.bind(status_label, message, arguments)


func _page(label: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.name = label
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	return content


func _label(parent: Node, text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent is HFlowContainer:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _spin(parent: Node, minimum: int, maximum: int, initial: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = initial
	parent.add_child(spin)
	return spin
