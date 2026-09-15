extends SceneTree

var _failed: int = 0
var _checks: int = 0
var _main: Node3D
var _panel: MotionLabPanel
var _saved_before: PackedByteArray = PackedByteArray()
var _had_saved_file: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 950)
	_had_saved_file = FileAccess.file_exists(MotionLabPanel.SAVE_PATH)
	if _had_saved_file:
		_saved_before = FileAccess.get_file_as_bytes(MotionLabPanel.SAVE_PATH)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	_panel = _main.motion_lab
	_main.biped_button.pressed.emit()
	var initial_code: String = _main.code_edit.text
	var fingerprint: String = MotionSnapshot.fingerprint(_main._motion_snapshot())
	_check(not fingerprint.is_empty(), "current biped has a stable snapshot fingerprint")
	_main.mode_button.button_pressed = true
	_main.motion_lab_button.pressed.emit()
	_check(_panel.visible and not _main.manual_controller.is_enabled(), "opening the lab stops manual control")
	_check(not _main.runtime.is_running() and not _main.navigation.navigation_enabled, "modal lab suspends code and viewport navigation")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	key.unicode = 119
	_panel.goal_edit.grab_focus()
	_panel.push_input(key, true)
	await process_frame
	_check(_main.manual_controller.get_move_input().is_zero_approx(), "typing a goal cannot leave WASD movement active")
	var record: Dictionary = _fixture(fingerprint)
	_panel.best = _panel._clean_best(record)
	_panel.best_fingerprint = fingerprint
	_check(not _panel.apply_best(), "applying while physics is running is rejected")
	_panel._close_panel()
	_main.mode_button.button_pressed = false
	_main.motion_lab_button.pressed.emit()
	_check(_panel.apply_best(), "same-graph edit-mode result applies explicitly")
	_check(is_equal_approx(_main.motion_program.posture_degrees, 2.0), "apply changes the existing WASD joint program")
	_check(_main.code_edit.text == initial_code and MotionSnapshot.fingerprint(_main._motion_snapshot()) == fingerprint, "apply changes neither learner code nor assembly")
	var original_pose: Transform3D = _main.assembly.graph.parts[0].transform
	_main.assembly.graph.parts[0].transform.origin.x += 0.01
	_main.assembly.graph_changed.emit()
	_check(not _panel.apply_error().is_empty() and _panel.apply_button.disabled, "changed graph invalidates the result immediately")
	_check(MotionPolicy.read(_main.motion_program) == MotionPolicy.defaults(), "changing the graph resets its applied policy to defaults")
	_check(not _panel.apply_best(), "stale policy cannot be applied to a changed graph")
	_main.assembly.graph.parts[0].transform = original_pose
	_main.assembly.graph_changed.emit()
	_check(_panel.apply_error().is_empty(), "restoring the exact assembly permits explicit reapplication")
	_panel.best.metrics.fallen = true
	_check(not _panel.apply_best(), "fallen result is rejected")
	_panel.best = _panel._clean_best(record)
	_panel.best.policy.stride_degrees = INF
	_check(not _panel.apply_best(), "nonfinite policy is rejected")
	_panel.best = _panel._clean_best(record)
	_panel._search_fingerprint = fingerprint
	var stale_job: Dictionary = {"id": "0123456789abcdef0123456789abcdef", "state": "completed", "history": [record], "best": record.duplicate(true)}
	stale_job.best.metrics.graph_fingerprint = "bad-fingerprint"
	_check(not _panel._accept_job(stale_job) and _panel.best.is_empty(), "bridge metrics must match the locally captured graph fingerprint")
	var bad_history: Dictionary = stale_job.duplicate(true)
	bad_history.history[0].metrics.score = "not-a-number"
	_check(not _panel._accept_job(bad_history), "malformed history metrics are rejected before rendering")
	_panel._job.clear()
	_panel.best = _panel._clean_best(record)
	_panel.best_fingerprint = fingerprint
	_panel.token_edit.text = "ssok-ui-fixture-token-never-persist"
	_panel.goal_edit.text = "PRIVATE_GOAL_FIXTURE_NEVER_PERSIST"
	_check(_panel.save_best(), "result can be saved under user://")
	var saved: String = FileAccess.get_file_as_string(MotionLabPanel.SAVE_PATH)
	_check(not saved.contains(_panel.token_edit.text) and not saved.contains(_panel.goal_edit.text) and not saved.contains("reason"), "saved result excludes token, goal and model output text")
	_panel.best.clear()
	_check(_panel.load_best() and _panel.apply_error().is_empty(), "saved bounded policy loads without automatic application")
	_check(MotionPolicy.read(_main.motion_program) == MotionPolicy.defaults(), "loading alone does not change the active movement program")
	_panel._server = {"provider": "openai", "model": "gpt-5.6-luna", "key_configured": true}
	_panel.allow_paid.button_pressed = false
	_check(_panel.start_error().contains("consent"), "live API search requires explicit consent")
	_panel.allow_paid.button_pressed = true
	_check(_panel.start_error().is_empty(), "live consent permits a valid search request without sending it")
	_panel.allow_paid.button_pressed = false
	_check(MotionLabClient.endpoint_error("http://example.com:8765").length() > 0, "unencrypted non-loopback endpoint is rejected")
	_check(MotionLabClient.endpoint_error("http://127.0.0.1.evil:8765").length() > 0, "loopback-looking external hostname is rejected")
	_check(MotionLabClient.endpoint_error("https://user:secret@example.com").length() > 0, "URL credentials are rejected")
	_check(MotionLabClient.endpoint_error("http://127.0.0.1:70000").length() > 0, "invalid TCP port is rejected")
	_check(MotionLabClient.endpoint_error("http://[::1]:8765").is_empty() and MotionLabClient.endpoint_error("https://bridge.example.com").is_empty(), "loopback IPv6 and HTTPS origins are accepted")
	_check(_panel.client.configure("http://127.0.0.1:8765", "sk-proj-DO_NOT_SEND_THIS_KEY_TO_BRIDGE").contains("OpenAI"), "OpenAI API key pasted in bridge field is rejected")
	_panel.endpoint_edit.text = "http://127.0.0.1:65534"
	_panel.check_connection()
	await _wait_client()
	_check(_panel._server.is_empty() and _panel.status_label.text.contains("failed"), "failed HTTP connection is safe and leaves the lab disconnected")
	_panel._job = {"id": "0123456789abcdef0123456789abcdef", "state": "evaluating"}
	_panel._on_failure("poll", "Unavailable bridge fixture")
	_check(not _panel.token_edit.editable and not _panel.disconnect_button.disabled, "unavailable active search exposes explicit recovery without silently forgetting")
	_panel.disconnect_button.pressed.emit()
	_check(_panel._forget_dialog.visible and _panel._forget_dialog.dialog_text.contains("does NOT cancel"), "disconnect requires acknowledgement that the remote search is not cancelled")
	_panel._forget_dialog.confirmed.emit()
	_check(_panel._job.is_empty() and _panel.token_edit.editable and _panel.endpoint_edit.editable, "confirmed forget permits new bridge credentials after a restart")
	_panel._on_failure("start", "Lost start response fixture")
	_check(_panel._start_uncertain and _panel.start_error().contains("unknown"), "lost start response blocks implicit paid retry")
	_panel._close_panel()
	_main.motion_lab_button.pressed.emit()
	_check(_panel._start_uncertain and _panel.start_button.disabled, "closing and reopening does not silently forget an unknown start")
	_panel._forget_confirmed()
	_check(not _panel._start_uncertain and not _panel.client.is_busy() and _panel._server.is_empty(), "explicit recovery resets local state without sending a new search")
	if not OS.get_environment("SSOK_UI_TEST_URL").is_empty():
		await _check_http_flow()
	else:
		print("SKIP live bridge transport fixture: set SSOK_UI_TEST_URL and SSOK_UI_TEST_TOKEN (mock server only)")
	_panel._close_panel()
	_check(_main.navigation.navigation_enabled and not _main.manual_controller.is_enabled(), "closing restores navigation without automatically resuming movement")
	_main.free()
	await process_frame
	if _had_saved_file:
		var file: FileAccess = FileAccess.open(MotionLabPanel.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_saved_before)
		file.close()
	else:
		DirAccess.remove_absolute(MotionLabPanel.SAVE_PATH)
	print("motion_lab_ui_check: %d checks, %d failures" % [_checks, _failed])
	quit(1 if _failed else 0)


