class_name AssemblyMode
extends Node3D

signal link_added(link: Dictionary)
signal link_removed(link: Dictionary)
signal graph_changed()
signal selection_changed(part: PartNode)
signal status_changed(message: String)
signal transform_active_changed(active: bool)

const MAX_NUMERIC_CHARACTERS := 16

@export var snap_radius: float = 0.025

var graph: ConnectionGraph = ConnectionGraph.new()
var gizmo: TransformGizmo
var selected_part: PartNode:
	get:
		return _selected_part
var transform_active: bool:
	get:
		return _transform_kind != &""

var _part_nodes: Array[PartNode] = []
var _selected_part: PartNode
var _transform_kind: StringName = &""
var _constraint: StringName = &""
var _numeric_input: String = ""
var _start_transform := Transform3D.IDENTITY
var _start_mouse := Vector2.ZERO
var _current_mouse := Vector2.ZERO
var _view_basis := Basis.IDENTITY
var _before_transform: Dictionary = {}
var _detached := false
var _gizmo_drag := false
var _precision := false
var _increment_snap := false
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []


func _ready() -> void:
	gizmo = TransformGizmo.new()
	add_child(gizmo)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_transform()


func _process(_delta: float) -> void:
	if gizmo != null:
		gizmo.set_enabled(_selected_part != null and not transform_active)
		if _selected_part != null:
			gizmo.global_position = _selected_part.global_position
	if transform_active and _text_has_focus():
		cancel_transform()


func spawn_part(definition: PartDef, xform: Transform3D) -> PartNode:
	cancel_transform()
	if graph.parts.size() >= MotionSnapshot.MAX_PARTS:
		status_changed.emit("This project supports up to 256 parts. Delete a part before adding another.")
		return null
	if not xform.is_finite():
		status_changed.emit("Transform exceeds the supported numeric range")
		return null
	if maxf(absf(xform.origin.x), maxf(absf(xform.origin.y), absf(xform.origin.z))) > MotionSnapshot.MAX_POSITION:
		status_changed.emit("Parts must stay within 100 m of the workspace origin.")
		return null
	var before := _snapshot()
	var graph_index := graph.parts.size()
	graph.parts.append({"part_def": definition, "transform": xform})
	var part := _create_part_node(definition, graph_index, xform)
	_record_action(before)
	graph_changed.emit()
	return part


func load_graph(source_graph: ConnectionGraph) -> void:
	cancel_transform()
	clear_history()
	for part_node: PartNode in _part_nodes:
		remove_child(part_node)
		part_node.queue_free()
	_part_nodes.clear()
	_selected_part = null
	graph = source_graph
	for index: int in range(graph.parts.size()):
		var part_entry: Dictionary = graph.parts[index]
		_create_part_node(part_entry["part_def"], index, part_entry["transform"])
	selection_changed.emit(null)
	graph_changed.emit()


func remove_part(part: PartNode) -> void:
	cancel_transform()
	if part == null or part not in _part_nodes:
		return
	var before := _snapshot()
	unsnap(part)
	var removed_index := part.graph_index
	graph.parts.remove_at(removed_index)
	_part_nodes.erase(part)
	for other: PartNode in _part_nodes:
		if other.graph_index > removed_index:
			other.graph_index -= 1
	for link: Dictionary in graph.links:
		if link["a_part"] > removed_index:
			link["a_part"] -= 1
		if link["b_part"] > removed_index:
			link["b_part"] -= 1
	if _selected_part == part:
		select_part(null)
	remove_child(part)
	part.queue_free()
	_record_action(before)
	graph_changed.emit()
	status_changed.emit("Part deleted · Ctrl+Z to undo")


func remove_selected() -> bool:
	if _selected_part == null or transform_active:
		return false
	remove_part(_selected_part)
	return true


func select_part(part: PartNode) -> void:
	if transform_active:
		cancel_transform()
	_selected_part = part
	selection_changed.emit(part)


