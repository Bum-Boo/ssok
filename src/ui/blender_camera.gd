class_name BlenderCamera
extends Node

## Blender-style viewport navigation without capturing the pointer.

@export var orbit_sensitivity: float = 0.006
@export var zoom_sensitivity: float = 0.01
@export var zoom_step: float = 0.15
@export var min_distance: float = 0.005
@export var max_distance: float = 20.0

var navigation_enabled: bool = true:
	set(value):
		navigation_enabled = value
		if not value:
			_stop_navigation()
var bounds_provider: Callable
var scene_bounds_provider: Callable
var framing_rect_provider: Callable
var pivot: Vector3 = Vector3(0.05, 0.09, 0.0)

var _camera: Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance: float = 0.3
var _navigating: bool = false
var _axis_view: bool = false
var _framed_bounds: AABB
var _has_framed_bounds: bool = false
var _previous_viewport: Rect2
var _previous_framing_rect: Rect2


func _init(camera: Camera3D) -> void:
	_camera = camera


func _ready() -> void:
	_camera.near = minf(_camera.near, 0.001)
	sync_from_camera()
	get_window().focus_exited.connect(_stop_navigation)
	_previous_viewport = _camera.get_viewport().get_visible_rect()
	_previous_framing_rect = _framing_rect()
	get_viewport().size_changed.connect(func() -> void: _resize_view.call_deferred())


func sync_from_camera() -> void:
	var offset: Vector3 = _camera.global_position - pivot
	_distance = clampf(offset.length(), min_distance, max_distance)
	if not offset.is_zero_approx():
		_yaw = atan2(offset.x, offset.z)
		_pitch = asin(clampf(offset.normalized().y, -1.0, 1.0))
	_axis_view = false


func is_navigating() -> bool:
	return _navigating


func track_displacement(displacement: Vector3) -> void:
	if not displacement.is_finite():
		return
	pivot += displacement
	_apply_view()


func frame_bounds(bounds: AABB) -> void:
	if not bounds.position.is_finite() or not bounds.size.is_finite():
		return
	pivot = bounds.get_center()
	var viewport_rect: Rect2 = _camera.get_viewport().get_visible_rect()
	var framing_rect: Rect2 = _framing_rect()
	var fit: Vector2 = _fit_bounds(bounds, viewport_rect, framing_rect)
	_distance = fit.x
	_camera.size = fit.y
	_framed_bounds = bounds
	_has_framed_bounds = true
	_previous_viewport = viewport_rect
	_previous_framing_rect = framing_rect
	_apply_view()


func _fit_bounds(bounds: AABB, viewport_rect: Rect2, framing_rect: Rect2) -> Vector2:
	if framing_rect != viewport_rect:
		return _fit_in_rect(bounds, viewport_rect, framing_rect)
	var radius: float = maxf(bounds.size.length() * 0.5, min_distance)
	var aspect: float = viewport_rect.size.x / maxf(viewport_rect.size.y, 1.0)
	var tangent: float = tan(deg_to_rad(_camera.fov) * 0.5)
	var narrow_tangent: float = tangent * minf(1.0, aspect)
	if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
		narrow_tangent = tangent * minf(1.0, 1.0 / aspect)
	var distance: float = clampf(radius * 1.2 / sin(atan(narrow_tangent)), min_distance, max_distance)
	var view_size: float = radius * 2.4 * maxf(1.0, 1.0 / aspect)
	if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
		view_size = radius * 2.4 * maxf(1.0, aspect)
	return Vector2(distance, view_size)


