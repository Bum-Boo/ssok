extends SceneTree

const ROOT: String = "res://assets/construction_kit/"
const MATERIALS = preload("res://tools/godot/part_materials.gd")
var _failed: bool = false


func _initialize() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "catalog.json"))
	DirAccess.make_dir_recursive_absolute(ROOT + "parts")
	DirAccess.make_dir_recursive_absolute(ROOT + "meshes")
	for entry: Dictionary in catalog.parts:
		var source: ArrayMesh = load(ROOT + "obj/" + String(entry.id) + ".obj") as ArrayMesh
		if source == null:
			_failed = true
			continue
		var mesh: ArrayMesh = source.duplicate(true) as ArrayMesh
		for surface: int in mesh.get_surface_count():
			var material: Material = source.surface_get_material(surface)
			var path: String = MATERIALS.material_path(material.resource_name)
			if not ResourceLoader.exists(path):
				push_error("Missing shared material: " + path)
				_failed = true
				continue
			mesh.surface_set_material(surface, load(path))
		mesh.resource_name = entry.id
		var mesh_path: String = ROOT + "meshes/" + String(entry.id) + ".res"
		ResourceSaver.save(mesh, mesh_path, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_CHANGE_PATH)
		mesh.take_over_path(mesh_path)
		var definition := PartDef.new()
		definition.id = StringName(entry.id)
		definition.display_name = entry.name
		definition.mass_kg = entry.mass_kg
		definition.mesh = mesh
		definition.merge_fixed_connections = true
		definition.physics_frame_priority = int(entry.get("physics_frame_priority", 100 if entry.kind == "controller" else 0))
		definition.actuator_torque_nm = float(entry.geometry.get("torque_nm", 0.0))
		definition.actuator_min_deg = float(entry.get("min_deg", -140.0))
		definition.actuator_max_deg = float(entry.get("max_deg", 140.0))
		definition.actuator_drives_connected_body = definition.actuator_torque_nm > 0.0
		for bounds: Dictionary in entry.get("collision_boxes", []):
			var size: Vector3 = _vector(bounds.size)
			definition.collision_boxes.append(AABB(_vector(bounds.position) - size * 0.5, size))
		for item: Dictionary in entry.ports:
			var port := Port.new()
			port.id = StringName(item.id)
			port.local_position = _vector(item.position)
			port.local_normal = _vector(item.normal)
			port.kind = Port.Kind.ELEC if item.get("kind", "MECH") == "ELEC" else Port.Kind.MECH
			port.tag = StringName(item.tag)
			for accepted: String in item.accepts:
				port.accepts.append(StringName(accepted))
			port.rotates = bool(item.get("rotates", false))
			definition.ports.append(port)
		if ResourceSaver.save(definition, ROOT + "parts/" + String(entry.id) + ".tres") != OK:
			_failed = true
	print("make_construction_kit_defs: %d generic construction parts; failed=%s" % [catalog.parts.size(), _failed])
	quit(1 if _failed else 0)


func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