func get_selection_bounds() -> AABB:
	if _selected_part == null:
		return AABB()
	return _selected_part.global_transform * _selected_part.part_def.mesh.get_aabb()


func get_scene_bounds() -> AABB:
	var bounds := AABB()
	for index: int in range(_part_nodes.size()):
		var part: PartNode = _part_nodes[index]
		var part_bounds: AABB = part.global_transform * part.part_def.mesh.get_aabb()
		bounds = part_bounds if index == 0 else bounds.merge(part_bounds)
	return bounds


func begin_transform(kind: StringName, screen_position := Vector2.INF) -> bool:
	if _selected_part == null or transform_active or _text_has_focus():
		return false
	if kind != &"translate" and kind != &"rotate":
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	_before_transform = _snapshot()
	_start_transform = _selected_part.global_transform
	_start_mouse = get_viewport().get_mouse_position() if screen_position == Vector2.INF else screen_position
	_current_mouse = _start_mouse
	_view_basis = camera.global_basis.orthonormalized()
	_transform_kind = kind
	_constraint = &""
	_numeric_input = ""
	_detached = false
	_gizmo_drag = false
	_precision = false
	_increment_snap = false
	transform_active_changed.emit(true)
	_report_transform()
	return true


func confirm_transform() -> void:
	if not transform_active:
		return
	var before: Dictionary = _before_transform
	var moved := not _selected_part.global_transform.is_equal_approx(_start_transform)
	if moved:
		try_snap(_selected_part)
	else:
		_restore_snapshot(before)
	_finish_transform()
	if moved:
		_record_action(before)
	graph_changed.emit()
	status_changed.emit("Transform confirmed · Ctrl+Z to undo" if moved else "Transform unchanged")


func cancel_transform() -> void:
	if not transform_active:
		return
	_restore_snapshot(_before_transform)
	_finish_transform()
	graph_changed.emit()
	status_changed.emit("Transform cancelled")


func _finish_transform() -> void:
	_transform_kind = &""
	_constraint = &""
	_numeric_input = ""
	_before_transform = {}
	_detached = false
	_gizmo_drag = false
	transform_active_changed.emit(false)


func clear_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


func undo() -> bool:
	if transform_active:
		cancel_transform()
		return true
	if _undo_stack.is_empty():
		return false
	var action: Dictionary = _undo_stack.pop_back()
	_restore_snapshot(action["before"])
	_redo_stack.append(action)
	graph_changed.emit()
	status_changed.emit("Undo")
	return true


func redo() -> bool:
	if transform_active or _redo_stack.is_empty():
		return false
	var action: Dictionary = _redo_stack.pop_back()
	_restore_snapshot(action["after"])
	_undo_stack.append(action)
	graph_changed.emit()
	status_changed.emit("Redo")
	return true


func _snapshot() -> Dictionary:
	return {
		"parts": graph.parts.duplicate(true),
		"links": graph.links.duplicate(true),
		"selected": _selected_part.graph_index if _selected_part != null else -1,
	}


func _record_action(before: Dictionary) -> void:
	_undo_stack.append({"before": before, "after": _snapshot()})
	if _undo_stack.size() > 64:
		_undo_stack.pop_front()
	_redo_stack.clear()


func _restore_snapshot(snapshot: Dictionary) -> void:
	var old_links: Array[Dictionary] = graph.links.duplicate(true)
	var entries: Array = snapshot["parts"]
	var rebuild := entries.size() != _part_nodes.size()
	if not rebuild:
		for index: int in range(entries.size()):
			if entries[index]["part_def"] != _part_nodes[index].part_def:
				rebuild = true
				break
	graph.parts.assign(entries.duplicate(true))
	graph.links.assign(snapshot["links"].duplicate(true))
	if rebuild:
		for part: PartNode in _part_nodes:
			remove_child(part)
			part.queue_free()
		_part_nodes.clear()
		for index: int in range(graph.parts.size()):
			_create_part_node(graph.parts[index]["part_def"], index, graph.parts[index]["transform"])
	else:
		for index: int in range(graph.parts.size()):
			_part_nodes[index].global_transform = graph.parts[index]["transform"]
	var selected_index: int = snapshot["selected"]
	_selected_part = _part_nodes[selected_index] if selected_index >= 0 and selected_index < _part_nodes.size() else null
	for link: Dictionary in old_links:
		if link not in graph.links:
			link_removed.emit(link)
	for link: Dictionary in graph.links:
		if link not in old_links:
			link_added.emit(link)
	selection_changed.emit(_selected_part)