func _fit_in_rect(bounds: AABB, viewport_rect: Rect2, framing_rect: Rect2) -> Vector2:
	var target: Rect2 = framing_rect.grow_individual(-framing_rect.size.x * 0.08,
		-framing_rect.size.y * 0.08, -framing_rect.size.x * 0.08, -framing_rect.size.y * 0.08)
	var low: Vector2 = (target.position - viewport_rect.position) / viewport_rect.size * 2.0 - Vector2.ONE
	var high: Vector2 = (target.end - viewport_rect.position) / viewport_rect.size * 2.0 - Vector2.ONE
	var center: Vector2 = (framing_rect.get_center() - viewport_rect.position) / viewport_rect.size * 2.0 - Vector2.ONE
	var bottom: float = -high.y
	var top: float = -low.y
	center.y = -center.y
	var tangent: float = tan(deg_to_rad(_camera.fov) * 0.5)
	var aspect: float = viewport_rect.size.x / maxf(viewport_rect.size.y, 1.0)
	var tangents: Vector2 = Vector2(tangent * aspect, tangent)
	if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
		tangents = Vector2(tangent, tangent / aspect)
	var view_basis: Basis = Basis.from_euler(Vector3(-_pitch, _yaw, 0.0))
	var required_distance: float = min_distance
	var required_height: float = min_distance
	for index: int in 8:
		var local: Vector3 = view_basis.inverse() * (bounds.get_endpoint(index) - bounds.get_center())
		# Solve the four projection edges, including depth and the off-centre view.
		required_distance = maxf(required_distance, local.z + _camera.near * 2.0)
		required_distance = maxf(required_distance, (-local.x - low.x * local.z * tangents.x) / ((center.x - low.x) * tangents.x))
		required_distance = maxf(required_distance, (local.x + high.x * local.z * tangents.x) / ((high.x - center.x) * tangents.x))
		required_distance = maxf(required_distance, (-local.y - bottom * local.z * tangents.y) / ((center.y - bottom) * tangents.y))
		required_distance = maxf(required_distance, (local.y + top * local.z * tangents.y) / ((top - center.y) * tangents.y))
		required_height = maxf(required_height, absf(local.x) * 2.0 * viewport_rect.size.x / (target.size.x * aspect))
		required_height = maxf(required_height, absf(local.y) * 2.0 * viewport_rect.size.y / target.size.y)
	return Vector2(clampf(required_distance, min_distance, max_distance),
		required_height * (aspect if _camera.keep_aspect == Camera3D.KEEP_WIDTH else 1.0))


func _resize_view() -> void:
	var viewport_rect: Rect2 = _camera.get_viewport().get_visible_rect()
	var framing_rect: Rect2 = _framing_rect()
	if _has_framed_bounds:
		var previous: Vector2 = _fit_bounds(_framed_bounds, _previous_viewport, _previous_framing_rect)
		var current: Vector2 = _fit_bounds(_framed_bounds, viewport_rect, framing_rect)
		# Keep the learner's pan, orbit and zoom relative to the available framing area.
		_distance = clampf(_distance * current.x / previous.x, min_distance, max_distance)
		_camera.size *= current.y / previous.y
	_previous_viewport = viewport_rect
	_previous_framing_rect = framing_rect
	_apply_view()


func _input(event: InputEvent) -> void:
	# Releases must reach us even when a panel consumes the end of a viewport drag.
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_MIDDLE and not button.pressed:
			_stop_navigation()


func _unhandled_input(event: InputEvent) -> void:
	if not navigation_enabled:
		return
	var handled: bool = false
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_MIDDLE:
				_navigating = button.pressed
				if button.pressed:
					get_viewport().gui_release_focus()
				handled = true
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed and get_viewport().gui_get_hovered_control() == null:
					var direction: float = -1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
					_zoom(direction * zoom_step * maxf(button.factor, 1.0))
					handled = true
	elif event is InputEventMouseMotion and _navigating:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.shift_pressed:
			_pan(motion.relative)
		elif motion.ctrl_pressed:
			_zoom(motion.relative.y * zoom_sensitivity)
		else:
			_orbit(motion.relative)
		handled = true
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and get_viewport().gui_get_focus_owner() == null:
			handled = _handle_key(key)
	if handled:
		get_viewport().set_input_as_handled()


