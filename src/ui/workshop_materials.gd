class_name WorkshopMaterials
extends RefCounted

## Moves part surfaces onto the shared WebGL2 surface shader and keeps every converted surface on
## the current theme's studio hemisphere (ADR 0043). Catalog meshes and their materials are never
## modified: each MeshInstance3D receives per-surface overrides, cached by source material, so the
## LED device, ghosts and thumbnails still see the original StandardMaterial3D.

const SHADER: Shader = preload("res://assets/shaders/workshop_part.gdshader")

## Source StandardMaterial3D -> converted ShaderMaterial.
static var _variants: Dictionary = {}
static var _environment: Dictionary = {}


## Converts every supported surface of a part visual. Unsupported materials stay untouched.
static func dress(visual: MeshInstance3D) -> void:
	if visual == null or visual.mesh == null:
		return
	for surface: int in visual.mesh.get_surface_count():
		var source: Material = visual.get_surface_override_material(surface)
		if source == null:
			source = visual.mesh.surface_get_material(surface)
		var converted: ShaderMaterial = variant(source)
		if converted != null and converted != source:
			visual.set_surface_override_material(surface, converted)


## The converted material for a source, or null when the source uses a feature the part shader
## does not reproduce (transparency, textures other than a triplanar normal map, unshaded, ...).
static func variant(source: Material) -> ShaderMaterial:
	if source is ShaderMaterial and (source as ShaderMaterial).shader == SHADER:
		return source
	if not source is StandardMaterial3D or not supports(source):
		return null
	if _variants.has(source):
		return _variants[source]
	var standard: StandardMaterial3D = source
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.resource_name = standard.resource_name
	material.set_shader_parameter("albedo", standard.albedo_color)
	material.set_shader_parameter("metallic", standard.metallic)
	material.set_shader_parameter("roughness", standard.roughness)
	material.set_shader_parameter("specular", standard.metallic_specular)
	if standard.normal_enabled and standard.normal_texture != null:
		material.set_shader_parameter("texture_normal", standard.normal_texture)
		material.set_shader_parameter("normal_scale", standard.normal_scale)
		material.set_shader_parameter("uv1_scale", standard.uv1_scale)
	if standard.emission_enabled:
		material.set_shader_parameter("emission", standard.emission)
		material.set_shader_parameter("emission_energy", standard.emission_energy_multiplier)
	_apply_environment(material)
	_variants[source] = material
	return material


static func supports(standard: StandardMaterial3D) -> bool:
	if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or standard.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		return false
	if standard.cull_mode != BaseMaterial3D.CULL_BACK or standard.vertex_color_use_as_albedo or standard.next_pass != null:
		return false
	if standard.albedo_texture != null or standard.metallic_texture != null or standard.roughness_texture != null or standard.emission_texture != null:
		return false
	if standard.detail_enabled or standard.rim_enabled or standard.clearcoat_enabled or standard.anisotropy_enabled or standard.ao_enabled or standard.heightmap_enabled or standard.subsurf_scatter_enabled or standard.backlight_enabled or standard.refraction_enabled:
		return false
	# Normal maps are reproduced only in the object-space triplanar projection the kit uses.
	if standard.normal_enabled and standard.normal_texture != null and not standard.uv1_triplanar:
		return false
	return true


## Studio hemisphere and lamp reflection for the current theme; see WorkshopLook.palette().
static func set_environment(values: Dictionary) -> void:
	_environment = values
	for material: ShaderMaterial in _variants.values():
		_apply_environment(material)


static func converted_count() -> int:
	return _variants.size()


static func _apply_environment(material: ShaderMaterial) -> void:
	for key: String in _environment:
		material.set_shader_parameter(key, _environment[key])
