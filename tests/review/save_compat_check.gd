extends SceneTree

## Reads synthetic main-written save data with r3 code and reports any loss or rewrite.
const FIXTURES: String = "res://tests/review/fixtures/main/"

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
		print("FAIL ", message)


func _read(name: String) -> String:
	return FileAccess.get_file_as_string(FIXTURES + name)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _encoded(graph: ConnectionGraph) -> String:
	return JSON.stringify(MotionSnapshot.encode(graph), "", true, true)


func _report_difference(expected: Dictionary, actual: Dictionary) -> void:
	var shown: int = 0
	for index: int in expected.parts.size():
		for component: int in 12:
			var a: float = expected.parts[index].transform[component]
			var b: float = actual.parts[index].transform[component]
			if a != b and shown < 5:
				shown += 1
				print("DIFF part ", index, " ", expected.parts[index].id, " c", component, " main=", String.num_scientific(a), " restored=", String.num_scientific(b), " delta=", String.num_scientific(b - a))


func _run() -> void:
	var keys: Array[String] = ["servo_arm", "servo_arm_microbit", "robot_car", "robot_car_wall", "humanoid", "modular", "kit", "kit_bridge", "biped", "yaw_biped"]
	var projects: Dictionary = {}
	for key: String in keys:
		var text: String = _read("project_%s.json" % key)
		var record: Dictionary = ProjectStore.parse(text)
		_check(not record.is_empty(), key + " main project parses in r3")
		if record.is_empty():
			continue
		projects[key] = record
		_check(_encoded(ProjectStore.graph_from(record)) == _read("encode_%s.json" % key), key + " graph re-encodes identically")
	var arm: ConnectionGraph = ProjectStore.graph_from(projects.servo_arm)
	for part: Dictionary in arm.parts:
		if part.part_def.id == &"arm_link":
			_check(part.part_def.ports[0].id == &"mount_base" and part.part_def.ports.size() == 2, "arm_link keeps mount_base at port index 0")
	for id: String in ["raise-flag", "finish-line", "wall-brake"]:
		var text: String = _read("stage_%s.json" % id)
		var stage: Dictionary = StageDefinition.parse(text)
		_check(not stage.is_empty(), id + " main v2 stage parses")
		if stage.is_empty():
			continue
		_check(StageDefinition.serialize(stage) == text, id + " main v2 stage re-serializes identically")
		var legacy: Dictionary = stage.duplicate(true)
		legacy.version = 1
		for rule: Dictionary in legacy.rules:
			rule.erase("target_index")
		_check(not StageDefinition.parse(JSON.stringify(legacy)).is_empty(), id + " v1 form of main stage parses")
		if id == "wall-brake":
			var wall_kept: bool = false
			for part: Dictionary in ProjectStore.graph_from(stage.scene).parts:
				wall_kept = wall_kept or part.part_def.id == &"stage_wall"
			_check(wall_kept, "legacy stage_wall prop is kept in the imported scene graph")
	# Progress v1 -> v2 with workspaces.
	StageProgress.path = "user://review_progress.json"
	_write(StageProgress.path, _read("progress_main.json"))
	_check(StageProgress.load_cleared() == {"raise-flag": true, "finish-line": true}, "main v1 clears load")
	_check(not StageProgress.cleared_with_solution("raise-flag"), "main v1 clears count as independent")
	for key: String in ["robot_car_wall", "kit", "humanoid", "servo_arm_microbit"]:
		_check(StageProgress.save_workspace("finish-line", projects[key], false) == OK, key + " workspace saves")
		var restored: Dictionary = StageProgress.load_workspace("finish-line")
		_check(not restored.is_empty(), key + " workspace reloads")
		if not restored.is_empty():
			var restored_text: String = _encoded(ProjectStore.graph_from(restored.project))
			_check(restored_text == _read("encode_%s.json" % key), key + " workspace graph round-trips exactly")
			if restored_text != _read("encode_%s.json" % key):
				_report_difference(JSON.parse_string(_read("encode_%s.json" % key)), JSON.parse_string(restored_text))
			_check(restored.project.source == projects[key].source and restored.project.title == projects[key].title, key + " workspace source and title round-trip")
	var lowered: ConnectionGraph = StageLevels.starting_graph(StageLevels.all()[0], StageCatalog.builtins()[0])
	var lowered_record: Dictionary = ProjectStore.document("Lowered", lowered, "x = 1\n")
	StageProgress.save_workspace("raise-flag", lowered_record, true)
	var lowered_back: Dictionary = StageProgress.load_workspace("raise-flag")
	_check(not lowered_back.is_empty() and _encoded(ProjectStore.graph_from(lowered_back.project)) == _encoded(lowered), "rotated stage workspace round-trips exactly")
	_check(StageProgress.load_cleared().size() == 2, "workspace saves keep v1 clears")
	_check(not FileAccess.file_exists(StageProgress.path + ".tmp"), "no temporary file is left after save")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StageProgress.path))
	_check(saved.version == 2 and saved.workspaces.has("stage:finish-line"), "written file is v2 with stage:<id> keys")
	# Unknown keys survive rewrite.
	saved["future_key"] = {"a": 1}
	saved.cleared["odd"] = "yes"
	_write(StageProgress.path, JSON.stringify(saved))
	StageProgress.mark_cleared("wall-brake")
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StageProgress.path))
	_check(after.has("future_key") and after.cleared.get("odd") == "yes", "unknown progress keys are preserved")
	# A non-bool clear value raises a script error inside load_cleared (same comparison as main).
	print("NON_BOOL_CLEAR load_cleared=", StageProgress.load_cleared())
	# Corrupt and partial files.
	var good: String = FileAccess.get_file_as_string(StageProgress.path)
	_write(StageProgress.path, good.left(good.length() / 2))
	_check(StageProgress.load_cleared().is_empty() and StageProgress.load_workspace("finish-line").is_empty(), "truncated progress reads as empty without crashing")
	StageProgress.mark_cleared("raise-flag")
	var rewritten: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StageProgress.path))
	print("CORRUPT_THEN_CLEAR cleared=", rewritten.cleared.keys(), " workspaces=", rewritten.workspaces.keys())
	_write(StageProgress.path, '{"format":"ssok-progress","version":2,"cleared":{"a":true},"solutions":[],"workspaces":"bad"}')
	_check(StageProgress.is_cleared("a") and StageProgress.load_workspace("a").is_empty(), "wrong-typed sections are tolerated")
	_check(StageProgress.save_workspace("a", projects.robot_car, false) == OK and not StageProgress.load_workspace("a").is_empty(), "wrong-typed sections are repaired on save")
	_check(StageProgress.save_workspace("a", {"format": "ssok-project"}, false) == ERR_INVALID_DATA, "invalid workspace project is refused")
	# Write failure.
	StageProgress.path = "user://missing_review_dir/progress.json"
	_check(StageProgress.mark_cleared("x") != OK and not FileAccess.file_exists(StageProgress.path), "write failure reports an error")
	# Leftover temporary file with missing main file (crash between remove and rename on Windows).
	StageProgress.path = "user://review_tmp_only.json"
	DirAccess.remove_absolute(StageProgress.path)
	_write(StageProgress.path + ".tmp", good)
	print("TMP_ONLY cleared=", StageProgress.load_cleared().keys())
	DirAccess.remove_absolute(StageProgress.path + ".tmp")
	DirAccess.remove_absolute("user://review_progress.json")
	# Preferences written by main.
	var preferences := InterfacePreferences.new()
	preferences.load_preferences(FIXTURES + "interface_main.cfg")
	_check(preferences.values.appearance == "system" and is_equal_approx(float(preferences.values.text_scale), 1.3) and is_equal_approx(float(preferences.values.volume), 25.0), "main preferences load unchanged")
	preferences.load_preferences("user://no_such_interface.cfg")
	print("DEFAULT_APPEARANCE ", preferences.values.appearance)
	preferences.free()
	print("save_compat_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
