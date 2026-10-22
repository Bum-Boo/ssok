extends SceneTree

## Reproducible primitive meshes and mechanical interfaces from the shared kit catalog.
const ROOT: String = "res://assets/construction_kit/"


func _initialize() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "catalog.json"))
	var generated: int = 0
	for entry: Dictionary in catalog.parts:
		if entry.geometry.type != "functional_v1":
			continue
		if write_definition(entry) != OK:
			quit(1)
			return
		generated += 1
	print("make_functional_parts: %d parts" % generated)
	quit(0)


static func write_definition(entry: Dictionary) -> Error:
	var mesh := ArrayMesh.new()
	for component: Dictionary in entry.geometry.components:
		var primitive: PrimitiveMesh
		if component.type == "cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = component.radius
			cylinder.bottom_radius = component.radius
			cylinder.height = component.depth
			cylinder.radial_segments = 32
			primitive = cylinder
		else:
			var box := BoxMesh.new()
			box.size = _vector(component.size)
			primitive = box
		var arrays: Array = primitive.get_mesh_arrays()
		var pose := Transform3D(Basis(Vector3.RIGHT, PI / 2.0) if component.type == "cylinder" else Basis.IDENTITY, _vector(component.position))
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index: int in vertices.size():
			vertices[index] = pose * vertices[index]
			normals[index] = pose.basis * normals[index]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, load("res://assets/materials/" + component.get("material", "chassis_metal") + ".tres"))
	mesh.resource_name = entry.id
	if ResourceSaver.save(mesh, entry.mesh, ResourceSaver.FLAG_COMPRESS) != OK:
		return FAILED
	mesh.take_over_path(entry.mesh)
	var definition := PartDef.new()
	definition.id = entry.id
	definition.display_name = entry.name
	definition.mesh = mesh
	definition.mass_kg = entry.mass_kg
	definition.merge_fixed_connections = true
	definition.passive_hinge = entry.get("passive_hinge", false)
	definition.actuator_min_deg = entry.get("min_deg", -90.0)
	definition.actuator_max_deg = entry.get("max_deg", 90.0)
	definition.wheel_radius = entry.get("wheel_radius", 0.0)
	definition.wheel_width = entry.get("wheel_width", 0.0)
	for bounds: Dictionary in entry.collision_boxes:
		var size: Vector3 = _vector(bounds.size)
		definition.collision_boxes.append(AABB(_vector(bounds.position) - size * 0.5, size))
	for spec: Dictionary in entry.ports:
		var port := Port.new()
		port.id = spec.id
		port.local_position = _vector(spec.position)
		port.local_normal = _vector(spec.normal)
		port.tag = spec.tag
		for tag: String in spec.accepts:
			port.accepts.append(StringName(tag))
		port.rotates = spec.get("rotates", false)
		definition.ports.append(port)
	if ResourceSaver.save(definition, ROOT + "parts/" + entry.id + ".tres") != OK:
		return FAILED
	return OK


static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
