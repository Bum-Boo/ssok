extends SceneTree

## Actual GL UI and real mock-provider physics results; no generated success fixture.

var _main: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	root.gui_embed_subwindows = true
	root.msaa_3d = Viewport.MSAA_4X
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	_main.biped_button.pressed.emit()
	_main.motion_lab_button.pressed.emit()
	var panel: MotionLabPanel = _main.motion_lab
	panel.token_edit.text = OS.get_environment("SSOK_UI_TEST_TOKEN")
	panel.endpoint_edit.text = OS.get_environment("SSOK_UI_TEST_URL")
	panel.check_connection()
	await _wait_client(panel)
	if panel._server.get("provider") != "mock":
		push_error("Screenshot requires an explicitly mock bridge; no live API requests allowed")
		quit(1)
		return
	await _save("motion_lab_setup")
	panel.rounds.value = 1
	panel.start_search()
	var deadline: int = Time.get_ticks_msec() + 120000
	while (str(panel._job.get("state", "")) not in MotionLabPanel.TERMINAL_STATES or panel.client.is_busy()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if panel._job.get("state") != "completed":
		push_error("Mock evaluation did not complete for the screenshot")
		quit(1)
		return
	var scroll: ScrollContainer = panel.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _save("motion_lab_results")
	panel._close_panel()
	_main.free()
	await process_frame
	quit()


func _wait_client(panel: MotionLabPanel) -> void:
	var deadline: int = Time.get_ticks_msec() + 25000
	while panel.client.is_busy() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout


func _save(name: String) -> void:
	for frame: int in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://control_previews")
	var path: String = "user://control_previews/" + name + ".png"
	var error: Error = root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not capture motion lab UI")
	else:
		print("Saved ", ProjectSettings.globalize_path(path))
