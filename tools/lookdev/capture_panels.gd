extends SceneTree

## Captures the docked workshop panels in free building, in Korean.
##   godot --path . --resolution 1440x900 -s tools/lookdev/capture_panels.gd
## Images are written to user://lookdev/panels-<shot>.png.


func _initialize() -> void:
	_run.call_deferred()


func _settle(frames: int = 10) -> void:
	for index: int in frames:
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://lookdev/panels-%s.png" % name)


func _key(main: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	main._unhandled_key_input(event)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://lookdev")
	root.size = Vector2i(1440, 900)
	var prefs: Node = root.get_node("Preferences")
	prefs.values.appearance = "light"
	prefs.values.text_scale = 1.0
	SsokLocale.select_locale("ko", false)
	prefs.changed.emit()

	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = {"mode": "lab"}
	root.add_child(main)
	await _settle()
	await _capture("1-empty")

	# Drop a plate on the bench: it should lie flat, the tray stays, the camera stays.
	var plate: PartDef = load("res://assets/construction_kit/parts/kit_plate_120_80.tres")
	var before: Transform3D = main.get_viewport().get_camera_3d().global_transform
	var camera: Camera3D = main.get_viewport().get_camera_3d()
	var screen: Vector2 = Vector2(760, 560)
	main.assembly.begin_place(plate)
	main.assembly.update_place_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	var index: int = main.assembly.commit_place()
	await _settle()
	var after: Transform3D = main.get_viewport().get_camera_3d().global_transform
	print("panels: placed=", index, " camera_moved=", not before.is_equal_approx(after),
		" tray_visible=", main._ui_root.get_node("PartsLibrary").visible, " side_visible=", main._side_panel.visible)
	await _capture("2-plate-placed")

	_key(main, KEY_N)
	await _settle()
	print("panels: after N tray=", main._ui_root.get_node("PartsLibrary").visible, " side=", main._side_panel.visible)
	await _capture("3-both-panels")

	_key(main, KEY_H)
	await _settle()
	await _capture("4-cinema")
	_key(main, KEY_H)
	await _settle()
	print("panels: after cinema tray=", main._ui_root.get_node("PartsLibrary").visible, " side=", main._side_panel.visible, " hud=", main.stage_hud.visible)
	main.free()
	await _settle()
	quit(0)
