extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Use: -- requests.json results.json [--allow-edits]")
		quit(1)
		return
	var input: String = FileAccess.get_file_as_string(args[0])
	var requests: Variant = JSON.parse_string(input) if input.to_utf8_buffer().size() <= 1048576 else null
	if not requests is Array or requests.size() > 100:
		quit(1)
		return
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var controller := AppController.new()
	controller.app = main
	controller.allow_edits = "--allow-edits" in args
	var results: Array = []
	for request: Variant in requests:
		if not request is Dictionary or not request.get("tool") is String or not request.get("args", {}) is Dictionary:
			results.append({"error": "invalid_request"})
			continue
		var revision: Variant = request.get("expected_revision", -1)
		if not MotionSnapshot._is_integer(revision):
			results.append({"error": "invalid_revision"})
			continue
		results.append(controller.invoke(request.tool, request.get("args", {}), int(revision)))
		var ticks: Variant = request.get("observe_ticks", 0)
		if MotionSnapshot._is_integer(ticks) and ticks >= 0 and ticks <= 3600:
			for tick: int in int(ticks):
				await physics_frame
	var file: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(results, "  "))
	main.free()
	quit()
