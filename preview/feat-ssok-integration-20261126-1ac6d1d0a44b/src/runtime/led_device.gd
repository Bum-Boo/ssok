class_name LEDDevice
extends RefCounted

const GLOW_SHADER: Shader = preload("res://assets/shaders/led_glow.gdshader")
const GLOW_COLOR: Color = Color(1.0, 0.32, 0.08)

var brightness: float = 0.0
var material: StandardMaterial3D
## Additive halo over the lens (ADR 0045); a child of the LED visual, freed with it.
var glow: MeshInstance3D
var _glow_material: ShaderMaterial


func configure(visual: MeshInstance3D) -> void:
	var surface: int = lens_surface(visual.mesh)
	material = visual.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
	visual.set_surface_override_material(surface, material)
	_add_glow(visual, surface)
	off()


## The emitting lens: the surface whose material is named "lens" in the detailed hardware meshes
## (tools/godot/hardware_meshes.gd), which end with board silkscreen. Older meshes end with the lens.
static func lens_surface(mesh: Mesh) -> int:
	for surface: int in mesh.get_surface_count():
		var source: Material = mesh.surface_get_material(surface)
		if source != null and source.resource_name == "lens":
			return surface
	return mesh.get_surface_count() - 1


func on() -> void:
	set_brightness(1.0)


func off() -> void:
	set_brightness(0.0)


func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.0, 1.0)
	material.emission_enabled = brightness > 0.0
	material.emission = Color(1.0, 0.2, 0.01) * brightness
	material.emission_energy_multiplier = 2.0 * brightness
	material.albedo_color = Color(0.12 + 0.88 * brightness, 0.025 + 0.175 * brightness, 0.005, 1.0)
	if is_instance_valid(glow):
		glow.visible = brightness > 0.0
		_glow_material.set_shader_parameter("intensity", 1.6 * brightness)


## A camera-facing quad centred on the lens surface and a few lens sizes wide.
func _add_glow(visual: MeshInstance3D, surface: int) -> void:
	# The lens and, in detailed meshes, the glass dome over it.
	var points := PackedVector3Array()
	for index: int in visual.mesh.get_surface_count():
		var source: Material = visual.mesh.surface_get_material(index)
		if index != surface and (source == null or source.resource_name != "glass"):
			continue
		var arrays: Array = visual.mesh.surface_get_arrays(index)
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			points.append_array(arrays[Mesh.ARRAY_VERTEX])
	# Without surface data (some headless runs) the top of the whole part stands in for the lens.
	var lens := visual.mesh.get_aabb()
	if not points.is_empty():
		lens = AABB(points[0], Vector3.ZERO)
		for point: Vector3 in points:
			lens = lens.expand(point)
	else:
		lens = AABB(lens.position + Vector3(0, lens.size.y * 0.7, 0), lens.size * Vector3(0.5, 0.3, 0.5))
	var quad := QuadMesh.new()
	var width: float = clampf(lens.size.length() * 3.2, 0.012, 0.05)
	quad.size = Vector2(width, width)
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = GLOW_SHADER
	_glow_material.set_shader_parameter("glow_color", GLOW_COLOR)
	_glow_material.set_shader_parameter("lift", maxf(lens.size.length() * 0.6, 0.004))
	glow = MeshInstance3D.new()
	glow.name = "LEDGlow"
	glow.mesh = quad
	glow.material_override = _glow_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = lens.get_center()
	glow.visible = false
	visual.add_child(glow)
