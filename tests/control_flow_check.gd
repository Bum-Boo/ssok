extends SceneTree

var _failures: Array[String] = []
var _main: Node3D
var _finished_count: int = 0
var _runtime_errors: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 900)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	_main.runtime.finished.connect(func() -> void: _finished_count += 1)
	_main.runtime.failed.connect(func(_line: int, message: String) -> void: _runtime_errors.append(message))
	_main.answer_button.pressed.emit()
	_main.control_source.select(_main.CONTROL_CODE)
	_main.mode_button.button_pressed = true
	_check(not _main.manual_controller.is_enabled(), "code mode excludes movement inputs")
	var drive: ServoDrive = _main.run_mode.servo_on_pin(9)
	_main.runtime.run("arm = Servo(9)\narm.write(10)\nsleep(0.15)\narm.write(90)")
	_check(_main.runtime.is_running() and drive.target_deg == 10.0, "learner program is sleeping after its first command")
	_main.control_source.select(_main.CONTROL_MANUAL)
	_main.control_source.item_selected.emit(_main.CONTROL_MANUAL)
	_check(not _main.runtime.is_running(), "changing command source stops the sleeping program")
	await create_timer(0.2).timeout
	_check(drive.target_deg == 10.0 and _finished_count == 0, "cancelled sleep cannot send a stale motor command or finish event")

	_main.runtime.run("arm = Servo(9)\nsleep(0.1)\narm.write(100)")
	_main.runtime.stop()
	_main.runtime.run("arm = Servo(9)\nsleep(0.3)\narm.write(20)")
	await create_timer(0.15).timeout
	_check(_main.runtime.is_running() and drive.target_deg == 10.0, "older cancellation cannot clear a newer program's state")
	await create_timer(0.2).timeout
	_check(not _main.runtime.is_running() and drive.target_deg == 20.0 and _finished_count == 1, "only the newer program finishes")

	_main.runtime.run("arm = Servo(9)\nsleep(0.1)\narm.write(120)")
	_main.mode_button.button_pressed = false
	_check(not _main.runtime.is_running() and not _main.run_mode.is_built(), "returning to edit stops code before tearing down physics")
	await create_timer(0.15).timeout
	_check(_runtime_errors.is_empty(), "no stale coroutine accesses removed servo drives")

	_main.biped_button.pressed.emit()
	_main.control_source.select(_main.CONTROL_MANUAL)
	_main.mode_button.button_pressed = true
	_check(_main.motion_program.is_supported() and _main.manual_controller.is_enabled(), "biped run mode connects whole-robot movement program")
	root.gui_release_focus()
	await _key(KEY_W, true)
	_check(_main.manual_controller.get_move_input().y > 0.0, "viewport W dispatches a forward command")
	await _key(KEY_W, false)
	_check(_main.manual_controller.get_move_input().is_zero_approx(), "key release dispatches stop")
	_main.program_tabs.current_tab = 0
	_main.code_edit.grab_focus()
	await _key(KEY_W, true)
	_check(_main.manual_controller.get_move_input().is_zero_approx(), "typing W in the code editor does not move the robot")
	await _key(KEY_W, false)
	await _click_viewport()
	_check(not _main.code_edit.has_focus(), "clicking the run viewport returns keyboard control from the code editor")
	await _key(KEY_S, true)
	_check(_main.manual_controller.get_move_input().y < 0.0, "viewport S dispatches backward after leaving the editor")
	await _key(KEY_S, false)
	_main.code_edit.text = "left = Servo(5)\nleft.write(0)\nsleep(0.2)\nleft.write(10)"
	_main.run_button.pressed.emit()
	_check(not _main.manual_controller.is_enabled() and _main.runtime.is_running(), "Run code hands ownership away from WASD")
	_main.stop_button.pressed.emit()
	_check(not _main.runtime.is_running() and not _main.manual_controller.is_enabled(), "Stop cancels both input sources")
	await create_timer(0.25).timeout
	_main.mode_button.button_pressed = false
	_check(_main.assembly.process_mode != Node.PROCESS_MODE_DISABLED, "edit controls are restored after run mode")
	_check(_runtime_errors.is_empty(), "complete input/code lifecycle has no runtime errors")
	_main.free()
	await process_frame
	print("control_flow_check: %d failure(s)" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _click_viewport() -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(640, 500)
	root.push_input(motion, true)
	await process_frame
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.position = motion.position
	button.pressed = true
	root.push_input(button, true)
	await process_frame
	button.pressed = false
	root.push_input(button, true)
	await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.unicode = int(code) if pressed else 0
	root.push_input(event, true)
	await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failures.append(message)
