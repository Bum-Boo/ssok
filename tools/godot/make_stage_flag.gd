extends SceneTree

## Keep the task flag on the same imported OBJ/shared PBR path as the existing palette.
func _initialize() -> void:
	var source: ArrayMesh = load("res://assets/parts/flag.obj")
	var mesh := ArrayMesh.new()
	for surface: int in source.get_surface_count():
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), source.surface_get_arrays(surface))
		mesh.surface_set_material(surface, load("res://assets/materials/orange.tres"))
	var error: Error = ResourceSaver.save(mesh, "res://assets/meshes/flag.res", ResourceSaver.FLAG_COMPRESS)
	print("make_stage_flag: ", error_string(error))
	quit(0 if error == OK else 1)
