extends SceneTree

var _files: Array[String] = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or not ProjectSettings.load_resource_pack(args[0]):
		push_error("Expected a readable export pack and output manifest path")
		quit(1)
		return
	_scan("res://")
	_files.sort()
	var output: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify(_files, "  ") + "\n")
	var failures: int = 0
	for path: String in _files:
		if path.begins_with("res://tools/") or path.begins_with("res://tests/") or path.begins_with("res://docs/") or path.begins_with("res://build/") or ".blend" in path or path.get_file().begins_with(".env"):
			push_error("Development-only resource included in export: " + path)
			failures += 1
	if not ResourceLoader.exists("res://scenes/main.tscn"):
		push_error("Missing application scene")
		failures += 1
	print("Export resource audit: %d files, %d failures" % [_files.size(), failures])
	quit(1 if failures else 0)


func _scan(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for file: String in directory.get_files():
		_files.append(path.path_join(file))
	for child: String in directory.get_directories():
		_scan(path.path_join(child))
