extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output: String = "res://build/issues-review/screens"
	DirAccess.make_dir_recursive_absolute(output)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for locale: String in ["en", "ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(locale, false)
		for size: Vector2i in [Vector2i(1440, 900), Vector2i(960, 640)]:
			root.size = size
			main._on_microbit_arm_pressed()
			main.program_tabs.current_tab = 2
			await _capture(output.path_join("%s-%d-flag.png" % [locale, size.x]))
			var stage: Dictionary = StageCatalog.builtins()[2]
			main._load_preset(ProjectStore.graph_from(stage.author_solution), stage.author_solution.source, "")
			main.stages.load_goal(stage)
			main.flag_mission.visible = false
			main.program_tabs.current_tab = 4
			await _capture(output.path_join("%s-%d-stage.png" % [locale, size.x]))
	main.free()
	await process_frame
	quit()

func _capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
