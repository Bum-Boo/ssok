extends SceneTree

## Look-development capture. Renders the same workshop moments so that visual
## changes can be compared picture against picture. Run with a real display:
##   godot --path . --resolution 1440x900 -s tools/lookdev/capture.gd -- <tag>
## Images are written to user://lookdev/<tag>-<shot>.png.

var tag: String = "shot"
var look: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _settle(frames: int = 8) -> void:
	for index: int in frames:
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://lookdev/%s-%s.png" % [tag, name])


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		tag = args[0]
	look = "look" in args
	DirAccess.make_dir_recursive_absolute("user://lookdev")
	root.size = Vector2i(1440, 900)
	var prefs: Node = root.get_node("Preferences")
	prefs.values.appearance = "light"
	prefs.values.text_scale = 1.0
	SsokLocale.select_locale("ko", false)
	prefs.changed.emit()

	var level: Dictionary = StageLevels.find("finish-line")
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = {"mode": "stage", "level": level}
	root.add_child(main)
	if look:
		LookDev.apply(main)
	await _settle()
	# 1. Empty bench with the tray open: what a learner sees first.
	await _capture("1-empty")

	# 2. The kit answer car on the bench, tray open: the assembly moment.
	var definition: Variant = StageLevels.stage_definition(level)
	main._load_preset(StageLevels.starting_graph(level, definition), definition.author_solution.source, "")
	if look:
		LookDev._surfaces(main)
	await _settle()
	if not main._ui_root.get_node("PartsLibrary").visible:
		main.stage_hud.parts_requested.emit()
	await _settle()
	await _capture("2-build")

	# 3. Close on the robot: the model itself.
	main.navigation.frame_bounds(main.assembly.get_scene_bounds())
	await _settle(20)
	await _capture("3-robot")
	main._ui_root.visible = false
	await _settle(3)
	await _capture("3-robot-clean")
	main._ui_root.visible = true

	# 4. Program panel open on blocks.
	main.stage_hud.program_requested.emit()
	main.program_tabs.current_tab = 2
	await _settle()
	await _capture("4-blocks")
	main.program_tabs.current_tab = 3
	await _settle()
	await _capture("5-wiring")
	if look:
		print("lookdev materials: ", LookDev.seen)
	main.free()
	await _settle()
	quit(0)
