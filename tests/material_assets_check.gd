extends SceneTree

## Checks shared PBR assets and verifies material binding never changes robot geometry.
## godot --headless --path . -s tests/material_assets_check.gd

const PartMaterials = preload("res://tools/godot/part_materials.gd")
const TEXTURE_DIRECTORY: String = "res://assets/materials/textures"

var _failures: Array[String] = []
var _material_specs: Dictionary = {}
var _families: Dictionary = {}
var _used_materials: Dictionary[String, bool] = {}
var _definitions: Array[PartDef] = []
var _surface_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PartMaterials.CATALOG_PATH))
	_check(parsed is Dictionary, "material catalog parses")
	if not parsed is Dictionary:
		quit(1)
		return
	var catalog: Dictionary = parsed
	_check(catalog.get("version") == 1 and catalog.get("color_space") == "linear", "catalog uses the shared linear-color schema")
	_material_specs = catalog.get("materials", {})
	_families = catalog.get("families", {})
	_check(not _material_specs.is_empty() and not _families.is_empty(), "catalog contains materials and surface families")
	for material_name: String in _material_specs:
		_check_material(material_name, _material_specs[material_name])
	_check_meshes()
	for material_name: String in _material_specs:
		if not _material_specs[material_name].get("hidden", false):
			_check(_used_materials.has(material_name), "%s is bound to a palette mesh" % material_name)
	_check_modes()
	print("material_assets_check: %d materials, %d parts, %d surfaces, %d failure(s)" % [
		_material_specs.size(), _definitions.size(), _surface_count, _failures.size()])
	quit(1 if not _failures.is_empty() else 0)


func _check_material(material_name: String, spec: Dictionary) -> void:
	var path: String = PartMaterials.material_path(material_name)
	var material: StandardMaterial3D = load(path) as StandardMaterial3D
	_check(material != null, "%s loads as a web-compatible StandardMaterial3D" % material_name)
	if material == null:
		return
	var components: Array = spec["base_color"]
	var expected_color: Color = Color(components[0], components[1], components[2]).linear_to_srgb()
	var valid: bool = material.resource_path == path and material.resource_name == material_name
	valid = valid and material.albedo_color.is_equal_approx(expected_color)
	valid = valid and is_equal_approx(material.metallic, float(spec["metallic"]))
	valid = valid and is_equal_approx(material.roughness, float(spec["roughness"]))
	valid = valid and is_equal_approx(material.metallic_specular, float(spec["specular"]))
	valid = valid and not material.resource_local_to_scene
	_check(valid, "%s preserves catalog color/PBR values as a shared external resource" % material_name)
	var emission_energy: float = float(spec.get("emission_energy", 0.0))
	_check((emission_energy > 0.0) == (material_name == "DetailAmber"), "%s catalog emission is limited to the indicator LED" % material_name)
	var valid_emission: bool = material.emission_enabled == (emission_energy > 0.0)
	if emission_energy > 0.0:
		valid_emission = valid_emission and material.emission.is_equal_approx(expected_color)
		valid_emission = valid_emission and is_equal_approx(material.emission_energy_multiplier, emission_energy)
	_check(valid_emission, "%s has the expected emission state" % material_name)
	var family: String = spec["family"]
	var surface: Dictionary = _families[family]
	if family == "smooth":
		_check(not material.normal_enabled and material.normal_texture == null, "%s needs no normal texture" % material_name)
		return
	var texture_family: String = "plastic" if family == "pcb" else family
	var texture_path: String = "%s/%s_normal.res" % [TEXTURE_DIRECTORY, texture_family]
	var texture: ImageTexture = material.normal_texture as ImageTexture
	var valid_texture: bool = material.normal_enabled and texture != null
	valid_texture = valid_texture and material.uv1_triplanar and not material.uv1_world_triplanar
	valid_texture = valid_texture and material.uv1_scale.is_equal_approx(Vector3.ONE * float(surface["texture_scale"]))
	valid_texture = valid_texture and is_equal_approx(material.normal_scale, float(surface["normal_scale"]))
	valid_texture = valid_texture and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if texture != null:
		var image: Image = texture.get_image()
		valid_texture = valid_texture and texture.resource_path == texture_path
		valid_texture = valid_texture and texture == load(texture_path)
		valid_texture = valid_texture and image != null and image.get_size() == Vector2i(128, 128)
		valid_texture = valid_texture and image.has_mipmaps()
	_check(valid_texture, "%s uses a shared baked normal map with local triplanar mapping" % material_name)


