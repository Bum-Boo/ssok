extends SceneTree

## Captures the menu screens in Korean: user://lookdev/menu-<name>.png.
##   godot --path . --resolution 1440x900 -s tools/lookdev/capture_menus.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://lookdev")
	root.size = Vector2i(1440, 900)
	var prefs: Node = root.get_node("Preferences")
	prefs.values.appearance = "light"
	prefs.values.text_scale = 1.0
	SsokLocale.select_locale("ko", false)
	SsokTheme.configure(false, 1.0, 1.0)
	for name: String in ["stage_select", "title"]:
		var screen: Control = load("res://scenes/screens/%s.tscn" % name).instantiate()
		root.add_child(screen)
		for index: int in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://lookdev/menu-%s.png" % name)
		screen.free()
		await process_frame
	quit(0)
