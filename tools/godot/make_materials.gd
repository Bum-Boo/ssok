extends SceneTree

## Bakes shared PBR resources and binds them to copies of the imported OBJ meshes.
## godot --headless --path . -s tools/godot/make_materials.gd

const PartMaterials = preload("res://tools/godot/part_materials.gd")
const SOURCE_DIRECTORY: String = "res://assets/parts"
const TEXTURE_DIRECTORY: String = "res://assets/materials/textures"
const TEXTURE_SIZE: int = 128
const TEXTURED_FAMILIES: Array[String] = ["plastic", "rubber", "brushed"]
const FALLBACK_MATERIAL: String = "Temporary_cutter"

var _failed: bool = false
var _families: Dictionary = {}
var _materials: Dictionary[String, StandardMaterial3D] = {}
var _textures: Dictionary[String, ImageTexture] = {}


func _init() -> void:
	var catalog: Dictionary = _read_catalog()
	if _failed:
		quit(1)
		return
	_families = catalog["families"]
	for directory: String in [PartMaterials.MATERIAL_DIRECTORY, PartMaterials.MESH_DIRECTORY, TEXTURE_DIRECTORY]:
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			_fail("Could not create %s" % directory)
	if _failed:
		quit(1)
		return
	for family: String in TEXTURED_FAMILIES:
		_make_texture(family)
	var material_specs: Dictionary = catalog["materials"]
	var material_names: Array = material_specs.keys()
	material_names.sort()
	for material_name: String in material_names:
		_make_material(material_name, material_specs[material_name])
	if _failed:
		quit(1)
		return
	var directory: DirAccess = DirAccess.open(SOURCE_DIRECTORY)
	if directory == null:
		_fail("Could not read %s" % SOURCE_DIRECTORY)
		quit(1)
		return
	var files: PackedStringArray = directory.get_files()
	files.sort()
	var mesh_count: int = 0
	for filename: String in files:
		if filename.ends_with(".obj"):
			_make_mesh(filename)
			mesh_count += 1
	if mesh_count == 0:
		_fail("No imported OBJ sources found in %s" % SOURCE_DIRECTORY)
	print("make_materials: %d materials, %d shared normal maps, %d meshes; failed=%s" % [
		_materials.size(), _textures.size(), mesh_count, _failed])
	quit(1 if _failed else 0)


func _read_catalog() -> Dictionary:
	if not FileAccess.file_exists(PartMaterials.CATALOG_PATH):
		_fail("Missing material catalog: %s" % PartMaterials.CATALOG_PATH)
		return {}
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(FileAccess.get_file_as_string(PartMaterials.CATALOG_PATH))
	if error != OK or not parser.data is Dictionary:
		_fail("Invalid material catalog: %s" % parser.get_error_message())
		return {}
	var catalog: Dictionary = parser.data
	if catalog.get("version") != 1 or catalog.get("color_space") != "linear":
		_fail("Material catalog requires version=1 and color_space=linear")
	elif not catalog.get("families") is Dictionary or not catalog.get("materials") is Dictionary:
		_fail("Material catalog requires families and materials dictionaries")
	return catalog


func _make_texture(family: String) -> void:
	var normal_image: Image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	for y: int in TEXTURE_SIZE:
		for x: int in TEXTURE_SIZE:
			var u: float = float(x) / TEXTURE_SIZE
			var v: float = float(y) / TEXTURE_SIZE
			var slope: Vector2 = _surface_slope(family, u, v)
			var normal: Vector3 = Vector3(-slope.x, -slope.y, 1.0).normalized()
			normal_image.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
	# Renormalized mipmaps keep fine grain from sparkling at the assembly camera distance.
	normal_image.generate_mipmaps(true)
	var texture: ImageTexture = ImageTexture.create_from_image(normal_image)
	texture.resource_name = "%s normal" % family
	texture.resource_scene_unique_id = "Texture_%s" % family
	var path: String = "%s/%s_normal.res" % [TEXTURE_DIRECTORY, family]
	if _save(texture, path, true):
		_textures[family] = texture