func _check_meshes() -> void:
	var directory: DirAccess = DirAccess.open("res://assets/parts")
	_check(directory != null, "palette directory exists")
	if directory == null:
		return
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for filename: String in files:
		if not filename.ends_with(".tres"):
			continue
		var definition: PartDef = load("res://assets/parts/" + filename) as PartDef
		_check(definition != null, "%s loads as PartDef" % filename)
		if definition == null:
			continue
		_definitions.append(definition)
		var source: ArrayMesh = load("res://assets/parts/%s.obj" % definition.id) as ArrayMesh
		var mesh: ArrayMesh = definition.mesh as ArrayMesh
		_check(source != null and mesh != null, "%s source and materialized meshes exist" % definition.id)
		if source == null or mesh == null:
			continue
		_check(mesh.resource_path == PartMaterials.mesh_path(definition.id), "%s PartDef uses the persistent materialized mesh" % definition.id)
		var valid_geometry: bool = source.get_aabb() == mesh.get_aabb()
		valid_geometry = valid_geometry and source.get_surface_count() == mesh.get_surface_count()
		var valid_materials: bool = true
		for surface: int in mini(source.get_surface_count(), mesh.get_surface_count()):
			valid_geometry = valid_geometry and source.surface_get_primitive_type(surface) == mesh.surface_get_primitive_type(surface)
			valid_geometry = valid_geometry and source.surface_get_format(surface) == mesh.surface_get_format(surface)
			valid_geometry = valid_geometry and source.surface_get_arrays(surface) == mesh.surface_get_arrays(surface)
			var imported: Material = source.surface_get_material(surface)
			var material_name: String = imported.resource_name if imported != null else ""
			if material_name.is_empty():
				material_name = "Temporary_cutter"
			var expected_path: String = PartMaterials.material_path(material_name)
			var material: Material = mesh.surface_get_material(surface)
			valid_materials = valid_materials and _material_specs.has(material_name) and material != null
			if material != null:
				valid_materials = valid_materials and material.resource_path == expected_path
				valid_materials = valid_materials and material == load(expected_path)
			_used_materials[material_name] = true
			_surface_count += 1
		_check(valid_geometry, "%s exactly preserves all source vertex/index/normal arrays and AABB" % definition.id)
		_check(valid_materials, "%s surfaces resolve the correct shared catalog materials" % definition.id)
	_check(_definitions.size() == 19, "all 19 robot part definitions are checked")


func _check_modes() -> void:
	var assembly: AssemblyMode = AssemblyMode.new()
	root.add_child(assembly)
	var valid_assembly: bool = true
	for definition: PartDef in _definitions:
		var part: PartNode = assembly.spawn_part(definition, Transform3D.IDENTITY)
		var visual: MeshInstance3D = _visual_child(part)
		valid_assembly = valid_assembly and visual != null and visual.mesh == definition.mesh
	_check(valid_assembly, "assembly uses each materialized mesh without copying or overriding materials")
	var run_mode: RunMode = RunMode.new()
	root.add_child(run_mode)
	run_mode.build(assembly.graph)
	var valid_runtime: bool = run_mode.bodies.size() == _definitions.size()
	for index: int in run_mode.bodies.size():
		var visual: MeshInstance3D = _visual_child(run_mode.bodies[index])
		valid_runtime = valid_runtime and visual != null and visual.mesh == _definitions[index].mesh
	_check(valid_runtime, "run mode uses the same graph-derived materialized meshes as assembly")
	run_mode.teardown()
	run_mode.free()
	assembly.free()


func _visual_child(parent: Node) -> MeshInstance3D:
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			var visual: MeshInstance3D = child as MeshInstance3D
			if visual.material_override != null:
				return null
			for surface: int in visual.mesh.get_surface_count():
				if visual.get_surface_override_material(surface) != null:
					return null
			return visual
	return null


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failures.append(message)
