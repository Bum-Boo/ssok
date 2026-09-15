extends SceneTree

## Renders shared production materials in GL Compatibility without authoring a scene.
## godot --path . -s tools/godot/material_preview.gd
## Saves user://mesh_previews/materials.png.

const PartMaterials = preload("res://tools/godot/part_materials.gd")
const IMAGE_SIZE: Vector2i = Vector2i(1600, 1000)
const INK: Color = Color(0.88, 0.93, 0.96)
const MUTED: Color = Color(0.43, 0.56, 0.65)
const SWATCHES: Array[Dictionary] = [
	{"material": "Shell", "title": "SATIN ABS", "detail": "White robot shell"},
	{"material": "DetailTeal", "title": "TEAL TRIM", "detail": "Satin polymer insert"},
	{"material": "Rubber", "title": "RUBBER GRIP", "detail": "Matte tire and foot pad"},
	{"material": "Silver", "title": "BRUSHED ALUMINUM", "detail": "Sensor can and metal finish"},
	{"material": "BoardBody", "title": "PCB SOLDER MASK", "detail": "Coated circuit board"},
	{"material": "DetailAmber", "title": "AMBER INDICATOR", "detail": "Low-emission LED lens"}
]

var _viewport: SubViewport
var _world: Node3D
var _overlay: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1120, 700)
	root.title = "ssok material preview"
	_viewport = SubViewport.new()
	_viewport.size = IMAGE_SIZE
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var display: TextureRect = TextureRect.new()
	display.texture = _viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = Vector2(root.size)
	root.add_child(display)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_overlay = Control.new()
	_viewport.add_child(_overlay)
	_create_studio()
	_label("ssok", Vector2(75, 38), 54, INK)
	_label("MATERIAL LIBRARY / PLASTIC · METAL · RUBBER · PCB", Vector2(78, 105), 19, MUTED)
	_label("06 SURFACE STUDIES", Vector2(1207, 65), 21, INK)
	for index: int in SWATCHES.size():
		_create_swatch(index, SWATCHES[index])
	_label("Shared production materials · GL Compatibility · DetailAmber emission is decorative, not circuit-driven", Vector2(75, 948), 18, MUTED)
	for frame: int in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://mesh_previews")
	var path: String = "user://mesh_previews/materials.png"
	var error: Error = _viewport.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save material preview: %s" % error_string(error))
		quit(1)
		return
	print("saved ", ProjectSettings.globalize_path(path))
	quit()


func _create_studio() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.052, 0.070)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.55
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.46, 0.64)
	sky_material.sky_horizon_color = Color(0.88, 0.91, 0.98)
	sky_material.ground_horizon_color = Color(0.72, 0.77, 0.84)
	sky_material.ground_bottom_color = Color(0.045, 0.060, 0.095)
	sky_material.sky_curve = 0.3
	sky_material.ground_curve = 0.25
	sky.sky_material = sky_material
	environment.sky = sky
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	_light(Vector3(-35, -35, 0), Color(1.0, 0.94, 0.85), 1.25)
	_light(Vector3(-20, 140, 0), Color(0.6, 0.76, 1.0), 0.65)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.2
	camera.near = 0.001
	camera.position = Vector3(0, 0, 0.4)
	_world.add_child(camera)


func _create_swatch(index: int, swatch: Dictionary) -> void:
	var column: int = index % 3
	var row: int = index / 3
	var left: float = 75 + column * 510
	var center: Vector2 = Vector2(left + 205, 300 + row * 350)
	var material: StandardMaterial3D = load(PartMaterials.material_path(swatch["material"])) as StandardMaterial3D
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.023
	sphere.height = 0.046
	sphere.radial_segments = 64
	sphere.rings = 32
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = sphere
	instance.material_override = material
	instance.position = Vector3((center.x - 800) * 0.0002, (500 - center.y) * 0.0002, 0)
	_world.add_child(instance)
	var label_position: Vector2 = Vector2(left, center.y + 131)
	_label(swatch["title"], label_position, 25, INK)
	_label(swatch["detail"], label_position + Vector2(0, 34), 18, MUTED)
	_label("Metal %.2f  /  Roughness %.2f" % [material.metallic, material.roughness], label_position + Vector2(0, 62), 16, MUTED)


func _light(rotation: Vector3, color: Color, energy: float) -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = energy
	_world.add_child(light)


func _label(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_overlay.add_child(label)
