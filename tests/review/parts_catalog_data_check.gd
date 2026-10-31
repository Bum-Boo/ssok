extends SceneTree

## Review audit: every loaded part definition is well formed and every kit catalog
## entry matches its generated resource. Size mismatches are reported, not failed.
const DIRECTORIES: Array[String] = ["res://assets/parts/", "res://assets/humanoid/", "res://assets/modular_humanoid/parts/", "res://assets/construction_kit/parts/", "res://assets/learning_biped/parts/"]
const KIT: String = "res://assets/construction_kit/"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	var ids: Dictionary = {}
	var total: int = 0
	for directory: String in DIRECTORIES:
		for file: String in ResourceLoader.list_directory(directory):
			if not file.ends_with(".tres") or file.contains("/"):
				continue
			var definition: PartDef = load(directory + file) as PartDef
			if definition == null:
				continue
			total += 1
			var id: String = String(definition.id)
			_check(not ids.has(id), "unique id " + id + " (" + directory + file + ")")
			ids[id] = directory + file
			_check(file.get_basename() == id, "file name equals id " + directory + file)
			_check(definition.mass_kg > 0.0 and is_finite(definition.mass_kg), "positive mass " + id)
			_check(definition.mesh != null and definition.mesh.get_aabb().size.length() > 0.0, "mesh with extent " + id)
			_check(not definition.display_name.is_empty(), "display name " + id)
			var port_ids: Dictionary = {}
			for port: Port in definition.ports:
				_check(not port_ids.has(port.id), "unique port %s.%s" % [id, port.id])
				port_ids[port.id] = true
				_check(is_equal_approx(port.local_normal.length(), 1.0), "unit normal %s.%s" % [id, port.id])
				_check(not String(port.tag).is_empty() and not port.accepts.is_empty(), "tag/accepts %s.%s" % [id, port.id])
			if definition.mesh != null:
				for surface: int in definition.mesh.get_surface_count():
					var material: Material = definition.mesh.surface_get_material(surface)
					_check(material != null and material.resource_path.begins_with("res://assets/materials/"), "shared material %s surface %d (%s)" % [id, surface, material.resource_path if material else "null"])
	print("AUDIT loaded part definitions: %d, unique ids: %d" % [total, ids.size()])
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT + "catalog.json"))
	var catalog_ids: Dictionary = {}
	for entry: Dictionary in catalog.parts:
		var id: String = entry.id
		_check(not catalog_ids.has(id), "unique catalog id " + id)
		catalog_ids[id] = true
		var path: String = KIT + "parts/" + id + ".tres"
		_check(ResourceLoader.exists(path) and ResourceLoader.exists(entry.mesh), "resources exist " + id)
		var definition: PartDef = load(path) as PartDef
		if definition == null:
			continue
		_check(definition.mesh.resource_path == entry.mesh, "mesh path " + id)
		_check(is_equal_approx(definition.mass_kg, float(entry.mass_kg)), "mass matches catalog " + id)
		_check(definition.display_name == entry.name, "name matches catalog " + id)
		_check(definition.ports.size() == entry.ports.size(), "port count " + id)
		for index: int in mini(definition.ports.size(), entry.ports.size()):
			var port: Port = definition.ports[index]
			var spec: Dictionary = entry.ports[index]
			_check(String(port.id) == spec.id and port.local_position.is_equal_approx(_vector(spec.position)) and port.local_normal.is_equal_approx(_vector(spec.normal)) and port.rotates == bool(spec.get("rotates", false)), "port %s.%s matches catalog" % [id, spec.id])
		_check(is_equal_approx(definition.gear_ratio, float(entry.get("gear_ratio", 0.0))) and definition.passive_hinge == bool(entry.get("passive_hinge", false)) and definition.device_kind == String(entry.get("device_kind", "")), "functional flags " + id)
		_check(is_equal_approx(definition.wheel_radius, float(entry.get("wheel_radius", 0.0))) and is_equal_approx(definition.sphere_radius, float(entry.get("sphere_radius", 0.0))), "radii " + id)
		var anchored: bool = bool(entry.get("anchored", false))
		_check(anchored == (StringName(id) in RunMode.new().anchored_part_ids), "catalog anchored flag equals RunMode anchored list " + id)
		var bounds: AABB = definition.mesh.get_aabb()
		var size: Vector3 = _vector(entry.size)
		if not bounds.size.is_equal_approx(size) and (bounds.size - size).abs().max_axis_index() >= 0 and (bounds.size - size).abs()[(bounds.size - size).abs().max_axis_index()] > 0.0015:
			print("SIZE_MISMATCH %s declared=%s mesh=%s mesh_center=%s declared_center=%s" % [id, size, bounds.size, bounds.get_center(), _vector(entry.center)])
	for category: String in catalog.get("categories", {}):
		print("CATEGORY %s %s" % [category, catalog.categories[category]])
	print("AUDIT kit catalog entries: %d" % catalog_ids.size())
	print("parts_catalog_data_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