func try_snap(part: PartNode) -> bool:
	var candidate := _find_nearest_candidate(part)
	if candidate.is_empty():
		return false
	return snap(part, candidate["my_port"], candidate["other_part"], candidate["other_port"])


func snap(part: PartNode, part_port_id: StringName, other_part: PartNode, other_port_id: StringName) -> bool:
	if part == null or other_part == null or part == other_part or part not in _part_nodes or other_part not in _part_nodes:
		return false
	var source_port: Port = part.get_port(part_port_id)
	var target_port: Port = other_part.get_port(other_port_id)
	if source_port == null or target_port == null or source_port.kind != target_port.kind or not _ports_accept(source_port, target_port):
		return false
	if _is_port_linked(part.graph_index, part_port_id) or _is_port_linked(other_part.graph_index, other_port_id):
		return false
	if source_port.kind == Port.Kind.MECH:
		var source_normal := part.get_port_global_normal(part_port_id)
		var target_normal := -other_part.get_port_global_normal(other_port_id)
		var rotation := Basis(Quaternion(source_normal, target_normal))
		var aligned_transform := part.global_transform
		aligned_transform.basis = rotation * aligned_transform.basis
		aligned_transform.origin += other_part.get_port_global_position(other_port_id) - aligned_transform * source_port.local_position
		if maxf(absf(aligned_transform.origin.x), maxf(absf(aligned_transform.origin.y), absf(aligned_transform.origin.z))) > MotionSnapshot.MAX_POSITION:
			status_changed.emit("Parts must stay within 100 m of the workspace origin.")
			return false
		part.global_transform = aligned_transform
		_update_graph_transform(part)
	var link: Dictionary = {
		"a_part": part.graph_index, "a_port": part_port_id,
		"b_part": other_part.graph_index, "b_port": other_port_id,
	}
	graph.links.append(link)
	link_added.emit(link)
	return true


func connect_wire(first_index: int, first_port_id: StringName, second_index: int, second_port_id: StringName) -> bool:
	if process_mode == Node.PROCESS_MODE_DISABLED or transform_active or first_index < 0 or second_index < 0 or first_index >= _part_nodes.size() or second_index >= _part_nodes.size() or first_index == second_index:
		return false
	var first: PartNode = _part_nodes[first_index]
	var second: PartNode = _part_nodes[second_index]
	var first_port: Port = first.get_port(first_port_id)
	var second_port: Port = second.get_port(second_port_id)
	if first_port == null or second_port == null or first_port.kind != Port.Kind.ELEC or second_port.kind != Port.Kind.ELEC or not _ports_accept(first_port, second_port):
		return false
	if _is_port_linked(first_index, first_port_id) or _is_port_linked(second_index, second_port_id):
		return false
	var before: Dictionary = _snapshot()
	if not snap(first, first_port_id, second, second_port_id):
		return false
	_record_action(before)
	graph_changed.emit()
	status_changed.emit("Wire connected · Ctrl+Z to undo")
	return true


func disconnect_wire(link: Dictionary) -> bool:
	var index: int = graph.links.find(link)
	if process_mode == Node.PROCESS_MODE_DISABLED or transform_active or index < 0:
		return false
	var port: Port = _part_nodes[link.a_part].get_port(link.a_port)
	if port == null or port.kind != Port.Kind.ELEC:
		return false
	var before: Dictionary = _snapshot()
	graph.links.remove_at(index)
	link_removed.emit(link)
	_record_action(before)
	graph_changed.emit()
	status_changed.emit("Wire disconnected · Ctrl+Z to undo")
	return true


