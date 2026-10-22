extends SceneTree

## Keep the task flag on the same imported OBJ/shared PBR path as the existing palette.
func _initialize() -> void:
	var source: ArrayMesh = load("res://assets/parts/flag.obj")
	var mesh: ArrayMesh = source.duplicate(true)
	mesh.resource_name = "flag"
	mesh.resource_scene_unique_id = "Mesh_flag"
	for surface: int in source.get_surface_count():
		mesh.surface_set_material(surface, load("res://assets/materials/orange.tres"))
	var error: Error = ResourceSaver.save(mesh, "res://assets/meshes/flag.res", ResourceSaver.FLAG_COMPRESS)
	print("make_stage_flag: ", error_string(error))
	quit(0 if error == OK else 1)