func _fixture(fingerprint: String) -> Dictionary:
	var policy: Dictionary = MotionPolicy.defaults()
	policy.posture_degrees = 2.0
	return {"policy": policy, "reason": "Synthetic UI fixture, not a measured gait result", "metrics": {
		"forward_m": 0.02, "lateral_m": 0.001, "yaw_rad": 0.02, "min_upright": 0.99,
		"min_height_m": 0.12, "score": 0.5, "finite": true, "fallen": false, "graph_fingerprint": fingerprint}}


func _check_http_flow() -> void:
	_panel.endpoint_edit.text = OS.get_environment("SSOK_UI_TEST_URL")
	_panel.token_edit.text = OS.get_environment("SSOK_UI_TEST_TOKEN")
	_panel.check_connection()
	await _wait_client()
	_check(_panel._server.get("provider") == "mock", "HTTP fixture is explicitly a mock provider")
	if _panel._server.get("provider") != "mock":
		return
	_panel.goal_edit.text = "Walk forward while staying upright"
	_panel.rounds.value = 1
	if OS.get_environment("SSOK_UI_DUMP_GRAPH") == "1":
		print("SSOK_UI_GRAPH=", JSON.stringify(_main._motion_snapshot(), "", true, true))
	_panel.start_search()
	var deadline: int = Time.get_ticks_msec() + 120000
	while (str(_panel._job.get("state", "")) not in MotionLabPanel.TERMINAL_STATES or _panel.client.is_busy()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_check(_panel._job.get("state") == "completed", "native HTTP starts and polls an isolated Godot trial to completion")
	_check(_panel._job.get("api_calls") == 0 and _panel._job.get("history", []).size() == 2, "mock search records baseline and candidate without GPT calls")
	_check(_panel._job.get("best", {}).get("metrics", {}).get("graph_fingerprint") == MotionSnapshot.fingerprint(_main._motion_snapshot()), "real HTTP trial returns the evaluated assembly fingerprint")
	var measured: Dictionary = _panel._job.get("best", {}).get("metrics", {})
	var eligible: bool = measured.get("finite") == true and measured.get("fallen") == false
	print("HTTP measured outcome: fallen=%s finite=%s score=%s" % [str(measured.get("fallen")), str(measured.get("finite")), str(measured.get("score"))])
	_check(eligible, "full-precision graph transport preserves the stable biped baseline")
	_check(_panel.apply_best() == eligible, "real HTTP result is applied only if the measured gait stayed finite and upright")
	_check(_panel.history_label.text.contains("Baseline") and _panel.history_label.text.contains("Candidate 1"), "HTTP UI explains baseline and candidate scores, direction and falls")
	_panel.start_search()
	_panel.cancel_search()
	deadline = Time.get_ticks_msec() + 15000
	while (str(_panel._job.get("state", "")) not in MotionLabPanel.TERMINAL_STATES or _panel.client.is_busy()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_check(_panel._job.get("state") == "cancelled", "cancellation queued during start reaches the server")
	await create_timer(0.05).timeout
	_panel.start_search()
	await _wait_client()
	if _panel._active():
		_panel.client.poll_job(_panel._job.id)
		_check(_panel.client.current_request() == "poll", "test begins with an in-flight status poll")
		_panel.cancel_search()
		_check(_panel.client.current_request() == "cancel", "cancellation preempts the in-flight poll")
		deadline = Time.get_ticks_msec() + 15000
		while (str(_panel._job.get("state", "")) not in MotionLabPanel.TERMINAL_STATES or _panel.client.is_busy()) and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		_check(_panel._job.get("state") == "cancelled", "poll-preempting cancellation reaches the bridge")
	else:
		_check(false, "a second cancellation fixture must start")


func _wait_client() -> void:
	var deadline: int = Time.get_ticks_msec() + 25000
	while _panel.client.is_busy() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout


func _check(condition: bool, message: String) -> void:
	_checks += 1
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failed += 1
