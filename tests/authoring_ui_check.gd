extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_answer_pressed()
	for locale: String in ["en", "ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(locale, false)
		main.program_tabs.current_tab = 2
		await process_frame
		await process_frame
		_check(main.blocks.rows.get_child_count() > 0, "actual program blocks visible in " + locale)
		_check(Rect2(Vector2.ZERO, root.size).encloses(main.projects_button.get_global_rect()), "projects action inside viewport")
		await _capture(locale + "-blocks", root)
		main._open_projects()
		main.projects.tabs.current_tab = 0
		await process_frame
		_check(main.projects.visible, "project panel opens in " + locale)
		_check(main.projects.size.x <= root.size.x and main.projects.size.y <= root.size.y, "project panel fits")
		await _capture(locale + "-projects", main.projects)
		main.projects.export_current()
		await process_frame
		_check(ProjectStore.parse(main.projects.transfer_edit.text).source == main.code_edit.text, "export contains learner source")
		await _capture(locale + "-share", main.projects)
		main.projects.close_panel()
		root.size = Vector2i(1152, 577)
		await process_frame
		await process_frame
		_check(Rect2(Vector2.ZERO, root.size).encloses(main.language_picker.get_global_rect()), "header fits compact screen in " + locale)
		_check(main._parts_scroll.size.y >= 100, "catalog keeps usable height on short browser viewport")
		_check(main.blocks.scroll.size.y >= 120, "block editor keeps a usable scrolling viewport")
		await _capture(locale + "-compact", root)
		root.size = Vector2i(1280, 800)
	main.free()
	print("authoring_ui_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _capture(name: String, viewport: Viewport) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://authoring_previews")
	_check(viewport.get_texture().get_image().save_png("user://authoring_previews/" + name + ".png") == OK, "capture " + name)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + description)
