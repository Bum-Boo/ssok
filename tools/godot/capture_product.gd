extends SceneTree

## Capture the actual workshop for product documentation; no synthetic UI or motion.
var _main: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Product screenshots require the GL renderer")
		quit(1)
		return
	root.size = Vector2i(1600, 1000)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	SsokLocale.select_locale("en", false)
	_main._on_modular_pressed()
	_main.program_tabs.current_tab = 0
	await _capture("workshop")
	_main._on_answer_pressed()
	_main.program_tabs.current_tab = 2
	await _capture("blocks")
	_main._on_kit_bridge_pressed()
	await _capture("bridge")
	_main.free()
	quit()


func _capture(name: String) -> void:
	for frame: int in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://release_media")
	var error: Error = root.get_texture().get_image().save_png("user://release_media/" + name + ".png")
	if error != OK:
		push_error("Capture failed: " + name)
