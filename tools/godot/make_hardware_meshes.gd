extends SceneTree

## Bake the legacy catalog's detailed visual meshes in place:
## godot --headless --path . -s tools/godot/make_hardware_meshes.gd -- [part id ...]
## Kit hardware is baked by make_functional_parts.gd from the shared kit catalog.

const HardwareMeshes = preload("res://tools/godot/hardware_meshes.gd")


func _initialize() -> void:
	var requested: PackedStringArray = OS.get_cmdline_user_args()
	for id: String in requested:
		if id not in HardwareMeshes.LEGACY_IDS:
			push_error("Unknown hardware part: %s" % id)
			quit(1)
			return
	for id: String in HardwareMeshes.LEGACY_IDS:
		if not requested.is_empty() and id not in requested:
			continue
		if bake(id) != OK:
			quit(1)
			return
	quit()


static func bake(id: String) -> Error:
	var definition := load("res://assets/parts/%s.tres" % id) as PartDef
	if definition == null or definition.mesh == null:
		push_error("Missing original mesh envelope for %s" % id)
		return ERR_INVALID_DATA
	var mesh: ArrayMesh = HardwareMeshes.build(definition, definition.mesh.get_aabb())
	if mesh == null:
		return ERR_INVALID_DATA
	var error: Error = ResourceSaver.save(mesh, definition.mesh.resource_path, ResourceSaver.FLAG_COMPRESS)
	print("%s: %d triangles, %s" % [id, mesh.get_faces().size() / 3, error_string(error)])
	return error
