class_name PartNode
extends Node3D

var part_def: PartDef
var graph_index: int = -1

var _port_markers: Dictionary[StringName, Marker3D] = {}
var _mesh_instance: MeshInstance3D
var _preview_material: StandardMaterial3D
var _xray_material: StandardMaterial3D
## The override the mesh had before X-ray, restored when it ends.
var _xray_previous: Material
var xray: bool:
	get:
		return _xray_material != null and _mesh_instance.material_override == _xray_material


func setup(definition: PartDef, index: int) -> void:
	part_def = definition
	graph_index = index
	name = String(part_def.id)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = part_def.mesh
	add_child(mesh_instance)
	_mesh_instance = mesh_instance

	for port: Port in part_def.ports:
		var marker := Marker3D.new()
		marker.name = String(port.id)
		marker.position = port.local_position
		marker.basis = _basis_for_normal(port.local_normal)
		add_child(marker)
		_port_markers[port.id] = marker

	var body := StaticBody3D.new()
	body.set_meta(&"part_node", self)
	body.collision_layer = 1
	body.collision_mask = 0
	var bounds: Array[AABB] = part_def.collision_boxes
	if bounds.is_empty() and part_def.mesh != null:
		bounds = [part_def.mesh.get_aabb()]
	for box: AABB in bounds:
		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box.size
		collision_shape.position = box.get_center()
		collision_shape.shape = box_shape
		body.add_child(collision_shape)
	add_child(body)


## A transient ghost never changes the shared catalog mesh or its materials.
func set_placement_preview(blocked: bool) -> void:
	if _preview_material == null:
		_preview_material = StandardMaterial3D.new()
		_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tint: Color = SsokTheme.ERROR if blocked else SsokTheme.ACCENT
	_preview_material.albedo_color = Color(tint, 0.45)
	_mesh_instance.material_override = _preview_material
	for child: Node in get_children():
		if child is StaticBody3D:
			child.collision_layer = 0


## Structural parts with no electrical ports, which X-ray turns see-through.
func is_structural() -> bool:
	for port: Port in part_def.ports:
		if port.kind == Port.Kind.ELEC:
			return false
	return true


## See-through view for wiring. Keeps the part's own colour; never edits shared materials.
func set_xray(on: bool) -> void:
	if on == xray:
		return
	if not on:
		_mesh_instance.material_override = _xray_previous
		_xray_previous = null
		return
	_xray_previous = _mesh_instance.material_override
	var base: Color = Color(0.6, 0.64, 0.7)
	var source: Material = _xray_previous
	if source == null and _mesh_instance.mesh != null and _mesh_instance.mesh.get_surface_count() > 0:
		source = _mesh_instance.mesh.surface_get_material(0)
	if source is BaseMaterial3D:
		base = (source as BaseMaterial3D).albedo_color
	if _xray_material == null:
		_xray_material = StandardMaterial3D.new()
		_xray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_xray_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_xray_material.cull_mode = BaseMaterial3D.CULL_BACK
	_xray_material.albedo_color = Color(base, 0.22)
	_mesh_instance.material_override = _xray_material


func clear_placement_preview() -> void:
	_mesh_instance.material_override = null
	for child: Node in get_children():
		if child is StaticBody3D:
			child.collision_layer = 1


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
