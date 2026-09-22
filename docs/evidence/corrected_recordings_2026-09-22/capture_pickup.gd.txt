extends SceneTree

## Record a native-speed, rendered physics episode with its measured result.
var _trial: PickupTrial
var _result: Dictionary = {}
var _render_fps: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Pickup recording requires the GL renderer")
		quit(1)
		return
	if not OS.has_feature("movie"):
		push_error("Use --write-movie and --fixed-fps to record native-speed evidence")
		quit(1)
		return
	await process_frame
	await process_frame
	_render_fps = roundi(1.0 / root.get_process_delta_time())
	root.size = Vector2i(1280, 720)
	_trial = PickupTrial.new()
	root.add_child(_trial)
	_trial.completed.connect(func(result: Dictionary) -> void: _result = result)
	var error: String = _trial.start_trial(ConstructionKitHumanoidPreset.build(), PickupPolicy.defaults(), true)
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	_trial.viewport.size = root.size
	_prepare_capture_view()
	var image: TextureRect = TextureRect.new()
	image.texture = _trial.viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(image)
	var completed_frames: int = 0
	var captured_frames: int = 0
	for frame: int in range(720):
		await physics_frame
		captured_frames = frame + 1
		if not _result.is_empty():
			completed_frames += 1
			if completed_frames >= 60:
				break
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://release_media")
	root.get_texture().get_image().save_png("user://release_media/pickup.png")
	var record: Dictionary = {
		"schema": 1,
		"engine_version": Engine.get_version_info().string,
		"physics_hz": Engine.physics_ticks_per_second,
		"render_fps": _render_fps,
		"playback_speed": 1.0,
		"capture_clock_seconds": float(captured_frames) / Engine.physics_ticks_per_second,
		"retained_result_seconds": float(completed_frames) / Engine.physics_ticks_per_second,
		"episode": _result,
	}
	var output: FileAccess = FileAccess.open("user://release_media/pickup.metrics.json", FileAccess.WRITE)
	if output == null:
		push_error("Could not write pickup measurement evidence")
		quit(1)
		return
	output.store_string(JSON.stringify(record, "\t") + "\n")
	output.close()
	print("pickup_recording_metrics: " + JSON.stringify(record))
	var success: bool = not _result.is_empty() and _result.metrics.success
	_trial.free()
	quit(0 if success else 1)


func _prepare_capture_view() -> void:
	for node: Node in _trial.viewport.get_children():
		if node is WorldEnvironment:
			var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
			sky_material.sky_top_color = Color("7189a8")
			sky_material.sky_horizon_color = Color("dde5ef")
			sky_material.ground_bottom_color = Color("344358")
			sky_material.ground_horizon_color = Color("cbd5e3")
			var sky: Sky = Sky.new()
			sky.sky_material = sky_material
			node.environment.sky = sky
			node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			node.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
			node.environment.ambient_light_energy = 0.8
		if node is DirectionalLight3D:
			node.light_energy = 1.0
		if node is Camera3D:
			node.position = Vector3(0.95, 0.90, 1.70)
			node.fov = 40.0
			node.look_at(Vector3(0.0, 0.52, 0.07))
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(-1.5, 1.3, 1.0)
	fill.light_energy = 0.55
	fill.omni_range = 5.0
	_trial.viewport.add_child(fill)
