class_name ManualController
extends Node

## Keyboard/gamepad input is a robot-level command, not a direct joint or body edit.

signal movement_changed(throttle: float, turn: float)
signal stop_requested
signal state_changed
signal sprint_changed(pressed: bool)
signal interaction_requested

@export_range(0.0, 0.95) var stick_deadzone: float = 0.18

var _hardware: RunMode
var _has_hardware: bool = false
var _enabled: bool = false
var _focused: bool = true
var _held_keys: Dictionary = {}
var _active_gamepad: int = -1
var _stick: Vector2 = Vector2.ZERO
var _stick_raw: Vector2 = Vector2.ZERO
var _stick_needs_neutral: bool = false
var _move_input: Vector2 = Vector2.ZERO
var _sprinting: bool = false


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func configure(hardware: RunMode = null) -> void:
	set_enabled(false)
	_hardware = hardware
	_has_hardware = hardware != null
	_active_gamepad = -1
	_stick_raw = Vector2.ZERO
	_clear_inputs(false)
	state_changed.emit()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled and (not _has_hardware or (is_instance_valid(_hardware) and _hardware.is_built()))
	_clear_inputs(false)
	if _active_gamepad >= 0:
		_stick_raw = Vector2(Input.get_joy_axis(_active_gamepad, JOY_AXIS_LEFT_X), Input.get_joy_axis(_active_gamepad, JOY_AXIS_LEFT_Y))
		_stick_needs_neutral = _stick_raw.length() > stick_deadzone
	state_changed.emit()


func is_enabled() -> bool:
	return _enabled


## x = right turn, y = forward; keyboard diagonals have the same unit limit as a stick.
func get_move_input() -> Vector2:
	return _move_input


func get_active_gamepad() -> int:
	return _active_gamepad


func brake() -> void:
	if not _enabled:
		return
	_clear_inputs(true)
	stop_requested.emit()


func advance(_delta: float) -> void:
	if not _enabled:
		return
	if _has_hardware and (not is_instance_valid(_hardware) or not _hardware.is_built()):
		set_enabled(false)
		return
	if not _focused or _text_has_focus():
		_clear_inputs(true)
		return
	var left := _held_keys.has(KEY_A) or _held_keys.has(KEY_LEFT)
	var right := _held_keys.has(KEY_D) or _held_keys.has(KEY_RIGHT)
	var forward := _held_keys.has(KEY_W) or _held_keys.has(KEY_UP)
	var backward := _held_keys.has(KEY_S) or _held_keys.has(KEY_DOWN)
	var keyboard := Vector2(float(right) - float(left), float(forward) - float(backward))
	_publish_input((keyboard + _stick).limit_length())


## Event-based presses prevent GUI-consumed keys from leaking into robot control.
func handle_event(event: InputEvent) -> bool:
	if event is InputEventKey and not event.pressed:
		_held_keys.erase(_key_code(event))
		if _key_code(event) == KEY_SHIFT:
			_set_sprinting(false)
		advance(0.0)
		return false
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if _active_gamepad >= 0 and event.device != _active_gamepad:
			return false
		_stick_raw.x = event.axis_value if event.axis == JOY_AXIS_LEFT_X else _stick_raw.x
		_stick_raw.y = event.axis_value if event.axis == JOY_AXIS_LEFT_Y else _stick_raw.y
	if not _enabled or not _focused:
		return false
	if _text_has_focus():
		_clear_inputs(true)
		return false
	if event is InputEventKey:
		if event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			return false
		var code := _key_code(event)
		if code == KEY_SHIFT:
			_set_sprinting(true)
			return true
		if code == KEY_E:
			interaction_requested.emit()
			return true
		if code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			_held_keys[code] = true
			advance(0.0)
			return true
		if code == KEY_SPACE:
			brake()
			return true
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if _stick_raw.length() <= stick_deadzone:
			_stick_needs_neutral = false
			_stick = Vector2.ZERO
		elif _stick_needs_neutral:
			return true
		else:
			_claim_gamepad(event.device)
			var strength := clampf((_stick_raw.length() - stick_deadzone) / (1.0 - stick_deadzone), 0.0, 1.0)
			_stick = Vector2(_stick_raw.x, -_stick_raw.y).normalized() * strength
		advance(0.0)
		return true
	elif event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]:
		if _active_gamepad >= 0 and event.device != _active_gamepad:
			return false
		if event.button_index == JOY_BUTTON_B:
			_claim_gamepad(event.device)
			_set_sprinting(event.pressed)
			return true
		if event.pressed:
			_claim_gamepad(event.device)
			if event.button_index == JOY_BUTTON_X:
				interaction_requested.emit()
			else:
				brake()
		return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		handle_event(event)
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if handle_event(event):
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and handle_event(event):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	advance(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_clear_inputs(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == _active_gamepad:
		_active_gamepad = -1
		_stick_raw = Vector2.ZERO
		_clear_inputs(true)
	state_changed.emit()


func _claim_gamepad(device: int) -> void:
	if _active_gamepad != device:
		_active_gamepad = device
		state_changed.emit()


func _clear_inputs(require_neutral: bool) -> void:
	_held_keys.clear()
	_set_sprinting(false)
	_stick = Vector2.ZERO
	_stick_needs_neutral = require_neutral
	_publish_input(Vector2.ZERO)


func _set_sprinting(pressed: bool) -> void:
	if _sprinting != pressed:
		_sprinting = pressed
		sprint_changed.emit(pressed)


func _publish_input(value: Vector2) -> void:
	if _move_input.is_equal_approx(value):
		return
	_move_input = value
	movement_changed.emit(value.y, value.x)
	state_changed.emit()


func _text_has_focus() -> bool:
	if not is_inside_tree():
		return false
	var focus := get_viewport().gui_get_focus_owner()
	return focus != null


static func _key_code(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != 0 else event.keycode
