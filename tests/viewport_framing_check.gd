extends SceneTree

var _main: Node3D
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.gui_embed_subwindows = true
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	var graphs: Array[ConnectionGraph] = [BipedPreset.build(), ConstructionKitHumanoidPreset.build()]
	var side_board: Transform3D = graphs[0].parts[10].transform
	side_board.origin.x = 0.5
	graphs[0].parts[10].transform = side_board
	for dimensions: Vector2i in [Vector2i(1440, 900), Vector2i(960, 640)]:
		root.size = dimensions
		for locale: String in ["en", "ko", "zh_CN", "ja"]:
			SsokLocale.select_locale(locale, false)
			await process_frame
			await process_frame
			for index: int in graphs.size():
				var graph: ConnectionGraph = graphs[index]
				var before: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
				_main._load_preset(graph, "", "")
				await process_frame
				_check_parts_visible(graph, locale)
				_check(MotionSnapshot.fingerprint(_main._motion_snapshot()) == before, "framing preserves the authored graph")
				if index == 0:
					await _capture("%s-%dx%d" % [locale, dimensions.x, dimensions.y])
	await _check_resize(graphs[0])
	_main.free()
	await process_frame
	print("viewport_framing_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check_resize(graph: ConnectionGraph) -> void:
	var camera: Camera3D = _main.get_node("Camera3D") as Camera3D
	for projection: Camera3D.ProjectionType in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		root.size = Vector2i(1440, 900)
		await process_frame
		await process_frame
		_main._load_preset(graph, "", "")
		root.size = Vector2i(960, 640)
		await process_frame
		await process_frame
		_check_parts_visible(graph, "resize without reloading")
		_main.navigation._pan(Vector2(15, 12))
		_main.navigation._orbit(Vector2(18, -10))
		_main.navigation._zoom(-0.2)
		var pivot: Vector3 = _main.navigation.pivot
		var basis: Basis = camera.global_basis
		var distance: float = _main.navigation._distance
		var view_size: float = camera.size
		root.size = Vector2i(1440, 900)
		await process_frame
		await process_frame
		_check(_main.navigation.pivot.is_equal_approx(pivot) and camera.global_basis.is_equal_approx(basis), "resize preserves custom pan and orbit")
		root.size = Vector2i(960, 640)
		await process_frame
		await process_frame
		_check(is_equal_approx(_main.navigation._distance, distance) and is_equal_approx(camera.size, view_size), "resize round trip preserves custom zoom")


func _check_parts_visible(graph: ConnectionGraph, locale: String) -> void:
	var camera: Camera3D = _main.get_node("Camera3D") as Camera3D
	var excluded: Array[Rect2] = []
	for name: String in ["PartsLibrary", "ProgramPanel", "ViewportTools", "WorkspaceHeader"]:
		excluded.append((_main._ui_root.get_node(name) as Control).get_global_rect())
	for entry: Dictionary in graph.parts:
		var definition: PartDef = entry.part_def
		for index: int in 8:
			var point: Vector3 = entry.transform * definition.mesh.get_aabb().get_endpoint(index)
			var screen: Vector2 = camera.unproject_position(point)
			_check(not camera.is_position_behind(point) and root.get_visible_rect().has_point(screen), locale + " actual part is visible in the window")
			for panel: Rect2 in excluded:
				_check(not panel.has_point(screen), locale + " actual part stays clear of the UI panels")


func _capture(name: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://frame_previews")
	_check(root.get_texture().get_image().save_png("user://frame_previews/" + name + ".png") == OK, "capture " + name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
