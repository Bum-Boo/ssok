extends SceneTree

## Captures the actual application with GL Compatibility, not a mock UI.
## godot --path . --script tests/controls_screenshot.gd

var _main: Node3D
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	root.title = "ssok controls verification"
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute("user://control_previews")
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	_main.biped_button.pressed.emit()
	root.gui_release_focus()
	await _save("edit")
	_main.control_source.select(_main.CONTROL_MANUAL)
	_main.mode_button.button_pressed = true
	root.gui_release_focus()
	await _key(KEY_W, true)
	if _main.manual_controller.get_move_input().y <= 0.0:
		push_error("Screenshot setup: W did not dispatch forward movement")
		_failed = true
	await _save("run")
	await _key(KEY_W, false)
	if not _main.manual_controller.get_move_input().is_zero_approx():
		push_error("Screenshot setup: released W did not stop input")
		_failed = true
	await _save("run_released")
	_main.mode_button.button_pressed = false
	_main.free()
	await process_frame
	quit(1 if _failed else 0)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _save(name: String) -> void:
	for frame: int in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://control_previews/%s.png" % name
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save screenshot: %s" % error_string(error))
		_failed = true
	else:
		print("saved ", ProjectSettings.globalize_path(path))