func unsnap(part: PartNode, mechanical_only: bool = false) -> void:
	for index: int in range(graph.links.size() - 1, -1, -1):
		var link: Dictionary = graph.links[index]
		if link["a_part"] == part.graph_index or link["b_part"] == part.graph_index:
			if mechanical_only and part.get_port(link.a_port if link.a_part == part.graph_index else link.b_port).kind == Port.Kind.ELEC:
				continue
			var removed_link: Dictionary = graph.links.pop_at(index)
			link_removed.emit(removed_link)


func _text_has_focus() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return focus != null


func _input(event: InputEvent) -> void:
	# GUI controls may consume the release of a gizmo drag that began in the viewport.
	if event is InputEventMouseButton and _gizmo_drag:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			if get_viewport().gui_get_hovered_control() != null:
				cancel_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			if get_viewport().gui_get_hovered_control() == null:
				get_viewport().gui_release_focus()
	if _text_has_focus():
		cancel_transform()
		return
	var handled := false
	if event is InputEventKey:
		handled = _handle_key(event as InputEventKey)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if transform_active:
			if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
				cancel_transform()
				handled = true
			elif button.button_index == MOUSE_BUTTON_LEFT:
				if (button.pressed and not _gizmo_drag) or (not button.pressed and _gizmo_drag):
					confirm_transform()
				handled = true
		elif button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			_begin_click(button.position)
			handled = true
	elif event is InputEventMouseMotion and transform_active:
		var motion := event as InputEventMouseMotion
		_current_mouse = motion.position
		_precision = motion.shift_pressed
		_increment_snap = motion.ctrl_pressed
		_apply_transform()
		handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _handle_key(event: InputEventKey) -> bool:
	if event.echo:
		return false
	var key: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	if transform_active and (key == KEY_SHIFT or key == KEY_CTRL):
		_precision = event.shift_pressed
		_increment_snap = event.ctrl_pressed
		_apply_transform()
		return true
	if not event.pressed:
		return false
	if event.ctrl_pressed and key == KEY_Z:
		if event.shift_pressed:
			redo()
		else:
			undo()
		return true
	if transform_active:
		if key == KEY_ESCAPE:
			cancel_transform()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			confirm_transform()
		elif key == KEY_X or key == KEY_Y or key == KEY_Z:
			var axis: StringName = &"X" if key == KEY_X else (&"Y" if key == KEY_Y else &"Z")
			_constraint = &"" if _constraint == axis else axis
			_apply_transform()
		elif key == KEY_BACKSPACE:
			_numeric_input = _numeric_input.left(-1)
			_apply_transform()
		elif key == KEY_MINUS or key == KEY_KP_SUBTRACT:
			_numeric_input = _numeric_input.substr(1) if _numeric_input.begins_with("-") else "-" + _numeric_input
			_apply_transform()
		elif key == KEY_PERIOD or key == KEY_KP_PERIOD:
			if "." not in _numeric_input:
				_numeric_input += "."
			_apply_transform()
		elif (key >= KEY_0 and key <= KEY_9) or (key >= KEY_KP_0 and key <= KEY_KP_9):
			if _numeric_input.length() >= MAX_NUMERIC_CHARACTERS:
				status_changed.emit("Numeric input is limited to 16 characters")
				return true
			var digit := int(key) - int(KEY_0) if key <= KEY_9 else int(key) - int(KEY_KP_0)
			_numeric_input += str(digit)
			_apply_transform()
		else:
			return false
		return true
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return false
	if key == KEY_G or key == KEY_R:
		return begin_transform(&"translate" if key == KEY_G else &"rotate")
	if key == KEY_S and _selected_part != null:
		status_changed.emit("Part dimensions are fixed · Scaling is unavailable")
		return true
	return false


