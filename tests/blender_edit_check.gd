extends SceneTree

var _failed := 0
var _checks := 0
var _assembly: AssemblyMode
var _camera: Camera3D


func _initialize() -> void:
	call_deferred(&"_run_check")


func _run_check() -> void:
	root.size = Vector2i(1000, 750)
	_assembly = AssemblyMode.new()
	root.add_child(_assembly)
	_camera = Camera3D.new()
	root.add_child(_camera)
	_camera.position = Vector3(0.4, 0.3, 0.6)
	_camera.look_at(Vector3.ZERO)
	_camera.current = true
	var base := _assembly.spawn_part(load("res://assets/parts/base.tres"), Transform3D.IDENTITY)
	var servo := _assembly.spawn_part(load("res://assets/parts/servo.tres"), Transform3D(Basis.IDENTITY, Vector3(0, 0.026, 0)))
	_check(_assembly.try_snap(servo), "setup snaps servo to base")
	_assembly.clear_history()
	var initial := servo.global_transform
	var initial_links: Array[Dictionary] = _assembly.graph.links.duplicate(true)
	await physics_frame
	await physics_frame
	_mouse_button(MOUSE_BUTTON_LEFT, true, _camera.unproject_position(servo.global_position))
	_mouse_button(MOUSE_BUTTON_LEFT, false, _camera.unproject_position(servo.global_position))
	_check(_assembly.selected_part == servo, "LMB ray selection selects servo")
	_check(_assembly.graph.links == initial_links, "LMB selection leaves links intact")
	_check(servo.global_transform == initial, "LMB selection leaves exact transform intact")
	_key(KEY_G)
	_check(_assembly.transform_active, "G begins modal move")
	_key(KEY_X)
	_key(KEY_1)
	_key(KEY_0)
	_check(is_equal_approx(servo.position.x, initial.origin.x + 0.01), "G X 10 uses millimeters")
	_check(_assembly.graph.parts[servo.graph_index]["transform"] == servo.global_transform, "preview writes ConnectionGraph transform")
	_check(_assembly.graph.links.is_empty(), "actual movement detaches links")
	_key(KEY_ESCAPE)
	_check(not _assembly.transform_active, "Esc exits modal move")
	_check(servo.global_transform == initial, "Esc restores exact transform")
	_check(_assembly.graph.links == initial_links, "Esc restores exact links")
	_key(KEY_G)
	_key(KEY_ENTER)
	_check(_assembly.graph.links == initial_links, "no-op confirmation retains links")
	_key(KEY_G)
	_key(KEY_X)
	_key(KEY_2)
	_key(KEY_0)
	_key(KEY_0)
	_key(KEY_ENTER)
	_check(is_equal_approx(servo.position.x, initial.origin.x + 0.2), "Enter commits move")
	_check(_assembly.graph.links.is_empty(), "committed distant part stays disconnected")
	_key(KEY_Z, true)
	_check(servo.global_transform == initial and _assembly.graph.links == initial_links, "Ctrl+Z restores transform and links")
	_key(KEY_Z, true, true)
	_check(is_equal_approx(servo.position.x, initial.origin.x + 0.2) and _assembly.graph.links.is_empty(), "Ctrl+Shift+Z restores committed state")
	var moved := servo.global_transform
	_key(KEY_R)
	_key(KEY_Y)
	_key(KEY_9)
	_key(KEY_0)
	_key(KEY_ENTER)
	_check(servo.global_basis.is_equal_approx(Basis(Vector3.UP, PI / 2.0) * moved.basis), "R Y 90 rotates in degrees")
	_check(servo.global_position == moved.origin, "rotation preserves position")
	var rotated := servo.global_transform
	_key(KEY_G)
	_key(KEY_Z)
	_key(KEY_MINUS)
	_key(KEY_1)
	_key(KEY_2)
	_key(KEY_PERIOD)
	_key(KEY_5)
	_key(KEY_9)
	_key(KEY_BACKSPACE)
	_check(is_equal_approx(servo.position.z, moved.origin.z - 0.0125), "signed decimal numeric input and Backspace")
	_mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2.ZERO)
	_check(servo.global_transform == rotated, "RMB restores exact transform")
	_key(KEY_R)
	_key(KEY_X)
	_key(KEY_3)
	_key(KEY_0)
	_mouse_button(MOUSE_BUTTON_LEFT, true, Vector2.ZERO)
	_check(not _assembly.transform_active and servo.global_transform != rotated, "LMB confirms a modal rotation")
	_assembly.undo()
	_check(servo.global_transform == rotated, "rotation undo restores state")
	_key(KEY_G)
	_key(KEY_Y)
	_key(KEY_Y)
	_check(_assembly.get("_constraint") == &"", "repeated axis key restores view-plane constraint")
	_key(KEY_1)
	_assembly.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not _assembly.transform_active and servo.global_transform == rotated, "window focus loss cancels transform")
	var edit := CodeEdit.new()
	root.add_child(edit)
	edit.grab_focus()
	_key(KEY_G)
	_check(not _assembly.transform_active, "CodeEdit focus blocks edit shortcuts")
	_key(KEY_Z, true)
	_check(servo.global_transform == rotated, "CodeEdit focus blocks assembly undo")
	_assembly.select_part(null)
	_assembly.gizmo.set_enabled(false)
	await physics_frame
	await physics_frame
	_mouse_button(MOUSE_BUTTON_LEFT, true, _camera.unproject_position(servo.global_position))
	_mouse_button(MOUSE_BUTTON_LEFT, false, _camera.unproject_position(servo.global_position))
	_check(root.gui_get_focus_owner() == null and _assembly.selected_part == servo, "viewport click releases CodeEdit focus and selects part")
	_key(KEY_G)
	_key(KEY_X)
	_key(KEY_5)
	edit.grab_focus()
	_assembly._process(0.0)
	_check(not _assembly.transform_active and servo.global_transform == rotated, "text focus acquired mid-transform cancels")
	edit.release_focus()
	var status_messages: Array[String] = []
	_assembly.status_changed.connect(func(message: String) -> void: status_messages.append(message))
	_key(KEY_S)
	_check(servo.global_transform == rotated and not _assembly.transform_active, "S cannot change physical part dimensions")
	_check(not status_messages.is_empty() and "fixed" in status_messages.back(), "S explains fixed physical dimensions")
	_assembly.select_part(base)
	_check(_assembly.remove_selected(), "selected deletion succeeds")
	_check(_assembly.graph.parts.size() == 1 and _assembly.graph.links.is_empty(), "deletion updates graph")
	_check(_assembly.undo(), "deletion is undoable")
	_check(_assembly.graph.parts.size() == 2, "deletion undo restores graph parts")
	_check(_assembly.selected_part != null and _assembly.selected_part.part_def.id == &"base", "deletion undo restores selection")
	_check(_assembly.redo() and _assembly.graph.parts.size() == 1, "deletion redo works")
	_assembly.undo()
	_assembly.select_part(_assembly.get("_part_nodes")[1])
	_key(KEY_G)
	_key(KEY_X)
	_key(KEY_9)
	var new_part := _assembly.spawn_part(load("res://assets/parts/arm_link.tres"), Transform3D(Basis.IDENTITY, Vector3.ONE))
	_check(not _assembly.transform_active and _assembly.graph.parts.size() == 3, "adding part safely cancels modal transform")
	_check(_assembly.graph.parts[1]["transform"] == rotated, "adding part rolls back old transform before addition")
	_assembly.select_part(new_part)
	_check(_assembly.undo() and _assembly.graph.parts.size() == 2, "part addition is undoable without discarding unrelated state")
	_check(_assembly.redo() and _assembly.graph.parts.size() == 3, "part addition redo restores added part")
	_assembly.undo()
	var moving: PartNode = _assembly.get("_part_nodes")[1]
	_assembly.select_part(moving)
	var mouse_start := Vector2(550, 320)
	var mouse_end := mouse_start + Vector2(60, 15)
	_assembly.begin_transform(&"translate", mouse_start)
	_motion(mouse_end)
	var full_displacement := moving.global_position - rotated.origin
	_check(not full_displacement.is_zero_approx(), "G mouse motion moves through view plane")
	_check(absf(full_displacement.dot(_camera.global_basis.z)) < 0.00001, "unconstrained G stays in camera plane")
	_motion(mouse_end, true)
	_check((moving.global_position - rotated.origin).is_equal_approx(full_displacement * 0.1), "Shift enables one-tenth precision")
	_motion(mouse_end, false, true)
	var snapped_displacement := moving.global_position - rotated.origin
	_check(snapped_displacement.is_equal_approx(full_displacement.snapped(Vector3.ONE * 0.001)), "Ctrl quantizes movement to millimeters")
	_assembly.cancel_transform()
	_key(KEY_G)
	_key(KEY_X)
	_key(KEY_KP_2)
	_key(KEY_KP_PERIOD)
	_key(KEY_KP_5)
	_check(is_equal_approx(moving.global_position.x, rotated.origin.x + 0.0025), "numpad numeric input works")
	_assembly.cancel_transform()
	_assembly.load_graph(ConnectionGraph.new())
	base = _assembly.spawn_part(load("res://assets/parts/base.tres"), Transform3D.IDENTITY)
	moving = _assembly.spawn_part(load("res://assets/parts/servo.tres"), Transform3D(Basis.IDENTITY, Vector3(0.1, 0.026, 0)))
	_assembly.select_part(moving)
	_key(KEY_G)
	_key(KEY_X)
	_key(KEY_MINUS)
	_key(KEY_1)
	_key(KEY_0)
	_key(KEY_0)
	_key(KEY_ENTER)
	_check(_assembly.graph.links.size() == 1, "transform confirmation still snaps compatible ports")
	_check(moving.get_port_global_position(&"mount_bottom").is_equal_approx(base.get_port_global_position(&"mount_top")), "confirmed snap aligns actual port geometry")
	_assembly.remove_selected()
	_assembly.undo()
	_check(_assembly.graph.links.size() == 1 and _assembly.graph.parts.size() == 2, "deletion undo restores connected graph links")
	var saved_transform := _assembly.selected_part.global_transform
	var saved_links: Array[Dictionary] = _assembly.graph.links.duplicate(true)
	_key(KEY_G)
	_key(KEY_X)
	_assembly.set("_numeric_input", "1" + "0".repeat(400))
	_assembly._apply_transform()
	_check(_assembly.selected_part.global_transform == saved_transform and _assembly.graph.links == saved_links, "non-finite numeric input cannot mutate graph or detach links")
	_assembly.cancel_transform()
	_key(KEY_G)
	_key(KEY_X)
	for index: int in range(40):
		_key(KEY_9)
	_check(String(_assembly.get("_numeric_input")).length() == 16, "numeric entry length is bounded")
	_assembly.cancel_transform()
	var panel := Panel.new()
	panel.position = Vector2(800, 20)
	panel.size = Vector2(180, 300)
	root.add_child(panel)
	await process_frame
	_key(KEY_G)
	_key(KEY_X)
	_key(KEY_5)
	_assembly.set("_gizmo_drag", true)
	var hover := InputEventMouseMotion.new()
	hover.position = Vector2(850, 50)
	root.push_input(hover, true)
	await process_frame
	_check(root.gui_get_hovered_control() == panel, "test panel receives GUI hover")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = hover.position
	root.push_input(release, true)
	await process_frame
	_check(not _assembly.transform_active and _assembly.selected_part.global_transform == saved_transform, "gizmo release over GUI cancels and restores exact transform")
	_check(_assembly.graph.links == saved_links, "gizmo release over GUI restores links")
	_check(_assembly.get_scene_bounds().has_volume(), "scene bounds available to camera framing")
	print("blender_edit_check: %d checks, %d failures" % [_checks, _failed])
	quit(1 if _failed else 0)


func _key(code: Key, ctrl := false, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	_assembly._unhandled_input(event)


func _mouse_button(button: MouseButton, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	_assembly._unhandled_input(event)


func _motion(position: Vector2, shift := false, ctrl := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	_assembly._unhandled_input(event)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error(message)
