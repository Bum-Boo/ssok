extends SceneTree

## Renders one picture per tray part from its real mesh, for the parts tray and
## for auditing the models. Run with a real display:
##   godot --path . --resolution 320x320 -s tools/lookdev/thumbnails.gd
## Images are written to user://lookdev/parts/<part id>.png.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://lookdev/parts")
	root.size = Vector2i(320, 320)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = {"mode": "lab"}
	root.add_child(main)
	for index: int in 5:
		await process_frame
	var catalog: Array[PartDef] = PartTray.definitions(main._part_catalog)
	main.free()
	for index: int in 3:
		await process_frame

	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("f4f5f6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffffff")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	key.light_color = Color("fff6ea")
	key.light_energy = 1.0
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
	fill.light_energy = 0.35
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 28.0
	stage.add_child(camera)
	camera.make_current()
	var holder := MeshInstance3D.new()
	stage.add_child(holder)

	for definition: PartDef in catalog:
		if definition.mesh == null:
			continue
		holder.mesh = definition.mesh
		var box: AABB = definition.mesh.get_aabb()
		var center: Vector3 = box.get_center()
		var radius: float = maxf(box.size.length() * 0.5, 0.005)
		var direction: Vector3 = Vector3(0.9, 0.75, 1.0).normalized()
		var distance: float = radius / sin(deg_to_rad(camera.fov * 0.5)) * 1.08
		camera.near = distance * 0.05
		camera.far = distance * 4.0
		camera.look_at_from_position(center + direction * distance, center, Vector3.UP)
		for index: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://lookdev/parts/%s.png" % definition.id)
	print("thumbnails: ", catalog.size())
	quit(0)