func _constraint_axis() -> Vector3:
	match _constraint:
		&"X": return Vector3.RIGHT
		&"Y": return Vector3.UP
		&"Z": return Vector3.BACK
	return Vector3.ZERO


func _apply_transform() -> void:
	if not transform_active:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		cancel_transform()
		return
	var result := _start_transform
	var numeric := _numeric_input.is_valid_float()
	var numeric_value := _numeric_input.to_float() if numeric else 0.0
	if not is_finite(numeric_value):
		status_changed.emit("Transform value must be finite")
		return
	var axis := _constraint_axis()
	var factor := 0.1 if _precision else 1.0
	if _transform_kind == &"translate":
		var displacement := _mouse_displacement(camera, axis) * factor
		if numeric:
			var direction := axis
			if direction.is_zero_approx():
				direction = displacement.normalized() if not displacement.is_zero_approx() else _view_basis.x
			displacement = direction * numeric_value * 0.001
		elif _increment_snap:
			displacement = displacement.snapped(Vector3.ONE * 0.001)
		result.origin += displacement
	else:
		if axis.is_zero_approx():
			axis = _view_basis.z
		var angle := _mouse_rotation(camera, axis) * factor
		if numeric:
			angle = deg_to_rad(numeric_value)
		elif _increment_snap:
			angle = snappedf(angle, deg_to_rad(15.0))
		result.basis = Basis(axis, angle) * _start_transform.basis
	if not result.is_finite():
		status_changed.emit("Transform exceeds the supported numeric range")
		return
	if maxf(absf(result.origin.x), maxf(absf(result.origin.y), absf(result.origin.z))) > MotionSnapshot.MAX_POSITION:
		status_changed.emit("Parts must stay within 100 m of the workspace origin.")
		return
	if not result.is_equal_approx(_start_transform) and not _detached:
		unsnap(_selected_part, true)
		_detached = true
	_selected_part.global_transform = result
	_update_graph_transform(_selected_part)
	_report_transform()


func _mouse_displacement(camera: Camera3D, axis: Vector3) -> Vector3:
	var start_origin := camera.project_ray_origin(_start_mouse)
	var start_direction := camera.project_ray_normal(_start_mouse)
	var current_origin := camera.project_ray_origin(_current_mouse)
	var current_direction := camera.project_ray_normal(_current_mouse)
	if not axis.is_zero_approx():
		var start := _closest_point_on_axis(_start_transform.origin, axis, start_origin, start_direction)
		var current := _closest_point_on_axis(_start_transform.origin, axis, current_origin, current_direction)
		return current - start
	var plane := Plane(_view_basis.z, _start_transform.origin.dot(_view_basis.z))
	var start: Variant = plane.intersects_ray(start_origin, start_direction)
	var current: Variant = plane.intersects_ray(current_origin, current_direction)
	if start is Vector3 and current is Vector3:
		return (current as Vector3) - (start as Vector3)
	return Vector3.ZERO


func _mouse_rotation(camera: Camera3D, axis: Vector3) -> float:
	var start := _vector_on_axis_plane(axis, _start_transform.origin, camera.project_ray_origin(_start_mouse), camera.project_ray_normal(_start_mouse))
	var current := _vector_on_axis_plane(axis, _start_transform.origin, camera.project_ray_origin(_current_mouse), camera.project_ray_normal(_current_mouse))
	if not start.is_zero_approx() and not current.is_zero_approx():
		return atan2(start.cross(current).dot(axis), start.dot(current))
	return (_current_mouse.x - _start_mouse.x) * 0.01


func _report_transform() -> void:
	var operation := tr("Move") if _transform_kind == &"translate" else tr("Rotate")
	var unit := "mm" if _transform_kind == &"translate" else "°"
	var axis := tr("View") if _constraint == &"" else String(_constraint)
	var value := _numeric_input
	if value.is_empty():
		if _transform_kind == &"translate":
			value = "%.2f" % ((_selected_part.global_position - _start_transform.origin).length() * 1000.0)
		else:
			value = tr("mouse")
	status_changed.emit(tr("%s · %s · %s %s | X/Y/Z axis · Enter/LMB confirm · Esc/RMB cancel · Ctrl snap · Shift precise") % [operation, axis, value, unit])


