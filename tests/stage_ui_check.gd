extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._load_preset(ServoArmPreset.build_microbit(), ServoArmPreset.microbit_code(), "")
	main.assembly.spawn_part(load("res://assets/parts/arm_link.tres"), Transform3D(Basis.IDENTITY, Vector3(-0.2, 0.1, 0)))
	main.program_tabs.current_tab = 4
	var folder: String = "user://stage_contract_previews"
	DirAccess.make_dir_recursive_absolute(folder)
	for locale: String in ["en", "ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(locale, false)
		main.stages._refresh_targets()
		_check(main.stages._target.item_count == main.assembly.graph.parts.size(), "each target instance is listed: " + locale)
		for cause: String in ["target_ambiguous", "user_stop", "sensor_missing", "program_error"]:
			main.stages.evaluator.reason = cause
			main.stages._show_result()
			for tick: int in 3:
				await process_frame
			_check(not main.stages._status.text.is_empty(), "recovery message displayed: " + locale + ":" + cause)
			_check(main.stages._status.get_rect().size.y >= main.stages._status.get_minimum_size().y, "wrapped message is not vertically clipped: " + locale + ":" + cause)
			if "--screenshots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder.path_join(locale + "_" + cause + ".png"))
	main.free()
	await process_frame
	await process_frame
	print("stage_ui_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
