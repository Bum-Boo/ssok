extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	var app: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app._load_preset(RobotCarPreset.build(0.5), RobotCarPreset.BRAKE_CODE, "")
	app.mode_button.button_pressed = true
	app.program_tabs.current_tab = app.agent_panel.get_index()
	await process_frame
	var inbox: AgentGoalInbox = app.agent_goal_inbox
	var panel: AgentTracePanel = app.agent_panel
	panel._goal_field.text = "Observe the wall and stop."
	panel._refresh_state()
	_check(panel._run_button.disabled, "Disconnected operator blocks dispatch")
	var identity: String = "fixture-operator-20261010"
	var poll: Dictionary = inbox.poll({"operator_id": identity})
	_check(poll.job.is_empty() and inbox.connected(), "Polling registers operator without dispatch")
	_check(not panel._run_button.disabled, "Connected operator allows a nonempty supported goal")
	panel._goal_field.text_submitted.emit(panel._goal_field.text)
	_check(not inbox.busy(), "Enter in goal field never dispatches")
	if DisplayServer.get_name() != "headless":
		panel._run_button.pressed.emit()
		_check(inbox.busy() and panel._run_button.disabled, "One click queues and blocks duplicates")
		var request: String = str(inbox._request.get("request_id", ""))
		panel._run_button.pressed.emit()
		_check(str(inbox._request.get("request_id", "")) == request, "Disabled second click does not replace request")
		_check(panel._enable_button.disabled and panel._capture_button.disabled and panel._forward_button.disabled, "Goal reserves local camera controls")
		_check(not panel._stop_button.disabled, "Stop stays available")
		for tick: int in 300:
			if app.agent_loop.state == "ready":
				break
			await physics_frame
		poll = inbox.poll({"operator_id": identity})
		_check(poll.get("job", {}).get("request_id") == request, "Operator claims current ready goal")
		_check(inbox.poll({"operator_id": identity}).job.is_empty(), "Claim is not replayed")
		app._on_stop_pressed()
		_check(not inbox.busy() and not app.agent_loop.enabled, "Local Stop revokes queue and camera")
		_check(inbox.poll({"operator_id": identity}).job.is_empty(), "Stopped goal cannot reappear")
	_check(inbox.poll({"operator_id": "another-operator-identity"}).has("error"), "Second live operator rejected")
	inbox.leave({"operator_id": identity})
	_check(not inbox.connected() and panel._run_button.disabled, "Leaving disconnects and blocks Run")
	var original_goal: String = panel._goal_field.text
	for language: String in ["en", "ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(language, false)
		_check(panel._goal_field.text == original_goal, "Language switch preserves raw goal")
	if "--screenshots" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("user://agent_goal_previews")
		for language: String in ["en", "ko", "zh_CN", "ja"]:
			SsokLocale.select_locale(language, false)
			for theme_id: String in ["dark", "light"]:
				root.get_node("Preferences").set_preference("appearance", theme_id)
				for screen: String in ["wide", "compact", "large"]:
					root.size = Vector2i(1152, 648) if screen == "compact" else Vector2i(1600, 1000)
					root.get_node("Preferences").set_preference("text_scale", 2.0 if screen == "large" else 1.0)
					panel.set_goal_status(true, false)
					panel._scroll.scroll_vertical = 0
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("user://agent_goal_previews/%s-%s-%s.png" % [language, theme_id, screen])
					for button: Button in [panel._enable_button, panel._capture_button, panel._forward_button, panel._run_button]:
						print(JSON.stringify({"capture": "%s-%s-%s" % [language, theme_id, screen], "button": button.text, "translated": button.tr(button.text), "size": str(button.size), "min": str(button.get_combined_minimum_size()), "clip": button.clip_text, "overrun": button.text_overrun_behavior, "font_size": button.get_theme_font_size("font_size")}))
					for layout_frame: int in 8:
						await process_frame
					panel._run_button.grab_focus()
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("user://agent_goal_previews/%s-%s-%s-run.png" % [language, theme_id, screen])
					print(JSON.stringify({"scrolled": "%s-%s-%s" % [language, theme_id, screen], "run_rect": str(panel._run_button.get_global_rect()), "scroll_rect": str(panel._scroll.get_global_rect()), "scroll_y": panel._scroll.scroll_vertical}))
					_check(panel._scroll.get_global_rect().encloses(panel._run_button.get_global_rect()), "Focused Run fully inside scroll viewport")
					_check(panel._run_button.has_focus() and not panel._stop_button.disabled, "Scrolled keyboard Run and pinned Stop stay available")
					panel._run_button.release_focus()

	print("Agent goal UI checks: %d / failures: %d" % [checks, failures])
	app.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
