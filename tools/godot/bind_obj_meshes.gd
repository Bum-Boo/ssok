extends SceneTree

## Rebinds existing PartDefs without replacing their port specifications.
## Run tools/godot/make_materials.gd first; raw OBJs do not contain the shared PBR finishes.

const PartMaterials = preload("res://tools/godot/part_materials.gd")


func _init() -> void:
	var failed: bool = false
	var definitions: Array[PartDef] = []
	var meshes: Array[ArrayMesh] = []
	var directory: DirAccess = DirAccess.open("res://assets/parts")
	if directory == null:
		push_error("Missing parts directory")
		quit(1)
		return
	for filename: String in directory.get_files():
		if not filename.ends_with(".tres"):
			continue
		var def: PartDef = load("res://assets/parts/" + filename) as PartDef
		if def == null:
			push_error("Invalid PartDef: %s" % filename)
			failed = true
			continue
		var mesh: ArrayMesh = PartMaterials.load_mesh(def.id)
		if mesh == null:
			failed = true
			continue
		definitions.append(def)
		meshes.append(mesh)
	if failed or definitions.is_empty():
		quit(1)
		return
	for index: int in definitions.size():
		var def: PartDef = definitions[index]
		def.mesh = meshes[index]
		var err: Error = ResourceSaver.save(def, def.resource_path)
		print("%s: save=%d surfaces=%d" % [def.id, err, def.mesh.get_surface_count()])
		failed = failed or err != OK
	quit(1 if failed else 0)
