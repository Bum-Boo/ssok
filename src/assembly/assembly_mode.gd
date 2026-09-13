class_name AssemblyMode
extends Node3D

signal link_added(link: Dictionary)
signal link_removed(link: Dictionary)

@export var snap_radius: float = 0.025

var graph: ConnectionGraph = ConnectionGraph.new()

var _part_nodes: Array[PartNode] = []
var _dragged_part: PartNode
var _drag_plane := Plane(Vector3.UP)
var _drag_offset := Vector3.ZERO


func spawn_part(definition: PartDef, xform: Transform3D) -> PartNode:
	var graph_index := graph.parts.size()
	graph.parts.append({"part_def": definition, "transform": xform})
	return _create_part_node(definition, graph_index, xform)


func load_graph(source_graph: ConnectionGraph) -> void:
	for part_node: PartNode in _part_nodes:
		part_node.queue_free()
	_part_nodes.clear()
	graph = source_graph
	for index: int in range(graph.parts.size()):
		var part_entry: Dictionary = graph.parts[index]
		var definition: PartDef = part_entry["part_def"]
		var xform: Transform3D = part_entry["transform"]
		_create_part_node(definition, index, xform)


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
			_begin_drag(button_event.position)
		elif _dragged_part != null:
			try_snap(_dragged_part)
			_dragged_part = null
	elif event is InputEventMouseMotion and _dragged_part != null:
		var motion_event := event as InputEventMouseMotion
		_move_dragged_part(motion_event.position)


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


func _begin_drag(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit["collider"] as StaticBody3D
	if collider == null or not collider.has_meta(&"part_node"):
		return
	_dragged_part = collider.get_meta(&"part_node") as PartNode
	unsnap(_dragged_part)
	_drag_plane = Plane(Vector3.UP, _dragged_part.global_position.y)
	var plane_position: Variant = _drag_plane.intersects_ray(ray_origin, ray_end - ray_origin)
	if plane_position is Vector3:
		_drag_offset = _dragged_part.global_position - (plane_position as Vector3)


func _move_dragged_part(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var plane_position: Variant = _drag_plane.intersects_ray(ray_origin, ray_direction)
	if plane_position is Vector3:
		_dragged_part.global_position = (plane_position as Vector3) + _drag_offset
		_update_graph_transform(_dragged_part)


func _update_graph_transform(part: PartNode) -> void:
	graph.parts[part.graph_index]["transform"] = part.global_transform
