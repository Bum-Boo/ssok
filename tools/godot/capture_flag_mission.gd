extends SceneTree

const OUTPUT: String = "res://build/flag_mission"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SsokLocale.select_locale("ko", false)
	await process_frame
	await _capture("01-start")
	main.flag_mission._action.pressed.emit()
	await process_frame
	await _capture("02-ready")
	main.run_button.pressed.emit()
	for frame: int in 480:
		await physics_frame
		if main.flag_mission._phase == &"Success":
			break
	await _capture("03-success")
	print("capture_flag_mission: phase=", main.flag_mission._phase)
	main.flag_mission._sound.stop()
	main.flag_mission._sound.stream = null
	main.free()
	await process_frame
	quit()


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var mission: FlagMission = root.get_node("Main").flag_mission
	print("FLAG_LAYOUT ", name, " rect=", mission.get_global_rect(), " minimum=", mission.get_combined_minimum_size())
	var folder: String = ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var image: Image = root.get_texture().get_image()
	var destination: String = folder.path_join(name + ".png")
	var error: Error = image.save_png(destination)
	if error != OK:
		push_error("Could not save flag mission screenshot: " + destination)
