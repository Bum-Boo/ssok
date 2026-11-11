extends SceneTree

## Captures the tier 1 power behaviour in free building, in Korean:
## an unwired battery (the reason appears), then the wired robot running.
##   godot --path . --resolution 1440x900 -s tools/lookdev/capture_power.gd
## Images are written to user://lookdev/power-<shot>.png.


func _initialize() -> void:
	_run.call_deferred()


func _settle(frames: int = 8) -> void:
	for index: int in frames:
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://lookdev/power-%s.png" % name)


func _index(graph: ConnectionGraph, id: StringName) -> int:
	for part: int in graph.parts.size():
		if graph.parts[part].part_def.id == id:
			return part
	return -1


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

	var graph: ConnectionGraph = KitCarPreset.build()
	var holder: PartDef = load("res://assets/power/parts/battery_holder_4aa.tres")
	graph.parts.append({"part_def": holder, "transform": graph.parts[0].transform.translated(Vector3(-0.02, 0.03, 0))})
	main._load_preset(graph, RobotCarPreset.ANSWER_CODE, "")
	await _settle()
	main.navigation.frame_bounds(main.assembly.get_scene_bounds())
	main.stage_hud.program_requested.emit()
	main.program_tabs.current_tab = 3
	await _settle(20)
	await _capture("1-battery-unwired")

	# Run with the battery not connected: the reason must appear.
	main.run_button.pressed.emit()
	await _settle(20)
	await _capture("2-run-without-power")
	if main.mode_button.button_pressed:
		main.mode_button.button_pressed = false
	await _settle()

	var live: ConnectionGraph = main.assembly.graph
	var battery: int = _index(live, &"battery_holder_4aa")
	var driver: int = _index(live, &"motor_driver")
	var board: int = _index(live, &"microbit")
	var sonar: int = _index(live, &"hc_sr04")
	print("power wires: ", main.assembly.connect_wire(battery, &"power_out", driver, &"power_in"), " ",
		main.assembly.connect_wire(driver, &"power_out", board, &"power_in"), " ",
		main.assembly.connect_wire(board, &"power_out_1", sonar, &"power_in"))
	await _settle(12)
	await _capture("3-battery-wired")

	main.run_button.pressed.emit()
	for tick: int in 90:
		await physics_frame
	await _settle(4)
	await _capture("4-run-with-power")
	print("power problems after wiring: ", main.run_mode.power_problems())
	main.free()
	await _settle()
	quit(0)
