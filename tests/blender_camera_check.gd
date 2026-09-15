extends SceneTree

var _failed: bool = false
var _camera: Camera3D
var _navigation: BlenderCamera
var _editor: CodeEdit
var _selected_bounds: AABB = AABB(Vector3(-0.01, 0.02, -0.03), Vector3(0.04, 0.08, 0.06))
var _scene_bounds: AABB = AABB(Vector3(-0.3, 0.0, -0.2), Vector3(0.6, 0.5, 0.4))


func _initialize() -> void:
	call_deferred(&"_run_check")


func _run_check() -> void:
	root.size = Vector2i(1280, 720)
	_camera = Camera3D.new()
	root.add_child(_camera)
	_camera.look_at_from_position(Vector3(0.2, 0.18, 0.26), Vector3(0.05, 0.09, 0.0))
	_navigation = BlenderCamera.new(_camera)
	_navigation.bounds_provider = func() -> AABB: return _selected_bounds
	_navigation.scene_bounds_provider = func() -> AABB: return _scene_bounds
	root.add_child(_navigation)
	_editor = CodeEdit.new()
	_editor.position = Vector2(900, 0)
	_editor.size = Vector2(380, 720)
	root.add_child(_editor)
	await process_frame
	_check_mouse_navigation()
	_check_views_and_framing()
	_check_focus_and_modal_guards()
	print("blender_camera_check: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _check_mouse_navigation() -> void:
	var original: Transform3D = _camera.global_transform
	var pivot_before: Vector3 = _navigation.pivot
	var distance_before: float = _camera.global_position.distance_to(pivot_before)
	_mouse_button(MOUSE_BUTTON_MIDDLE, true)
	_mouse_motion(Vector2(38.0, -21.0))
	_assert(not _camera.global_basis.is_equal_approx(original.basis), "MMB orbit must rotate camera")
	_assert(_navigation.pivot.is_equal_approx(pivot_before), "orbit must preserve pivot")
	_assert(is_equal_approx(_camera.global_position.distance_to(pivot_before), distance_before), "orbit must preserve distance")
	_assert(_camera.global_basis.z.dot((_camera.global_position - pivot_before).normalized()) > 0.999, "orbit must look at pivot")
	_assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "navigation must not capture the pointer")
	var basis_before: Basis = _camera.global_basis
	_mouse_motion(Vector2(30.0, -12.0), true)
	_assert(not _navigation.pivot.is_equal_approx(pivot_before), "Shift+MMB must pan pivot")
	_assert(_camera.global_basis.is_equal_approx(basis_before), "pan must preserve orientation")
	distance_before = _camera.global_position.distance_to(_navigation.pivot)
	_mouse_motion(Vector2(0.0, -20.0), false, true)
	_assert(_camera.global_position.distance_to(_navigation.pivot) < distance_before, "Ctrl+MMB must zoom")
	_mouse_button(MOUSE_BUTTON_MIDDLE, false)
	_assert(not _navigation.is_navigating(), "MMB release must end navigation")
	distance_before = _camera.global_position.distance_to(_navigation.pivot)
	_mouse_button(MOUSE_BUTTON_WHEEL_UP, true)
	_assert(_camera.global_position.distance_to(_navigation.pivot) < distance_before, "wheel up must zoom in")
	_mouse_button(MOUSE_BUTTON_WHEEL_DOWN, true)
	_assert(is_equal_approx(_camera.global_position.distance_to(_navigation.pivot), distance_before), "inverse wheel steps must restore distance")
	original = _camera.global_transform
	_mouse_button(MOUSE_BUTTON_RIGHT, true)
	_mouse_motion(Vector2(70.0, 40.0))
	_key(KEY_W)
	_mouse_button(MOUSE_BUTTON_RIGHT, false)
	_assert(_camera.global_transform.is_equal_approx(original), "RMB and WASD must remain free of fly navigation")


