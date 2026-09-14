class_name AssemblyMode
extends Node3D

signal link_added(link: Dictionary)
signal link_removed(link: Dictionary)

@export var snap_radius: float = 0.025

var graph: ConnectionGraph = ConnectionGraph.new()

var gizmo: TransformGizmo

var _part_nodes: Array[PartNode] = []
var _dragged_part: PartNode
var _drag_plane := Plane(Vector3.UP)
var _drag_offset := Vector3.ZERO
var _drag_vertical := false
var _drag_vertical_anchor := Vector3.ZERO

var _selected_part: PartNode
var _gizmo_kind: StringName = &""
var _gizmo_axis := Vector3.ZERO
var _gizmo_start_position := Vector3.ZERO
var _gizmo_start_offset := 0.0
var _gizmo_start_basis := Basis.IDENTITY
var _gizmo_start_vector := Vector3.ZERO


func _ready() -> void:
	gizmo = TransformGizmo.new()
	add_child(gizmo)


func _process(_delta: float) -> void:
	gizmo.set_enabled(_selected_part != null)
	if _selected_part != null:
		gizmo.global_position = _selected_part.global_position


func spawn_part(definition: PartDef, xform: Transform3D) -> PartNode:
	var graph_index := graph.parts.size()
	graph.parts.append({"part_def": definition, "transform": xform})
	return _create_part_node(definition, graph_index, xform)


func load_graph(source_graph: ConnectionGraph) -> void:
	for part_node: PartNode in _part_nodes:
		part_node.queue_free()
	_part_nodes.clear()
	_selected_part = null
	_dragged_part = null
	_gizmo_kind = &""
	graph = source_graph
	for index: int in range(graph.parts.size()):
		var part_entry: Dictionary = graph.parts[index]
		var definition: PartDef = part_entry["part_def"]
		var xform: Transform3D = part_entry["transform"]
		_create_part_node(definition, index, xform)


func remove_part(part: PartNode) -> void:
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
		_selected_part = null
	if _dragged_part == part:
		_dragged_part = null
	part.queue_free()


func remove_selected() -> bool:
	if _selected_part == null:
		return false
	remove_part(_selected_part)
	return true


func select_part(part: PartNode) -> void:
	_selected_part = part


func try_snap(part: PartNode) -> bool:
	var candidate := _find_nearest_candidate(part)
	if candidate.is_empty():
		return false
	snap(part, candidate["my_port"], candidate["other_part"], candidate["other_port"])
	return true


func snap(part: PartNode, part_port_id: StringName, other_part: PartNode, other_port_id: StringName) -> void:
	if _is_port_linked(part.graph_index, part_port_id) or _is_port_linked(other_part.graph_index, other_port_id):
		return

	var source_normal := part.get_port_global_normal(part_port_id)
	var target_normal := -other_part.get_port_global_normal(other_port_id)
	var rotation := Basis(Quaternion(source_normal, target_normal))
	var aligned_transform := part.global_transform
	aligned_transform.basis = rotation * aligned_transform.basis
	part.global_transform = aligned_transform
	part.global_position += other_part.get_port_global_position(other_port_id) - part.get_port_global_position(part_port_id)
	_update_graph_transform(part)

	var link: Dictionary = {
		"a_part": part.graph_index,
		"a_port": part_port_id,
		"b_part": other_part.graph_index,
		"b_port": other_port_id,
	}
	graph.links.append(link)
	link_added.emit(link)


func unsnap(part: PartNode) -> void:
	for index: int in range(graph.links.size() - 1, -1, -1):
		var link: Dictionary = graph.links[index]
		if link["a_part"] == part.graph_index or link["b_part"] == part.graph_index:
			var removed_link: Dictionary = graph.links.pop_at(index)
			link_removed.emit(removed_link)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if button_event.pressed:
			_begin_click(button_event.position)
		else:
			_end_click()
	elif event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if _dragged_part != null:
			_move_dragged_part(motion_event.position)
		elif _gizmo_kind != &"":
			_move_gizmo_handle(motion_event.position)


func _create_part_node(definition: PartDef, index: int, xform: Transform3D) -> PartNode:
	var part_node := PartNode.new()
	part_node.setup(definition, index)
	add_child(part_node)
	part_node.global_transform = xform
	_part_nodes.append(part_node)
	return part_node


func _find_nearest_candidate(part: PartNode) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := snap_radius
	for my_port: Port in part.part_def.ports:
		if _is_port_linked(part.graph_index, my_port.id):
			continue
		for other_part: PartNode in _part_nodes:
			if other_part == part:
				continue
			for other_port: Port in other_part.part_def.ports:
				if my_port.kind != other_port.kind or not _ports_accept(my_port, other_port):
					continue
				if _is_port_linked(other_part.graph_index, other_port.id):
					continue
				var distance := part.get_port_global_position(my_port.id).distance_to(
					other_part.get_port_global_position(other_port.id)
				)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest = {
						"my_port": my_port.id,
						"other_part": other_part,
						"other_port": other_port.id,
					}
	return nearest