func _create_part_node(definition: PartDef, index: int, xform: Transform3D) -> PartNode:
	var part_node := PartNode.new()
	part_node.setup(definition, index)
	add_child(part_node)
	part_node.global_transform = xform
	_part_nodes.append(part_node)
	return part_node


func _find_nearest_candidate(part: PartNode) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance: float = snap_radius * snap_radius
	# A perforated kit has many ports: resolve occupancy and target transforms once per snap.
	var occupied: Dictionary = {}
	for link: Dictionary in graph.links:
		for endpoint: String in ["a", "b"]:
			var index: int = link[endpoint + "_part"]
			if not occupied.has(index):
				occupied[index] = {}
			occupied[index][link[endpoint + "_port"]] = true
	var targets: Array[Dictionary] = []
	for other_part: PartNode in _part_nodes:
		if other_part == part:
			continue
		for other_port: Port in other_part.part_def.ports:
			if occupied.get(other_part.graph_index, {}).has(other_port.id):
				continue
			targets.append({"part": other_part, "port": other_port, "position": other_part.get_port_global_position(other_port.id)})
	for my_port: Port in part.part_def.ports:
		if occupied.get(part.graph_index, {}).has(my_port.id):
			continue
		var origin: Vector3 = part.get_port_global_position(my_port.id)
		for target: Dictionary in targets:
			var other_port: Port = target.port
			if my_port.kind != other_port.kind or not _ports_accept(my_port, other_port):
				continue
			var distance: float = origin.distance_squared_to(target.position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = {"my_port": my_port.id, "other_part": target.part, "other_port": other_port.id}
	return nearest


func _ports_accept(first: Port, second: Port) -> bool:
	return first.tag in second.accepts and second.tag in first.accepts


func _is_port_linked(part_index: int, port_id: StringName) -> bool:
	for link: Dictionary in graph.links:
		if link["a_part"] == part_index and link["a_port"] == port_id:
			return true
		if link["b_part"] == part_index and link["b_port"] == port_id:
			return true
	return false


func _begin_click(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		select_part(null)
		return
	var collider := hit["collider"] as Node
	if _selected_part != null and collider.has_meta(&"gizmo_axis"):
		var kind: StringName = collider.get_meta(&"gizmo_kind")
		if begin_transform(kind, screen_position):
			var axis: Vector3 = collider.get_meta(&"gizmo_axis")
			_constraint = &"X" if axis == Vector3.RIGHT else (&"Y" if axis == Vector3.UP else &"Z")
			_gizmo_drag = true
			_report_transform()
		return
	if collider.has_meta(&"part_node"):
		select_part(collider.get_meta(&"part_node") as PartNode)
	else:
		select_part(null)


func _vector_on_axis_plane(axis: Vector3, anchor: Vector3, ray_origin: Vector3, ray_direction: Vector3) -> Vector3:
	var plane := Plane(axis, anchor.dot(axis))
	var hit: Variant = plane.intersects_ray(ray_origin, ray_direction)
	return (hit as Vector3) - anchor if hit is Vector3 else Vector3.ZERO


func _closest_point_on_axis(anchor: Vector3, axis: Vector3, ray_origin: Vector3, ray_direction: Vector3) -> Vector3:
	var offset := ray_origin - anchor
	var alignment := ray_direction.dot(axis)
	var denominator := 1.0 - alignment * alignment
	if absf(denominator) < 0.0001:
		return anchor
	var distance := (offset.dot(axis) - alignment * ray_direction.dot(offset)) / denominator
	return anchor + axis * distance


func _update_graph_transform(part: PartNode) -> void:
	graph.parts[part.graph_index]["transform"] = part.global_transform