func _handle_key(event: InputEventKey) -> bool:
	if event.alt_pressed or event.meta_pressed or event.shift_pressed:
		return false
	var key: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	match key:
		KEY_KP_1:
			_set_axis_view(PI if event.ctrl_pressed else 0.0, 0.0)
		KEY_KP_3:
			_set_axis_view(-PI * 0.5 if event.ctrl_pressed else PI * 0.5, 0.0)
		KEY_KP_7:
			_set_axis_view(0.0, -PI * 0.5 if event.ctrl_pressed else PI * 0.5)
		KEY_KP_5:
			if event.ctrl_pressed:
				return false
			_toggle_projection()
			_axis_view = false
		KEY_KP_PERIOD:
			if event.ctrl_pressed:
				return false
			_frame_from_provider(bounds_provider)
		KEY_HOME:
			if event.ctrl_pressed:
				return false
			_frame_from_provider(scene_bounds_provider if scene_bounds_provider.is_valid() else bounds_provider)
		_:
			return false
	return true


func _orbit(relative: Vector2) -> void:
	if relative.is_zero_approx():
		return
	if _axis_view and _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_toggle_projection()
	_axis_view = false
	_yaw -= relative.x * orbit_sensitivity
	_pitch = clampf(_pitch + relative.y * orbit_sensitivity, -PI * 0.5 + 0.001, PI * 0.5 - 0.001)
	_apply_view()


func _pan(relative: Vector2) -> void:
	var height: float = _camera.size
	if _camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		height = 2.0 * _distance * tan(deg_to_rad(_camera.fov) * 0.5)
	if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
		height /= _viewport_aspect()
	var pixels: float = maxf(_camera.get_viewport().get_visible_rect().size.y, 1.0)
	var basis: Basis = _camera.global_basis
	pivot += (-basis.x * relative.x + basis.y * relative.y) * height / pixels
	_apply_view()


func _zoom(amount: float) -> void:
	var factor: float = exp(clampf(amount, -2.0, 2.0))
	_distance = clampf(_distance * factor, min_distance, max_distance)
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.size = clampf(_camera.size * factor, min_distance, max_distance)
	_apply_view()


func _set_axis_view(yaw: float, pitch: float) -> void:
	if _camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		_toggle_projection()
	_yaw = yaw
	_pitch = pitch
	_axis_view = true
	_apply_view()


func _toggle_projection() -> void:
	var tangent: float = tan(deg_to_rad(_camera.fov) * 0.5)
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_distance = clampf(_camera.size / (2.0 * tangent), min_distance, max_distance)
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	else:
		_camera.size = 2.0 * _distance * tangent
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_apply_view()


func _apply_view() -> void:
	var basis: Basis = Basis.from_euler(Vector3(-_pitch, _yaw, 0.0))
	_camera.global_transform = Transform3D(basis, pivot + basis.z * _distance)
	var viewport_rect: Rect2 = _camera.get_viewport().get_visible_rect()
	var offset: Vector2 = _framing_rect().get_center() - viewport_rect.get_center()
	var height: float = _camera.size
	if _camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		height = 2.0 * _distance * tan(deg_to_rad(_camera.fov) * 0.5)
	if _camera.keep_aspect == Camera3D.KEEP_WIDTH:
		height /= _viewport_aspect()
	_camera.h_offset = -offset.x * height / maxf(viewport_rect.size.y, 1.0)
	_camera.v_offset = offset.y * height / maxf(viewport_rect.size.y, 1.0)


func _framing_rect() -> Rect2:
	var viewport_rect: Rect2 = _camera.get_viewport().get_visible_rect()
	if framing_rect_provider.is_valid():
		var result: Variant = framing_rect_provider.call()
		if result is Rect2 and result.position.is_finite() and result.size.is_finite():
			var clipped: Rect2 = viewport_rect.intersection(result)
			if clipped.size.x >= 2.0 and clipped.size.y >= 2.0:
				return clipped
	return viewport_rect


func _frame_from_provider(provider: Callable) -> void:
	if not provider.is_valid():
		return
	var result: Variant = provider.call()
	if result is AABB:
		frame_bounds(result as AABB)


func _viewport_aspect() -> float:
	var size: Vector2 = _camera.get_viewport().get_visible_rect().size
	return maxf(size.x, 1.0) / maxf(size.y, 1.0)


func _stop_navigation() -> void:
	_navigating = false
