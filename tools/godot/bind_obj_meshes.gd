extends SceneTree

## Points each PartDef at its Blender-made OBJ. Run after tools/blender/make_parts.py:
##   godot --headless --path . --import && godot --headless --path . -s tools/godot/bind_obj_meshes.gd

const PART_IDS := ["base", "servo", "arm_link", "board"]


func _init() -> void:
	var failed := false
	for id: String in PART_IDS:
		var def: PartDef = load("res://assets/parts/%s.tres" % id)
		var mesh: Mesh = load("res://assets/parts/%s.obj" % id)
		if mesh == null:
			push_error("missing or unimported OBJ for %s" % id)
			failed = true
			continue
		def.mesh = mesh
		var err := ResourceSaver.save(def, def.resource_path)
		print("%s: save=%d surfaces=%d aabb=%s" % [id, err, mesh.get_surface_count(), mesh.get_aabb()])
		failed = failed or err != OK
	quit(1 if failed else 0)
