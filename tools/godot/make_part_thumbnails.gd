extends SceneTree

## Renders one transparent picture per tray part from its real mesh, for the parts tray.
## Needs a real display (not --headless), from the repository root:
##   godot --path . --resolution 384x384 -s tools/godot/make_part_thumbnails.gd
## Pictures are written to res://assets/part_thumbnails/<part id>.png at 128x128.

const OUTPUT: String = "res://assets/part_thumbnails/"
const RENDER: int = 384
const SIZE: int = 128


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(RENDER, RENDER)
	root.transparent_bg = true
	var catalog: Array[PartDef] = []
	for directory: String in ["res://assets/parts/", "res://assets/construction_kit/parts/", "res://assets/power/parts/"]:
		for file: String in DirAccess.get_files_at(directory):
			if file.ends_with(".tres"):
				var definition: PartDef = load(directory + file) as PartDef
				if definition != null:
					catalog.append(definition)
	catalog = PartTray.definitions(catalog)

	var stage := Node3D.new()
	root.add_child(stage)
	# Metal parts need something to reflect; the sky lights them but is not drawn.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("e9edf2")
	sky_material.sky_horizon_color = Color("f7f8fa")
	sky_material.ground_horizon_color = Color("f7f8fa")
	sky_material.ground_bottom_color = Color("c9ced6")
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	key.light_energy = 0.75
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
	fill.light_energy = 0.2
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 28.0
	stage.add_child(camera)
	camera.make_current()
	var holder := MeshInstance3D.new()
	stage.add_child(holder)

	var written: int = 0
	for definition: PartDef in catalog:
		if definition.mesh == null:
			continue
		holder.mesh = definition.mesh
		# Show the part as it rests on the bench.
		holder.basis = AssemblyMode.resting_basis(definition)
		var box: AABB = holder.transform * definition.mesh.get_aabb()
		var center: Vector3 = box.get_center()
		var radius: float = maxf(box.size.length() * 0.5, 0.005)
		# Long thin parts would otherwise be a sliver in the middle of the picture.
		var longest: float = box.size[box.size.max_axis_index()]
		if longest > 3.0 * (box.size.x + box.size.y + box.size.z - longest):
			radius *= 0.62
		var distance: float = radius / sin(deg_to_rad(camera.fov * 0.5)) * 1.05
		camera.near = distance * 0.05
		camera.far = distance * 4.0
		camera.look_at_from_position(center + Vector3(0.9, 0.85, 1.0).normalized() * distance, center, Vector3.UP)
		for index: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		if image.save_png(OUTPUT + String(definition.id) + ".png") == OK:
			written += 1
	print("make_part_thumbnails: ", written, " of ", catalog.size())
	quit(0 if written == catalog.size() else 1)