func _surface_slope(family: String, u: float, v: float) -> Vector2:
	# Integer wave frequencies make every texture tile seamless without randomness.
	if family == "brushed":
		return Vector2(0.26 * cos(TAU * (19.0 * u + v)) + 0.11 * cos(TAU * 31.0 * u),
			0.014 * cos(TAU * (19.0 * u + v)))
	var amplitude: float = 0.25 if family == "rubber" else 0.14
	var diagonal: float = cos(TAU * (13.0 * u + 11.0 * v))
	return amplitude * Vector2(
		cos(TAU * 7.0 * u) * sin(TAU * 9.0 * v) + 0.45 * diagonal,
		(9.0 / 7.0) * sin(TAU * 7.0 * u) * cos(TAU * 9.0 * v) + (0.45 * 11.0 / 13.0) * diagonal)


func _make_material(material_name: String, spec: Dictionary) -> void:
	var family: String = spec.get("family", "")
	if not _families.has(family):
		_fail("%s: unknown surface family '%s'" % [material_name, family])
		return
	var components: Array = spec.get("base_color", [])
	if components.size() != 3:
		_fail("%s: base_color requires three linear RGB values" % material_name)
		return
	for component: Variant in components:
		if not (component is float or component is int) or float(component) < 0.0 or float(component) > 1.0:
			_fail("%s: base_color components must be numbers in [0, 1]" % material_name)
			return
	for property: String in ["metallic", "roughness", "specular"]:
		var value: Variant = spec.get(property)
		if not (value is float or value is int) or float(value) < 0.0 or float(value) > 1.0:
			_fail("%s: %s must be a number in [0, 1]" % [material_name, property])
			return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = material_name
	material.resource_scene_unique_id = "Material_%s" % material_name.to_snake_case()
	# Blender's node colors are linear; Godot's material color properties are sRGB.
	var color: Color = Color(components[0], components[1], components[2]).linear_to_srgb()
	material.albedo_color = color
	material.metallic = float(spec["metallic"])
	material.roughness = float(spec["roughness"])
	material.metallic_specular = float(spec["specular"])
	var surface: Dictionary = _families[family]
	var texture_family: String = "plastic" if family == "pcb" else family
	if _textures.has(texture_family):
		material.normal_enabled = true
		material.normal_texture = _textures[texture_family]
		material.normal_scale = float(surface["normal_scale"])
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * float(surface["texture_scale"])
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var emission_energy: float = float(spec.get("emission_energy", 0.0))
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	if _save(material, PartMaterials.material_path(material_name)):
		_materials[material_name] = material


func _make_mesh(filename: String) -> void:
	var source_path: String = "%s/%s" % [SOURCE_DIRECTORY, filename]
	var source: ArrayMesh = load(source_path) as ArrayMesh
	if source == null or source.get_surface_count() == 0:
		_fail("%s: import the OBJ with godot --headless --path . --import first" % filename)
		return
	var surface_materials: Array[StandardMaterial3D] = []
	for surface: int in source.get_surface_count():
		var imported: Material = source.surface_get_material(surface)
		var material_name: String = imported.resource_name if imported != null else ""
		if material_name.is_empty():
			material_name = FALLBACK_MATERIAL
		if not _materials.has(material_name):
			_fail("%s surface %d: material '%s' is missing from the catalog" % [filename, surface, material_name])
			return
		surface_materials.append(_materials[material_name])
	# Keep the imported vertex/index buffers, bounds, normals and topology unchanged.
	var mesh: ArrayMesh = source.duplicate(true) as ArrayMesh
	var part_id: StringName = StringName(filename.get_basename())
	mesh.resource_name = String(part_id)
	mesh.resource_scene_unique_id = "Mesh_%s" % part_id
	for surface: int in mesh.get_surface_count():
		mesh.surface_set_material(surface, surface_materials[surface])
	if mesh.get_aabb() != source.get_aabb() or mesh.get_surface_count() != source.get_surface_count():
		_fail("%s: material binding changed geometry bounds or surfaces" % filename)
		return
	if _save(mesh, PartMaterials.mesh_path(part_id), true):
		print("%s: %d surfaces bound to shared materials" % [part_id, mesh.get_surface_count()])


func _save(resource: Resource, path: String, compressed: bool = false) -> bool:
	# Headless ResourceSaver does not update paths via FLAG_CHANGE_PATH alone.
	resource.take_over_path(path)
	var flags: int = ResourceSaver.FLAG_CHANGE_PATH
	if compressed:
		flags |= ResourceSaver.FLAG_COMPRESS
	var error: Error = ResourceSaver.save(resource, path, flags)
	if error != OK:
		_fail("Failed to save %s (error %d)" % [path, error])
	return error == OK


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
