extends SceneTree

var _hardware: RunMode
var _manual: ManualController
var _failures: Array[String] = []
var _last_command: Vector2 = Vector2.ZERO
var _stop_count: int = 0


func _init() -> void:
	_setup.call_deferred()


func _setup() -> void:
	_hardware = RunMode.new()
	root.add_child(_hardware)
	_manual = ManualController.new()
	root.add_child(_manual)
	_manual.set_physics_process(false)
	_manual.movement_changed.connect(func(throttle: float, turn: float) -> void: _last_command = Vector2(turn, throttle))
	_manual.stop_requested.connect(func() -> void: _stop_count += 1)
	_test_wiring()
	_test_keyboard()
	_test_gamepad()
	_test_dispatch()
	_test_focus()
	_hardware.teardown()
	_manual.advance(0.1)
	_check(_manual.get_move_input() == Vector2.ZERO, "leaving manual mode stops command output")
	_check(not _manual.is_enabled(), "hardware teardown disables stale manual input")
	print("manual_control_check: %d failure(s)" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _test_wiring() -> void:
	var graph := ServoArmPreset.build()
	graph.links[2].b_port = &"pin_10"
	_hardware.build(graph)
	_manual.configure(_hardware)
	_check(not _manual.is_enabled(), "configuration leaves manual input disabled")
	var channels := _hardware.wired_servo_channels()
	_check(channels.size() == 1 and channels[0].pin == 10, "hardware discovery follows graph pin 10, not preset pin 9")
	_check(channels[0].board_part == 3 and channels[0].part == 1, "channel identifies actual graph board and servo")
	_check("D10" in channels[0].label, "visible channel label identifies its wired pin")
	_manual.set_enabled(true)
	_manual.handle_event(_key(KEY_W))
	_manual.advance(1.0)
	_check(not _hardware.servo_on_pin(10).powered, "input adapter never writes servo joints directly")
	_manual.set_enabled(false)
	graph = ServoArmPreset.build()
	graph.links.remove_at(2)
	_hardware.build(graph)
	_manual.configure(_hardware)
	_check(_hardware.wired_servo_channels().is_empty(), "unwired servo is excluded from hardware discovery")
	graph = ServoArmPreset.build()
	var second := ServoArmPreset.build()
	var offset := graph.parts.size()
	for entry: Dictionary in second.parts:
		entry.transform.origin.x += 0.3
		graph.parts.append(entry)
	for link: Dictionary in second.links:
		link.a_part += offset
		link.b_part += offset
		graph.links.append(link)
	_hardware.build(graph)
	_manual.configure(_hardware)
	_check(_hardware.wired_servo_channels().is_empty(), "ambiguous numeric addresses never pick an arbitrary board")
	_hardware.build(BipedPreset.build())
	_manual.configure(_hardware)
	var pins: Array[int] = []
	for channel: Dictionary in _hardware.wired_servo_channels():
		pins.append(channel.pin)
	_check(pins == [3, 5, 6, 9], "biped hardware discovery is sorted by actual wiring")
	_manual.set_enabled(true)


func _test_keyboard() -> void:
	_manual.handle_event(_key(KEY_W))
	_check(_input_is(Vector2(0, 1)), "W requests forward motion")
	_check(_last_command == Vector2(0, 1), "motion signal delivers throttle before turn")
	_manual.handle_event(_key(KEY_D))
	_check(_manual.get_move_input().length() <= 1.0 and _input_is(Vector2(1, 1).normalized()), "W+D requests a bounded forward/right arc")
	_manual.handle_event(_key(KEY_W, false))
	_check(_input_is(Vector2(1, 0)), "D alone requests a right turn")
	_manual.handle_event(_key(KEY_D, false))
	_check(_input_is(Vector2.ZERO), "releasing movement keys stops motion")
	_manual.handle_event(_key(KEY_S))
	_check(_input_is(Vector2(0, -1)), "S requests reverse motion")
	_manual.handle_event(_key(KEY_W))
	_check(_input_is(Vector2.ZERO), "opposite throttle keys cancel")
	_manual.handle_event(_key(KEY_S, false))
	_manual.handle_event(_key(KEY_W, false))
	_manual.handle_event(_key(KEY_A))
	_check(_input_is(Vector2(-1, 0)), "A requests a left turn")
	_manual.handle_event(_key(KEY_SPACE))
	_check(_input_is(Vector2.ZERO) and _stop_count == 1, "Space clears motion and sends an explicit brake command")
	_manual.advance(1.0)
	_check(_input_is(Vector2.ZERO), "brake never resumes a previously held direction")
	_manual.handle_event(_key(KEY_UP))
	_check(_input_is(Vector2(0, 1)), "arrow keys share robot motion semantics")
	_manual.set_enabled(false)
	_manual.handle_event(_key(KEY_D))
	_manual.advance(1.0)
	_check(_input_is(Vector2.ZERO), "disabled adapter cannot send movement")
	_manual.set_enabled(true)
	_manual.advance(1.0)
	_check(_input_is(Vector2.ZERO), "reenabling never resumes previous held keys")
	var shortcut := _key(KEY_D)
	shortcut.ctrl_pressed = true
	_check(not _manual.handle_event(shortcut), "editor or OS shortcuts do not issue movement")
	_manual.handle_event(_key(KEY_W))
	_manual.advance(1.0 / 120.0)
	var fast := _manual.get_move_input()
	_manual.advance(1.0 / 30.0)
	_check(fast == _manual.get_move_input(), "robot command strength is independent of input frame rate")
	_manual.handle_event(_key(KEY_W, false))


func _test_gamepad() -> void:
	_manual.handle_event(_motion(2, JOY_AXIS_LEFT_X, 0.1))
	_check(_input_is(Vector2.ZERO), "gamepad deadzone rejects resting-stick noise")
	_manual.handle_event(_motion(2, JOY_AXIS_LEFT_X, 0.59))
	_check(_input_is(Vector2(0.5, 0)), "gamepad half-range beyond deadzone gives half turn command")
	_check(_manual.get_active_gamepad() == 2, "first active controller owns gamepad input")
	_manual.handle_event(_motion(3, JOY_AXIS_LEFT_X, -1.0))
	_check(_input_is(Vector2(0.5, 0)), "another controller cannot overwrite the active stick")
	_manual.handle_event(_motion(2, JOY_AXIS_LEFT_X, 0.0))
	_manual.handle_event(_motion(2, JOY_AXIS_LEFT_Y, -1.0))
	_check(_input_is(Vector2(0, 1)), "pushing gamepad stick up requests forward motion")
	_manual.handle_event(_motion(2, JOY_AXIS_LEFT_X, 1.0))
	_check(_input_is(Vector2(1, 1).normalized()), "gamepad diagonal movement is clamped to unit length")
	_manual.handle_event(_button(2, JOY_BUTTON_A))
	_check(_input_is(Vector2.ZERO) and _stop_count == 2, "gamepad A brakes robot motion")
	_manual.handle_event(_motion(2, JOY_AXIS_LEFT_X, 0.0))
	_manual.handle_event(_motion(2, JOY_AXIS_LEFT_Y, -0.9))
	_check(_input_is(Vector2.ZERO), "brake requires both stick axes to return to neutral")
	_manual.handle_event(_motion(2, JOY_AXIS_LEFT_Y, 0.0))
	_manual.handle_event(_motion(2, JOY_AXIS_LEFT_Y, 1.0))
	_check(_input_is(Vector2(0, -1)), "pulling stick down requests reverse motion")
	Input.joy_connection_changed.emit(2, false)
	_check(_input_is(Vector2.ZERO) and _manual.get_active_gamepad() == -1, "hot unplug clears motion and controller ownership")
	_manual.handle_event(_motion(3, JOY_AXIS_LEFT_Y, -1.0))
	_check(_input_is(Vector2.ZERO), "replacement controller must neutralize after hot unplug")
	_manual.handle_event(_motion(3, JOY_AXIS_LEFT_Y, 0.0))
	_manual.handle_event(_motion(3, JOY_AXIS_LEFT_Y, -1.0))
	_check(_input_is(Vector2(0, 1)) and _manual.get_active_gamepad() == 3, "replacement controller works after neutral rearm")
	_manual.handle_event(_motion(3, JOY_AXIS_LEFT_Y, 0.0))


func _test_dispatch() -> void:
	root.push_input(_key(KEY_W))
	_check(_input_is(Vector2(0, 1)), "actual viewport dispatch routes unhandled W to robot motion")
	var editor := TextEdit.new()
	root.add_child(editor)
	editor.grab_focus()
	root.push_input(_key(KEY_W, false))
	_check(_input_is(Vector2.ZERO), "input release is cleared even when a text editor consumes events")
	root.push_input(_key(KEY_W))
	_check(_input_is(Vector2.ZERO), "actual GUI dispatch never leaks typed W into movement")
	root.push_input(_key(KEY_W, false))
	editor.release_focus()
	editor.queue_free()


func _test_focus() -> void:
	_manual.handle_event(_key(KEY_W))
	var editor := TextEdit.new()
	root.add_child(editor)
	editor.grab_focus()
	_check(root.gui_get_focus_owner() == editor, "test text editor actually owns GUI focus")
	_manual.advance(1.0)
	_check(_input_is(Vector2.ZERO), "text focus clears already held movement")
	_check(not _manual.handle_event(_key(KEY_W)), "typing a movement key does not control the robot")
	_check(not _manual.handle_event(_motion(3, JOY_AXIS_LEFT_Y, -1.0)), "text focus blocks gamepad movement too")
	editor.release_focus()
	_manual.advance(1.0)
	_check(_input_is(Vector2.ZERO), "closing text editor never resumes stale movement")
	var repeat := _key(KEY_W)
	repeat.echo = true
	_manual.handle_event(repeat)
	_check(_input_is(Vector2.ZERO), "key autorepeat cannot revive movement after text focus")
	_manual.handle_event(_motion(3, JOY_AXIS_LEFT_Y, -1.0))
	_check(_input_is(Vector2.ZERO), "held stick must return to neutral after text focus")
	_manual.handle_event(_motion(3, JOY_AXIS_LEFT_Y, 0.0))
	_manual.handle_event(_motion(3, JOY_AXIS_LEFT_Y, -1.0))
	_check(_input_is(Vector2(0, 1)), "fresh neutralized stick works after text focus")
	_manual.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(_input_is(Vector2.ZERO), "application focus loss stops manual motion")
	_manual.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_manual.advance(1.0)
	_check(_input_is(Vector2.ZERO), "application focus regain never resumes stale input")
	editor.queue_free()


func _input_is(expected: Vector2) -> bool:
	return _manual.get_move_input().is_equal_approx(expected)


static func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event


static func _motion(device: int, axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	return event


static func _button(device: int, button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	return event


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures.append(what)
