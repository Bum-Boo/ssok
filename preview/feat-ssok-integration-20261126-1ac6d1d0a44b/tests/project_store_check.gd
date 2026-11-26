extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _directory: String = "user://project_store_test_%d/" % OS.get_process_id()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: ConnectionGraph = ConstructionKitHumanoidPreset.build()
	var source: String = "# 한글 中文 日本語\narm = Servo(9)\narm.write(90)\n"
	var record: Dictionary = ProjectStore.document("Robot / 로봇", graph, source)
	_check(ProjectStore.valid(record), "full elementary graph can be saved")
	var exported: String = ProjectStore.serialize(record)
	var imported: Dictionary = ProjectStore.parse(exported)
	_check(imported.source == source and imported.title == record.title, "source and Unicode title survive transfer")
	_check(MotionSnapshot.fingerprint(imported.graph) == MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)), "graph and wiring round-trip without rounding")
	var first: Dictionary = ProjectStore.save(record, _directory)
	var second: Dictionary = ProjectStore.save(record, _directory)
	_check(first.has("id") and second.has("id") and first.id != second.id, "saving preserves earlier snapshots")
	_check(ProjectStore.load_project(first.id, _directory) == imported, "disk reload preserves complete document")
	_check(ProjectStore.list_projects(_directory).size() == 2, "library enumerates both snapshots")
	_check(ProjectStore.load_project("../language", _directory).is_empty(), "path traversal rejected")
	_check(ProjectStore.remove("../language", _directory) == ERR_INVALID_PARAMETER, "deletion confined to project ids")
	_check(ProjectStore.parse("not json").is_empty(), "invalid JSON rejected")
	_check(ProjectStore.parse(" ".repeat(ProjectStore.MAX_BYTES + 1)).is_empty(), "oversized documents rejected")
	var altered: Dictionary = imported.duplicate(true)
	altered.graph.parts[0].id = "res://arbitrary.gd"
	_check(not ProjectStore.valid(altered), "untrusted resource paths rejected")
	altered = imported.duplicate(true)
	altered.graph.parts[0].transform[0] = 2.0
	_check(not ProjectStore.valid(altered), "nonrigid pose rejected")
	altered = imported.duplicate(true)
	altered.version = 1.5
	_check(not ProjectStore.valid(altered), "fractional version rejected")
	altered = imported.duplicate(true)
	altered.source = "a".repeat(ProjectStore.MAX_CODE_BYTES + 1)
	_check(not ProjectStore.valid(altered), "source bound enforced")
	altered = imported.duplicate(true)
	altered["token"] = "not-a-secret-test-field"
	_check(not ProjectStore.valid(altered), "unexpected fields rejected")
	_check(ProjectStore.valid(ProjectStore.document("Empty", ConnectionGraph.new(), "")), "empty workspace can be saved")
	var empty_record: Dictionary = ProjectStore.document("Empty round-trip", ConnectionGraph.new(), "# code before adding parts")
	var empty_result: Dictionary = ProjectStore.save(empty_record, _directory)
	var empty_loaded: Dictionary = ProjectStore.load_project(empty_result.get("id", ""), _directory)
	_check(not empty_loaded.is_empty() and empty_loaded.source == empty_record.source, "empty graph survives disk JSON numeric conversion with learner code")
	_check(ProjectStore.list_projects(_directory).size() == 3, "empty project remains visible in the library")
	var invalid_empty: Dictionary = empty_record.duplicate(true)
	invalid_empty.graph.version = 1.5
	_check(not ProjectStore.valid(invalid_empty), "empty graph still rejects fractional versions")
	invalid_empty.graph.version = 1
	invalid_empty.graph.links.append({})
	_check(not ProjectStore.valid(invalid_empty), "empty graph cannot carry invalid dangling links")
	_check(ProjectStore.document(" ", graph, source).is_empty(), "blank title rejected")
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_biped_pressed()
	main.mode_button.button_pressed = true
	main._open_projects()
	_check(main.projects.visible and not main.navigation.navigation_enabled, "project library is modal")
	_check(not main.manual_controller.is_enabled() and not main.runtime.is_running(), "opening library stops active control")
	main._load_project(imported)
	_check(not main.mode_button.button_pressed and not main.runtime.is_running(), "loading never executes stored code")
	_check(main.code_edit.text == source, "loaded source appears in editor")
	main.projects.close_panel()
	_check(main.navigation.navigation_enabled, "closing library restores navigation")
	main.code_edit.text = "# unsaved learner changes"
	var before: String = MotionSnapshot.fingerprint(main._motion_snapshot())
	main.biped_button.pressed.emit()
	_check(main._replace_dialog.visible, "starter replacement requires a decision for unsaved work")
	_check(main.code_edit.text == "# unsaved learner changes" and MotionSnapshot.fingerprint(main._motion_snapshot()) == before, "pending starter preserves code and graph")
	main._replace_dialog.hide()
	main._replace_dialog.confirmed.emit()
	_check(main.assembly.graph.parts.size() == BipedPreset.build().parts.size(), "explicit replacement loads requested example")
	main.free()
	for item: Dictionary in ProjectStore.list_projects(_directory):
		_check(ProjectStore.remove(item.id, _directory) == OK, "remove own test snapshot")
	DirAccess.remove_absolute(_directory)
	print("project_store_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check(condition: bool, explanation: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + explanation)
