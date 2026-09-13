class_name PartNode
extends Node3D

var part_def: PartDef
var graph_index: int = -1

var _port_markers: Dictionary[StringName, Marker3D] = {}


func setup(definition: PartDef, index: int) -> void:
	part_def = definition
	graph_index = index
	name = String(part_def.id)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = part_def.mesh
	add_child(mesh_instance)

	for port: Port in part_def.ports:
		var marker := Marker3D.new()
		marker.name = String(port.id)
		marker.position = port.local_position
		marker.basis = _basis_for_normal(port.local_normal)
		add_child(marker)
		_port_markers[port.id] = marker

	var body := StaticBody3D.new()
	body.set_meta(&"part_node", self)
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = part_def.mesh.get_aabb().size
	collision_shape.position = part_def.mesh.get_aabb().get_center()
	collision_shape.shape = box_shape
	body.add_child(collision_shape)
	add_child(body)


func get_port(port_id: StringName) -> Port:
	for port: Port in part_def.ports:
		if port.id == port_id:
			return port
	return null


func get_port_global_position(port_id: StringName) -> Vector3:
	var marker: Marker3D = _port_markers[port_id]
	return marker.global_position


func get_port_global_normal(port_id: StringName) -> Vector3:
	var marker: Marker3D = _port_markers[port_id]
	return marker.global_basis.y.normalized()


func _basis_for_normal(normal: Vector3) -> Basis:
	var normalized_normal := normal.normalized()
	if normalized_normal.is_zero_approx():
		normalized_normal = Vector3.UP
	return Basis(Quaternion(Vector3.UP, normalized_normal))