func _ports_accept(first: Port, second: Port) -> bool:
	return first.tag in second.accepts or second.tag in first.accepts


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
	var ray_end := ray_origin + ray_direction * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		select_part(null)
		return
	var collider := hit["collider"] as Node

	if _selected_part != null and collider.has_meta(&"gizmo_axis"):
		var axis: Vector3 = collider.get_meta(&"gizmo_axis")
		var kind: StringName = collider.get_meta(&"gizmo_kind")
		unsnap(_selected_part)
		if kind == &"translate":
			_begin_gizmo_translate(axis, ray_origin, ray_direction)
		else:
			_begin_gizmo_rotate(axis, ray_origin, ray_direction)
		return

	if collider.has_meta(&"part_node"):
		var part := collider.get_meta(&"part_node") as PartNode
		select_part(part)
		_dragged_part = part
		unsnap(part)
		_drag_vertical = false
		_drag_plane = Plane(Vector3.UP, part.global_position.y)
		var plane_position: Variant = _drag_plane.intersects_ray(ray_origin, ray_direction)
		if plane_position is Vector3:
			_drag_offset = part.global_position - (plane_position as Vector3)
		return

	select_part(null)


func _end_click() -> void:
	if _dragged_part != null:
		try_snap(_dragged_part)
		_dragged_part = null
	elif _gizmo_kind != &"":
		try_snap(_selected_part)
		_gizmo_kind = &""


func _begin_gizmo_translate(axis: Vector3, ray_origin: Vector3, ray_direction: Vector3) -> void:
	_gizmo_kind = &"translate"
	_gizmo_axis = axis
	_gizmo_start_position = _selected_part.global_position
	var hit_point := _closest_point_on_axis(_gizmo_start_position, axis, ray_origin, ray_direction)
	_gizmo_start_offset = (hit_point - _gizmo_start_position).dot(axis)


func _begin_gizmo_rotate(axis: Vector3, ray_origin: Vector3, ray_direction: Vector3) -> void:
	_gizmo_kind = &"rotate"
	_gizmo_axis = axis
	_gizmo_start_basis = _selected_part.global_transform.basis
	_gizmo_start_vector = _vector_on_axis_plane(axis, _selected_part.global_position, ray_origin, ray_direction)


func _move_gizmo_handle(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)

	if _gizmo_kind == &"translate":
		var hit_point := _closest_point_on_axis(_gizmo_start_position, _gizmo_axis, ray_origin, ray_direction)
		var t := (hit_point - _gizmo_start_position).dot(_gizmo_axis) - _gizmo_start_offset
		_selected_part.global_position = _gizmo_start_position + _gizmo_axis * t
		_update_graph_transform(_selected_part)
	elif _gizmo_kind == &"rotate":
		var current := _vector_on_axis_plane(_gizmo_axis, _selected_part.global_position, ray_origin, ray_direction)
		if current.is_zero_approx() or _gizmo_start_vector.is_zero_approx():
			return
		var angle := atan2(_gizmo_start_vector.cross(current).dot(_gizmo_axis), _gizmo_start_vector.dot(current))
		var new_transform := _selected_part.global_transform
		new_transform.basis = Basis(_gizmo_axis, angle) * _gizmo_start_basis
		_selected_part.global_transform = new_transform
		_update_graph_transform(_selected_part)


## Point on the mouse ray, radially out from `anchor` on the plane perpendicular
## to `axis` -- the reference vector rotate-drag measures its angle against.
func _vector_on_axis_plane(axis: Vector3, anchor: Vector3, ray_origin: Vector3, ray_direction: Vector3) -> Vector3:
	var plane := Plane(axis, anchor.dot(axis))
	var hit: Variant = plane.intersects_ray(ray_origin, ray_direction)
	if hit is Vector3:
		return (hit as Vector3) - anchor
	return Vector3.ZERO


func _move_dragged_part(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)

	## Shift switches from the horizontal snap plane to the part's own vertical
	## line, so height can be adjusted without also drifting on X/Z.
	var shift_held := Input.is_key_pressed(KEY_SHIFT)
	if shift_held != _drag_vertical:
		_drag_vertical = shift_held
		if _drag_vertical:
			_drag_vertical_anchor = _dragged_part.global_position
		else:
			_drag_plane = Plane(Vector3.UP, _dragged_part.global_position.y)
			_drag_offset = _dragged_part.global_position - (_drag_plane.intersects_ray(ray_origin, ray_direction) as Vector3)

	if _drag_vertical:
		var point := _closest_point_on_axis(_drag_vertical_anchor, Vector3.UP, ray_origin, ray_direction)
		_dragged_part.global_position = Vector3(_drag_vertical_anchor.x, point.y, _drag_vertical_anchor.z)
		_update_graph_transform(_dragged_part)
	else:
		var plane_position: Variant = _drag_plane.intersects_ray(ray_origin, ray_direction)
		if plane_position is Vector3:
			_dragged_part.global_position = (plane_position as Vector3) + _drag_offset
			_update_graph_transform(_dragged_part)


## Closest point to the mouse ray on the line through `anchor` running along
## `axis` (closest-point-between-two-lines, specialized for a unit line dir).
func _closest_point_on_axis(anchor: Vector3, axis: Vector3, ray_origin: Vector3, ray_direction: Vector3) -> Vector3:
	var r := ray_origin - anchor
	var b := ray_direction.dot(axis)
	var f := r.dot(axis)
	var c := ray_direction.dot(r)
	var denom := 1.0 - b * b
	if absf(denom) < 0.0001:
		return anchor
	var t := (f - b * c) / denom
	return anchor + axis * t


func _update_graph_transform(part: PartNode) -> void:
	graph.parts[part.graph_index]["transform"] = part.global_transform