func _check_views_and_framing() -> void:
	for entry: Array in [[KEY_KP_1, Vector3.BACK], [KEY_KP_3, Vector3.RIGHT], [KEY_KP_7, Vector3.UP]]:
		_key(entry[0])
		_assert(_camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "axis views must be orthographic")
		_assert(_camera.global_basis.z.is_equal_approx(entry[1]), "numpad axis must face the expected direction")
		_key(entry[0], true)
		_assert(_camera.global_basis.z.is_equal_approx(-entry[1]), "Ctrl+numpad must show opposite axis")
	_key(KEY_KP_5)
	_assert(_camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Numpad5 must toggle perspective")
	_key(KEY_KP_5)
	_assert(_camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Numpad5 must toggle orthographic")
	var size_before: float = _camera.size
	_mouse_button(MOUSE_BUTTON_WHEEL_UP, true)
	_assert(_camera.size < size_before, "orthographic zoom must change view size")
	_key(KEY_KP_PERIOD)
	_assert(_navigation.pivot.is_equal_approx(_selected_bounds.get_center()), "Numpad period must frame selected bounds")
	_assert_bounds_visible(_selected_bounds)
	_key(KEY_HOME)
	_assert(_navigation.pivot.is_equal_approx(_scene_bounds.get_center()), "Home must frame scene bounds")
	_assert(_camera.size > _scene_bounds.size.length(), "framing must include bounds with margin")
	_assert_bounds_visible(_scene_bounds)
	_key(KEY_KP_5)
	_key(KEY_KP_PERIOD)
	_assert_bounds_visible(_selected_bounds)
	_key(KEY_KP_7)
	_mouse_button(MOUSE_BUTTON_MIDDLE, true)
	_mouse_motion(Vector2(8.0, 8.0))
	_mouse_button(MOUSE_BUTTON_MIDDLE, false)
	_assert(_camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "orbiting an axis view must restore perspective")
	_assert(_camera.global_transform.is_finite(), "top-view orbit must remain finite")


func _check_focus_and_modal_guards() -> void:
	_editor.grab_focus()
	var original: Transform3D = _camera.global_transform
	_key(KEY_KP_1)
	_key(KEY_HOME)
	_assert(_camera.global_transform.is_equal_approx(original), "focused text editor must keep camera shortcuts")
	_mouse_button(MOUSE_BUTTON_WHEEL_UP, true, Vector2(1000, 100))
	_mouse_button(MOUSE_BUTTON_MIDDLE, true, Vector2(1000, 100))
	_assert(not _navigation.is_navigating(), "middle click over GUI must not start navigation")
	_assert(_camera.global_transform.is_equal_approx(original), "scrolling a GUI panel must not zoom camera")
	_mouse_button(MOUSE_BUTTON_MIDDLE, false, Vector2(1000, 100))
	_mouse_button(MOUSE_BUTTON_MIDDLE, true)
	_assert(root.gui_get_focus_owner() == null, "viewport navigation must release stale GUI focus")
	_mouse_button(MOUSE_BUTTON_MIDDLE, false, Vector2(1000, 100))
	_assert(not _navigation.is_navigating(), "MMB release over GUI must not leave navigation stuck")
	_mouse_motion(Vector2(45.0, 12.0))
	_assert(_camera.global_transform.is_equal_approx(original), "motion after GUI release must not navigate")
	_mouse_button(MOUSE_BUTTON_MIDDLE, true)
	root.focus_exited.emit()
	_assert(not _navigation.is_navigating(), "focus loss must end navigation")
	_mouse_button(MOUSE_BUTTON_MIDDLE, true)
	_navigation.navigation_enabled = false
	_assert(not _navigation.is_navigating(), "modal disable must cancel navigation")
	_mouse_motion(Vector2(60.0, 60.0))
	_mouse_button(MOUSE_BUTTON_WHEEL_UP, true)
	_key(KEY_KP_3)
	_assert(_camera.global_transform.is_equal_approx(original), "modal disable must block all camera inputs")
	_navigation.navigation_enabled = true
	_mouse_button(MOUSE_BUTTON_MIDDLE, false)
	_key(KEY_KP_1)
	_assert(_camera.global_basis.z.is_equal_approx(Vector3.BACK), "navigation must recover after modal editing")


func _assert_bounds_visible(bounds: AABB) -> void:
	var viewport_rect: Rect2 = root.get_visible_rect()
	for index: int in range(8):
		var corner: Vector3 = bounds.get_endpoint(index)
		_assert(not _camera.is_position_behind(corner), "framed corners must be in front of camera")
		_assert(viewport_rect.has_point(_camera.unproject_position(corner)), "framed corners must fit the viewport")


func _mouse_button(button: MouseButton, pressed: bool, position: Vector2 = Vector2(450, 250)) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	event.global_position = position
	root.push_input(event)
	if button == MOUSE_BUTTON_WHEEL_UP or button == MOUSE_BUTTON_WHEEL_DOWN:
		event.pressed = false
		root.push_input(event)


func _mouse_motion(relative: Vector2, shift: bool = false, ctrl: bool = false) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = Vector2(450, 250)
	event.relative = relative
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	root.push_input(event)


func _key(keycode: Key, ctrl: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	event.ctrl_pressed = ctrl
	root.push_input(event)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
