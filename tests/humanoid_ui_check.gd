extends SceneTree

var _main: Node3D
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 950)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	var modular: bool = "--modular" in OS.get_cmdline_user_args()
	if modular:
		_main.modular_button.pressed.emit()
	else:
		_main.humanoid_button.pressed.emit()
	_check(_main.motion_program is HumanoidMotion, "humanoid preset selects its own joint program")
	_check((_main.assembly.graph.parts.size() > 38 and _main.motion_program is KitHumanoidMotion) if modular else _main.assembly.graph.parts.size() == 14, "preset includes physical humanoid and cargo")
	_check(not _main.motion_lab_button.disabled, "humanoid pickup AI family is available")
	_check(_main.control_source.selected == _main.CONTROL_MANUAL, "preset selects high-level controls")
	for locale: String in ["ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(locale, false)
		var pack: Translation = load("res://assets/locales/" + locale + ".po") as Translation
		for entry: Dictionary in _main.assembly.graph.parts:
			_check(not pack.get_message(entry.part_def.display_name).is_empty(), locale + " humanoid part translated")
		for message: String in [
			"Experimental humanoid: torque-controlled joints",
			"Humanoid fell. Return to edit mode to reset.",
			"Move closer and face the box before picking it up.",
			"Could not reach the box. Reset and move closer.",
			"Box gripped through hand contact. Lifting.",
			"Box held. E releases it; Stop also releases the grip.",
			"Box released under gravity.",
			"Humanoid needs all ten joints and unambiguous wiring. Reload the humanoid preset to reset.",
			"Humanoid loaded. W/S walk, Shift sprint trial, E pick up or release. A/D turning is not supported yet.",
			"Humanoid experiment: W/S walk, Shift running experiment (unstable), E pick/release. The gripper needs contact with both hands. AI lab: parallel pickup search; no GPT weight training.",
			_main.humanoid_button.text,
		]:
			_check(not pack.get_message(message).is_empty(), locale + " humanoid status translated")
		await process_frame
		await process_frame
		_check(_main.humanoid_button.get_global_rect().end.y < root.size.y, locale + " starter remains reachable")
		_check(not _main._movement_instructions.visible, locale + " unsupported turning instructions hidden")
		await _capture(locale + "-edit")
		_main.tutorial_button.pressed.emit()
		_main.tutorial.show_step(TutorialPanel.STEPS.size() - 1)
		await process_frame
		await _capture(locale + "-tutorial", _main.tutorial)
		_main.tutorial.close_button.pressed.emit()
	SsokLocale.select_locale("ko", false)
	_main.mode_button.button_pressed = true
	root.gui_release_focus()
	var motion: HumanoidMotion = _main.motion_program
	_check(motion.is_supported() and _main.manual_controller.is_enabled(), "Run arms humanoid program")
	for frame: int in range(180):
		await physics_frame
	await _key(KEY_E, true)
	await _key(KEY_E, false)
	_check(motion.pickup_state == "reaching", "viewport E requests contact-based pickup")
	for frame: int in range(390):
		await physics_frame
	_check(motion.grasped and motion.pickup_state == "holding", "application reaches and lifts real box")
	for locale: String in ["ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(locale, false)
		await process_frame
		await process_frame
		await _capture(locale + "-holding")
	_main.tutorial_button.pressed.emit()
	_check(not motion.grasped and motion._grips.is_empty(), "opening tutorial releases physical grasp")
	_check(not _main.manual_controller.is_enabled(), "modal guide stops input")
	_main.tutorial.close_button.pressed.emit()
	_check(not _main.manual_controller.is_enabled(), "closing tutorial does not silently resume")
	_main.mode_button.button_pressed = false
	_check(not _main.run_mode.is_built(), "edit mode tears down physics")
	_main.biped_button.pressed.emit()
	_check(_main.motion_program is BipedMotion and not _main.motion_lab_button.disabled, "original biped and AI remain available")
	_main.free()
	await process_frame
	print("humanoid_ui_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _capture(name: String, viewport: Viewport = null) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://humanoid_previews")
	var target: Viewport = root if viewport == null else viewport
	var prefix: String = "modular-" if "--modular" in OS.get_cmdline_user_args() else ""
	_check(target.get_texture().get_image().save_png("user://humanoid_previews/" + prefix + name + ".png") == OK, "capture " + prefix + name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
