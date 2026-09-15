extends SceneTree

## Renders real imported meshes with GL Compatibility; no scene files are authored.
## godot --path . -s tools/godot/mesh_preview.gd
## Saves user://mesh_previews/{biped,parts}.png; -- --baseline prefixes filenames.

const IMAGE_SIZE: Vector2i = Vector2i(1600, 1200)
const BACKGROUND: Color = Color(0.035, 0.052, 0.070)
const INK: Color = Color(0.88, 0.93, 0.96)
const MUTED: Color = Color(0.43, 0.56, 0.65)

var _viewport: SubViewport
var _world: Node3D
var _overlay: Control
var _prefix: String = ""


func _initialize() -> void:
	if "--baseline" in OS.get_cmdline_user_args():
		_prefix = "baseline_"
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1000, 750)
	root.title = "ssok mesh preview"
	DirAccess.make_dir_recursive_absolute("user://mesh_previews")
	_create_viewport()
	_biped()
	await _save("biped")
	_world.free()
	_overlay.free()
	_create_world()
	_parts()
	await _save("parts")
	quit()


func _create_viewport() -> void:
	var container: SubViewportContainer = SubViewportContainer.new()
	container.stretch = true
	container.size = Vector2(1000, 750)
	root.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = IMAGE_SIZE
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Keep the export resolution independent of the preview window size.
	root.add_child(_viewport)
	var display: TextureRect = TextureRect.new()
	display.texture = _viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = Vector2(1000, 750)
	container.add_child(display)
	_create_world()


func _create_world() -> void:
	_world = Node3D.new()
	_viewport.add_child(_world)
	_overlay = Control.new()
	_viewport.add_child(_overlay)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.94, 1.0)
	environment.ambient_light_energy = 0.3
	# Metals need a reflection source even with a solid-color studio background.
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.42, 0.48, 0.58)
	sky_material.sky_horizon_color = Color(0.88, 0.9, 0.93)
	sky_material.ground_horizon_color = Color(0.88, 0.9, 0.93)
	sky_material.ground_bottom_color = Color(0.22, 0.24, 0.28)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	_light(Vector3(-35, -35, 0), Color(1.0, 0.96, 0.9), 0.85, true)
	_light(Vector3(-25, 130, 0), Color(0.8, 0.88, 1.0), 0.35, false)
	_label("ssok", Vector2(75, 48), 54, INK)
	_label("ROBOT PARTS / BLENDER → GODOT", Vector2(77, 111), 17, MUTED)


func _light(rotation: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadows
	light.directional_shadow_max_distance = 3.0
	_world.add_child(light)


func _biped() -> void:
	var graph: ConnectionGraph = BipedPreset.build()
	for entry: Dictionary in graph.parts:
		var definition: PartDef = entry.part_def
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = definition.mesh
		_world.add_child(mesh)
		mesh.transform = entry.transform
	var floor: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor.mesh = plane
	floor.position.y = BipedPreset.FLOOR_TOP - 0.0002
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.055, 0.078, 0.095)
	material.roughness = 0.95
	floor.material_override = material
	_world.add_child(floor)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.32
	camera.near = 0.001
	camera.far = 10.0
	_world.add_child(camera)
	camera.look_at_from_position(Vector3(0.30, 0.275, 0.52), Vector3(0, 0.14, -0.015))
	_label("BIPED / ASSEMBLY", Vector2(75, 1040), 31, INK)
	_label("11 parts · 4 servo joints · ultrasonic sensor · Arduino Uno", Vector2(77, 1091), 21, MUTED)
	_label("Actual project meshes · GL Compatibility", Vector2(1075, 1110), 16, MUTED)


func _parts() -> void:
	var directory: DirAccess = DirAccess.open("res://assets/parts")
	var filenames: PackedStringArray = directory.get_files()
	filenames.sort()
	var definitions: Array[PartDef] = []
	for filename: String in filenames:
		if filename.ends_with(".tres"):
			definitions.append(load("res://assets/parts/" + filename) as PartDef)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.2
	camera.near = 0.001
	_world.add_child(camera)
	camera.position = Vector3(0, 0, 2)
	var rows: int = ceili(definitions.size() / 4.0)
	var row_height: float = 890.0 / rows
	for index: int in definitions.size():
		var definition: PartDef = definitions[index]
		var column: int = index % 4
		var row: int = index / 4
		var row_top: float = 225 + row * row_height
		var label_position: Vector2 = Vector2(75 + column * 370, row_top + row_height * 0.75)
		var image_top: float = row_top + 18.0
		var image_height: float = label_position.y - 20.0 - image_top
		var center: Vector2 = Vector2(245 + column * 370, image_top + image_height * 0.5)
		var holder: Node3D = Node3D.new()
		holder.rotation_degrees = Vector3(35, -30, 0)
		var bounds: AABB = definition.mesh.get_aabb()
		# Rotated brackets project taller than their unrotated longest dimension.
		var projected_bounds: AABB = Transform3D(holder.basis, Vector3.ZERO) * AABB(-bounds.size * 0.5, bounds.size)
		var fitted_scale: float = minf(0.290 / projected_bounds.size.x, image_height * 0.001 / projected_bounds.size.y)
		holder.scale = Vector3.ONE * fitted_scale
		holder.position = Vector3((center.x - 800) * 0.001, (600 - center.y) * 0.001, 0)
		_world.add_child(holder)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = definition.mesh
		mesh.position = -bounds.get_center()
		holder.add_child(mesh)
		_label(definition.display_name, label_position, 23, INK)
		_label("%s · %d ports" % [definition.id, definition.ports.size()], label_position + Vector2(0, 34), 17, MUTED)
	_label("%02d MODULAR PARTS" % definitions.size(), Vector2(1190, 82), 21, INK)
	_label("Individual parts shown at fitted scale · Actual imported materials", Vector2(75, 1140), 18, MUTED)


func _label(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_overlay.add_child(label)


func _save(name: String) -> void:
	for frame: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "user://mesh_previews/%s%s.png" % [_prefix, name]
	var error: Error = _viewport.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save preview: %s (%s)" % [path, error_string(error)])
		quit(1)
	print("saved ", ProjectSettings.globalize_path(path))
