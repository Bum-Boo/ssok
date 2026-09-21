extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _main: Node3D
var _panel: PickupLabPanel


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	_main.modular_button.pressed.emit()
	_main.motion_lab_button.pressed.emit()
	_panel = _main.pickup_lab
	_panel.source.select(1)
	_panel._snapshot = _main._motion_snapshot()
	_panel._round = 1
	var status: Dictionary = {"provider": "openai", "model": "gpt-5.6-luna", "key_configured": true,
		"calls_used": 0, "max_calls": 4, "pickup": {"supported": true, "policy_family": "humanoid_pickup_v1", "max_candidates": 4}}
	_check(_panel._valid_capabilities(status), "strict known pickup capability accepted")
	for key: String in ["model", "provider", "key_configured", "calls_used", "max_calls", "pickup"]:
		for malformed: Variant in [null, [], {}, "wrong", true, -1, INF, NAN, 1.5]:
			var bad: Dictionary = status.duplicate(true)
			bad[key] = malformed
			if key == "key_configured" and malformed is bool:
				continue
			_check(not _panel._valid_capabilities(bad), "reject malformed capability " + key)
	_panel._server = status.duplicate(true)
	var job: Dictionary = {"id": "0123456789abcdef0123456789abcdef", "state": "queued",
		"provider": "openai", "model": "gpt-5.6-luna", "graph_fingerprint": MotionSnapshot.fingerprint(_panel._snapshot),
		"count": 4, "round": 0, "api_calls": 0}
	_check(_panel._valid_job(job), "known graph-bound pickup job accepted")
	for key: String in ["id", "state", "provider", "model", "graph_fingerprint", "count", "round", "api_calls"]:
		for malformed: Variant in [null, [], {}, "wrong", true, -1, INF, NAN, 1.5]:
			var bad: Dictionary = job.duplicate(true)
			bad[key] = malformed
			_check(not _panel._valid_job(bad), "reject malformed job " + key)
	_panel.allow_paid.button_pressed = false
	_panel.start_search()
	_check(not _panel._active and not _panel.client.is_busy(), "no paid request without explicit consent")
	_panel.allow_paid.button_pressed = true
	_panel.rounds.value = 2
	_panel._server.calls_used = 3
	_panel.start_search()
	_check(not _panel._active and _panel.status_label.text.contains("budget"), "fixed round count cannot exceed shared remaining budget")
	_panel.allow_paid.button_pressed = false
	_panel._on_failure("pickup_start", "test lost submission response")
	_check(_panel._remote_unknown and _panel.start_button.disabled, "unknown submission blocks automatic paid retry")
	_panel._close_panel()
	_main.motion_lab_button.pressed.emit()
	_check(_panel._remote_unknown and _panel.start_button.disabled, "close and reopen preserve unknown submission")
	_panel._forget_connection()
	_check(not _panel._remote_unknown and _panel._server.is_empty() and not _panel.allow_paid.button_pressed, "explicit forget clears only local status and consent")
	if OS.get_environment("SSOK_UI_TEST_URL").is_empty():
		print("SKIP mock HTTP transport: set SSOK_UI_TEST_URL and SSOK_UI_TEST_TOKEN")
	else:
		await _transport()
	_panel._close_panel()
	_main.free()
	await process_frame
	print("pickup_bridge_ui_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _transport() -> void:
	_panel.endpoint_edit.text = OS.get_environment("SSOK_UI_TEST_URL")
	_panel.token_edit.text = OS.get_environment("SSOK_UI_TEST_TOKEN")
	_panel.check_connection()
	await _wait_client()
	_check(_panel._server.get("provider") == "mock", "HTTP fixture is explicitly mock, never paid")
	if _panel._server.get("provider") != "mock":
		return
	_panel.rounds.value = 2
	_panel.parallel_count.value = 4
	_panel.start_search()
	var deadline: int = Time.get_ticks_msec() + 90000
	while _panel._busy() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout
	_check(not _panel._busy() and _panel._entries.size() == 9, "HTTP baseline and two batches produce nine measured local trials")
	var proposed: int = 0
	var successes: int = 0
	for entry: Dictionary in _panel._entries:
		proposed += int(entry.provider == "mock")
		successes += int(entry.result.metrics.success)
	_check(proposed == 8 and successes > 0, "bridge candidates remain mock-labelled and verify physical pickup")
	_check(_panel._server.get("calls_used") == 0 and not _panel.allow_paid.button_pressed, "parallel batches do not incur GPT calls in mock mode")
	_check(_panel._feedback(true).size() == 9, "measured history available for subsequent rounds")
	for record: Dictionary in _panel._feedback(true):
		_check(record.metrics.size() == PickupLabPanel.FEEDBACK_KEYS.size() and not record.has("reason"), "only bounded policy and numeric evidence enter feedback")
	# Submit directly to exercise cancellation while the POST response is still in flight.
	_panel._snapshot = _main._motion_snapshot()
	_panel._round = 1
	_panel._active = true
	_panel._cancel_pending = false
	_panel.client.propose_pickup({"goal": "Pick up the box", "graph_fingerprint": MotionSnapshot.fingerprint(_panel._snapshot),
		"count": 4, "round": 0, "history": [], "allow_paid": false})
	_panel.cancel_search()
	deadline = Time.get_ticks_msec() + 25000
	while (_panel.client.is_busy() or not _panel._remote_id.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout
	_check(not _panel._active and _panel._pending.is_empty() and _panel._running_count() == 0, "cancelling a submitted batch starts no new trials")
	if _panel.client.is_busy() or not _panel._remote_id.is_empty() or _panel._remote_unknown:
		print("Cancellation diagnostics: busy=%s kind=%s id=%s unknown=%s round=%d status=%s" % [_panel.client.is_busy(), _panel.client.current_request(), _panel._remote_id, _panel._remote_unknown, _panel._round, _panel.status_label.text])
	_check(not _panel.client.is_busy() and _panel._remote_id.is_empty() and not _panel._remote_unknown, "submitted mock job reaches a known terminal state")


func _wait_client() -> void:
	var deadline: int = Time.get_ticks_msec() + 25000
	while _panel.client.is_busy() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
