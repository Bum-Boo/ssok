class_name FlyCamera
extends Node

## Minecraft-style look/fly for the prototype camera: hold the right mouse
## button to capture the cursor and look around, WASD to move on the yaw plane,
## Space/Shift for up/down, Ctrl to sprint, wheel to dolly. Left-button part
## dragging keeps working because nothing here touches that button.

@export var move_speed := 0.25
@export var sprint_multiplier := 3.0
@export var look_sensitivity := 0.0025
@export var dolly_step := 0.02
@export var min_height := 0.005

var _camera: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _flying := false


func _init(camera: Camera3D) -> void:
	_camera = camera


func _ready() -> void:
	sync_from_camera()


## Call after moving the camera from code so look-around continues from there.
func sync_from_camera() -> void:
	var euler := _camera.global_transform.basis.get_euler()
	_pitch = euler.x
	_yaw = euler.y


func is_flying() -> bool:
	return _flying


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_RIGHT:
				_set_flying(button.pressed)
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_dolly(dolly_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_dolly(-dolly_step)
	elif event is InputEventMouseMotion and _flying:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * look_sensitivity
		_pitch = clampf(_pitch - motion.relative.y * look_sensitivity, -PI / 2.0 + 0.01, PI / 2.0 - 0.01)
		_camera.global_transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))


func _process(delta: float) -> void:
	if not _flying:
		return
	var basis := _camera.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()

	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		direction += forward
	if Input.is_physical_key_pressed(KEY_S):
		direction -= forward
	if Input.is_physical_key_pressed(KEY_D):
		direction += right
	if Input.is_physical_key_pressed(KEY_A):
		direction -= right
	if Input.is_physical_key_pressed(KEY_SPACE):
		direction += Vector3.UP
	if Input.is_physical_key_pressed(KEY_SHIFT):
		direction -= Vector3.UP
	if direction.is_zero_approx():
		return

	var speed := move_speed * (sprint_multiplier if Input.is_physical_key_pressed(KEY_CTRL) else 1.0)
	var position := _camera.global_position + direction.normalized() * speed * delta
	position.y = maxf(position.y, min_height)
	_camera.global_position = position


func _set_flying(flying: bool) -> void:
	if flying == _flying:
		return
	_flying = flying
	if flying:
		get_viewport().gui_release_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _dolly(distance: float) -> void:
	var position := _camera.global_position - _camera.global_transform.basis.z * distance
	position.y = maxf(position.y, min_height)
	_camera.global_position = position
