extends SceneTree

## Fixed-camera look comparison. The same cameras are used before and after a look change, so
## the pictures can be laid side by side. Run with a real display (GL Compatibility):
##   godot --path . --rendering-method gl_compatibility --resolution 1440x900 \
##     -s tools/lookdev/capture_look.gd -- <absolute output dir> <prefix> [vfx]
## Writes <prefix>-robot-light.png, <prefix>-robot-dark.png, <prefix>-workbench.png,
## <prefix>-workbench-dark.png and, with "vfx", <prefix>-vfx-led-sonar.png and <prefix>-vfx-snap.png.

## Pivot, yaw/pitch in degrees and distance in metres for BlenderCamera.
const ROBOT_VIEW: Dictionary = {"pivot": Vector3(0.0, 0.085, 0.0), "yaw": 38.0, "pitch": 26.0, "distance": 0.44}
const BENCH_VIEW: Dictionary = {"pivot": Vector3(0.3, 0.05, 0.0), "yaw": 24.0, "pitch": 38.0, "distance": 2.05}
const SNAP_VIEW: Dictionary = {"pivot": Vector3(0.0, 0.09, 0.0), "yaw": 30.0, "pitch": 42.0, "distance": 0.4}
const VFX_VIEW: Dictionary = {"pivot": Vector3(0.16, 0.09, 0.0), "yaw": 20.0, "pitch": 26.0, "distance": 0.5}

var out_dir: String = ""
var prefix: String = "shot"
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _settle(frames: int = 8) -> void:
	for index: int in frames:
		await process_frame


func _place_camera(main: Node3D, view: Dictionary) -> void:
	main._auto_frame = false
	var navigation: BlenderCamera = main.navigation
	navigation.pivot = view.pivot
	navigation._yaw = deg_to_rad(view.yaw)
	navigation._pitch = deg_to_rad(view.pitch)
	navigation._distance = view.distance
	navigation._apply_view()
	var camera: Camera3D = main.get_node("Camera3D")
	camera.h_offset = 0.0
	camera.v_offset = 0.0


func _capture(main: Node3D, view: Dictionary, shot: String) -> void:
	_place_camera(main, view)
	await _settle(4)
	_place_camera(main, view)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join("%s-%s.png" % [prefix, shot])
	if image == null or image.is_empty() or image.save_png(path) != OK:
		failures += 1
		push_error("capture failed: " + path)
		return
	print("captured %s %dx%d" % [path, image.get_width(), image.get_height()])


func _appearance(dark: bool) -> void:
	var prefs: Node = root.get_node("Preferences")
	prefs.values.appearance = "dark" if dark else "light"
	prefs.changed.emit()
	await _settle(6)


func _open(session: Dictionary) -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = session
	root.add_child(main)
	await _settle()
	main._ui_root.visible = false
	return main


func _close(main: Node3D) -> void:
	main.free()
	await _settle(4)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <absolute output dir> <prefix> [vfx]")
		quit(2)
		return
	out_dir = args[0]
	prefix = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1440, 900)
	var prefs: Node = root.get_node("Preferences")
	prefs.values.text_scale = 1.0
	SsokLocale.select_locale("ko", false)
	await _appearance(false)

	# Robot close-ups and the whole bench use the finish-line stage with its answer car.
	var level: Dictionary = StageLevels.find("finish-line")
	var definition: Dictionary = StageLevels.stage_definition(level)
	var main: Node3D = await _open({"mode": "stage", "level": level})
	main._load_preset(StageLevels.starting_graph(level, definition), definition.author_solution.source, "")
	await _settle(12)
	main._ui_root.visible = false
	await _capture(main, ROBOT_VIEW, "robot-light")
	await _capture(main, BENCH_VIEW, "workbench")
	await _appearance(true)
	await _capture(main, ROBOT_VIEW, "robot-dark")
	await _capture(main, BENCH_VIEW, "workbench-dark")
	await _appearance(false)
	await _close(main)

	if "vfx" in args:
		await _capture_vfx()
		await _capture_snap()
	quit(1 if failures else 0)


## Lab bench: the kit car with an LED on its deck and a wall ahead of its sonar, running.
func _capture_vfx() -> void:
	var main: Node3D = await _open({"mode": "lab"})
	var graph: ConnectionGraph = KitCarPreset.build(0.42)
	var led_def: PartDef = load("res://assets/construction_kit/parts/kit_led.tres")
	var sonar: int = -1
	for index: int in graph.parts.size():
		if graph.parts[index].part_def.id == &"hc_sr04":
			sonar = index
	# Every micro:bit pin already drives the car; run mode lights any LED part directly.
	graph.parts.append({"part_def": led_def, "transform": Transform3D(Basis.IDENTITY, Vector3(0.075, 0.106, 0.045))})
	var led: int = graph.parts.size() - 1
	main._load_preset(graph, "", "")
	await _settle(6)
	main._ui_root.visible = false
	main.mode_button.button_pressed = true
	await _settle(30)
	var run_mode: RunMode = main.run_mode
	if run_mode.leds.has(led):
		run_mode.leds[led].on()
	else:
		failures += 1
		push_error("vfx capture: LED device missing")
	var sensor: SonarSensor = run_mode.sonar_for_part(sonar)
	for frame: int in 20:
		if sensor != null:
			sensor.distance_cm()
		await process_frame
	if sensor == null or not sensor.last_valid:
		failures += 1
		push_error("vfx capture: sonar did not observe the wall")
	await _capture(main, VFX_VIEW, "vfx-led-sonar")
	main.mode_button.button_pressed = false
	await _close(main)


## A short beam carried over the car's deck: free-hole rings, the snap target and the ghost.
func _capture_snap() -> void:
	var main: Node3D = await _open({"mode": "lab"})
	main._load_preset(KitCarPreset.build(0.0), "", "")
	await _settle(6)
	main._ui_root.visible = false
	_place_camera(main, SNAP_VIEW)
	var assembly: AssemblyMode = main.assembly
	if not assembly.begin_place(load("res://assets/construction_kit/parts/kit_beam_60.tres")):
		failures += 1
		push_error("snap capture: placement did not start")
	var camera: Camera3D = main.get_node("Camera3D")
	# Aim at the free hole drawn nearest a fixed spot on screen (the deck's near edge), as the
	# pointer would; ports facing away from the camera are skipped.
	var screen_target := Vector2(860, 605)
	var best: float = INF
	var aim := Vector3.ZERO
	for entry: Dictionary in main._port_indicators._free_ports:
		var pose: Transform3D = assembly.global_transform * assembly.graph.parts[entry.part].transform
		var port: Port = entry.port
		var point: Vector3 = pose * port.local_position
		if (pose.basis * port.local_normal).dot(camera.global_position - point) <= 0.0:
			continue
		var distance: float = camera.unproject_position(point).distance_to(screen_target)
		if distance < best:
			best = distance
			aim = point
	assembly.update_place_ray(camera.global_position, (aim - camera.global_position).normalized())
	await _settle(6)
	if int(assembly.placement_state().get("target_part", -1)) < 0:
		push_warning("snap capture: no snap target under the aimed point")
	await _capture(main, SNAP_VIEW, "vfx-snap")
	assembly.cancel_place()
	await _close(main)
