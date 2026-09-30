extends RefCounted

const CATALOG_PATH: String = "res://assets/materials/catalog.json"
const MATERIAL_DIRECTORY: String = "res://assets/materials"
const MESH_DIRECTORY: String = "res://assets/meshes"


static func material_path(material_name: String) -> String:
	return "%s/%s.tres" % [MATERIAL_DIRECTORY, material_name.to_snake_case()]


static func mesh_path(part_id: StringName) -> String:
	return "%s/%s.res" % [MESH_DIRECTORY, part_id]


static func load_mesh(part_id: StringName) -> ArrayMesh:
	var path: String = mesh_path(part_id)
	if not ResourceLoader.exists(path):
		push_error("%s: missing materialized mesh. Run tools/godot/make_materials.gd first." % part_id)
		return null
	var mesh: ArrayMesh = load(path) as ArrayMesh
	if mesh == null:
		push_error("%s: expected an ArrayMesh at %s" % [part_id, path])
	return mesh
