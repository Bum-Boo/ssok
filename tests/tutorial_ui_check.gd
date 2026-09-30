extends SceneTree

const MESSAGES: Array[String] = [
	"Tutorial", "Restart tutorial", "Previous", "Next", "Finish tutorial", "Close and try it",
	"Step %d of %d",
	"Tutorial closed. Input remains stopped; select WASD control or toggle Run mode when ready.",
]
var _main: Node3D
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	var panel: TutorialPanel = _main.tutorial
	_check(not panel.visible, "tutorial starts closed")
	_check(_main.tutorial_button.icon != null, "tutorial has an icon entry point")
	_main.biped_button.pressed.emit()
	var snapshot: String = MotionSnapshot.fingerprint(_main._motion_snapshot())
	var source: String = _main.code_edit.text
	var policy: Dictionary = _main._motion_policy().duplicate(true)
	_main.assembly.select_part(_main.assembly.get_child(1) as PartNode)
	_main._begin_toolbar_transform(&"translate")
	_check(_main.assembly.transform_active, "start pending edit")
	await _click_tutorial_icon()
	_check(panel.visible and panel.exclusive, "icon opens modal tutorial")
	_check(not _main.assembly.transform_active, "opening cancels pending transform")
	_check(_main.assembly.process_mode == Node.PROCESS_MODE_DISABLED and not _main.navigation.navigation_enabled, "background editing and camera blocked")
	_check(panel.previous_button.disabled and panel.restart_button.disabled, "first step bounds")
	_main.motion_lab_button.pressed.emit()
	_check(not _main.motion_lab.visible, "cannot stack lab above tutorial")
	_main.run_button.pressed.emit()
	_check(not _main.runtime.is_running() and not _main.mode_button.button_pressed, "tutorial blocks code start")
	for locale: String in ["ko", "zh_CN", "ja", "en"]:
		SsokLocale.select_locale(locale, false)
		await process_frame
		await process_frame
		_check(Rect2(Vector2.ZERO, root.size).encloses(_main.tutorial_button.get_global_rect()), locale + " entry fits compact header")
		if locale != "en":
			var pack: Translation = load("res://assets/locales/" + locale + ".po") as Translation
			for message: String in MESSAGES:
				_check(not pack.get_message(message).is_empty(), locale + " new UI translation")
			for step: Dictionary in TutorialPanel.STEPS:
				for field: String in ["title", "body", "hint"]:
					_check(not pack.get_message(step[field]).is_empty(), locale + " step translation " + field)
		for step_index: int in range(TutorialPanel.STEPS.size()):
			panel.show_step(step_index)
			await process_frame
			await process_frame
			_check(panel.heading.text == String(TranslationServer.translate(TutorialPanel.STEPS[step_index].title)), locale + " translated title")
			_check(panel.body_label.text == String(TranslationServer.translate(TutorialPanel.STEPS[step_index].body)), locale + " translated body")
			_check(panel.step_label.text == String(TranslationServer.translate("Step %d of %d")) % [step_index + 1, TutorialPanel.STEPS.size()], locale + " progress")
			for control: Control in [panel.next_button, panel.previous_button, panel.restart_button, panel.close_button]:
				_check(Rect2(Vector2.ZERO, panel.size).encloses(control.get_global_rect()), locale + " navigation fits compact window")
			_check(panel.body_label.size.x <= panel.size.x - 48, locale + " body wraps within window")
			await _capture(locale + "-step-" + str(step_index), panel)
			panel._scroll.scroll_vertical = int(panel._scroll.get_v_scroll_bar().max_value)
			await process_frame
			_check(panel._scroll.get_global_rect().encloses(panel.hint_label.get_global_rect()), locale + " final hint is reachable by scrolling")
			if step_index == TutorialPanel.STEPS.size() - 1:
				await _capture(locale + "-last-hint", panel)
		_check(panel.next_button.text == "Finish tutorial", "last step offers finish")
		panel.next_button.pressed.emit()
		_check(not panel.visible, "finish closes tutorial")
		_main.tutorial_button.pressed.emit()
		_check(panel.current_step == TutorialPanel.STEPS.size() - 1, "reopen preserves session position")
		panel.restart_button.pressed.emit()
		_check(panel.current_step == 0, "restart returns to first step")
		panel.next_button.pressed.emit()
		panel.previous_button.pressed.emit()
		_check(panel.current_step == 0, "previous returns to prior step")
		panel.show_step(99)
		_check(panel.current_step == TutorialPanel.STEPS.size() - 1, "upper bound clamped")
		panel.show_step(-1)
		_check(panel.current_step == 0, "lower bound clamped")
	panel.show_step(2)
	SsokLocale.select_locale("ko", false)
	await process_frame
	await process_frame
	_check(panel.current_step == 2 and panel.heading.text == String(TranslationServer.translate(TutorialPanel.STEPS[2].title)), "open tutorial updates language without losing step")
	panel.close_button.pressed.emit()
	_check(not panel.visible and _main.navigation.navigation_enabled and _main.assembly.process_mode != Node.PROCESS_MODE_DISABLED, "close restores edit navigation")
	_check(_main.code_edit.text == source and MotionSnapshot.fingerprint(_main._motion_snapshot()) == snapshot and _main._motion_policy() == policy, "all guide navigation preserves code graph and policy")
	_check(not _main.motion_lab.allow_paid.button_pressed and _main.motion_lab._server.is_empty() and _main.motion_lab._job.is_empty(), "tutorial makes no AI connection trial or consent")
	_main.motion_lab_button.pressed.emit()
	_main.tutorial_button.pressed.emit()
	_check(not panel.visible and _main.motion_lab.visible, "lab blocks tutorial stacking")
	_main.motion_lab._close_panel()
	_main.control_source.select(_main.CONTROL_MANUAL)
	_main.mode_button.button_pressed = true
	_check(_main.manual_controller.is_enabled(), "manual control initially enabled")
	_main.tutorial_button.pressed.emit()
	_check(not _main.manual_controller.is_enabled() and _main.manual_controller.get_move_input().is_zero_approx(), "tutorial stops movement input")
	_check(_main.run_mode.is_built() and _main.mode_button.button_pressed, "tutorial does not rebuild or pause physics")
	_main._apply_control_source()
	_check(not _main.manual_controller.is_enabled(), "control selection cannot enable movement behind tutorial")
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	panel.push_input(key, true)
	await process_frame
	_check(_main.manual_controller.get_move_input().is_zero_approx(), "tutorial keyboard input does not drive")
	key.pressed = false
	panel.push_input(key, true)
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	panel.push_input(key, true)
	await process_frame
	_check(not panel.visible, "Escape closes tutorial")
	_check(not _main.manual_controller.is_enabled() and _main.assembly.process_mode == Node.PROCESS_MODE_DISABLED, "closing during physics does not resume movement or editing")
	_main.code_edit.text = "left = Servo(5)\nleft.write(10)\nsleep(0.1)\nleft.write(90)"
	_main.run_button.pressed.emit()
	_check(_main.runtime.is_running(), "code active before tutorial")
	var drive: ServoDrive = _main.run_mode.servo_on_pin(5)
	_main.tutorial_button.pressed.emit()
	_check(not _main.runtime.is_running(), "opening stops sleeping code")
	await create_timer(0.2).timeout
	_check(drive.target_deg == 10.0, "cancelled code cannot resume behind tutorial")
	panel.close_requested.emit()
	_check(not panel.visible and not _main.runtime.is_running(), "window close keeps code stopped")
	_main.mode_button.button_pressed = false
	_main.free()
	await process_frame
	print("tutorial_ui_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _capture(name: String, viewport: Viewport) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tutorial_previews")
	_check(viewport.get_texture().get_image().save_png("user://tutorial_previews/" + name + ".png") == OK, "capture " + name)


func _click_tutorial_icon() -> void:
	var position: Vector2 = _main.tutorial_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	await process_frame
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.position = position
	button.pressed = true
	root.push_input(button, true)
	await process_frame
	button.pressed = false
	root.push_input(button, true)
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
