extends SceneTree

const IDS: Array[String] = ["kit_passive_hinge", "kit_wheel_40", "kit_wheel_90", "kit_weight_100", "kit_weight_300"]
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var inventory: Dictionary = {}
	for button: Button in main.part_buttons:
		inventory[String((button.get_meta("part_definition") as PartDef).id)] = button
	for id: String in IDS:
		_check(inventory.has(id), "palette includes " + id)
		for locale: String in ["en", "ko", "ja", "zh_CN"]:
			SsokLocale.select_locale(locale, false)
			var definition: PartDef = inventory[id].get_meta("part_definition")
			_check(not String(TranslationServer.translate(definition.display_name)).is_empty(), "part name resolves in " + locale)
	var program: String = "x = 0\nfor i in range(3):\n    x = x + i"
	for stage: Dictionary in StageCatalog.builtins():
		var graph: ConnectionGraph = ProjectStore.graph_from(stage.author_solution)
		main._load_preset(graph, program, "")
		main.stages.load_goal(stage)
		for index: int in IDS.size():
			var definition: PartDef = inventory[IDS[index]].get_meta("part_definition")
			_check(main.assembly.spawn_part(definition, Transform3D(Basis.IDENTITY, Vector3(0.3 + index * 0.1, 0.2, 0.4))) != null, "add new part to " + String(stage.id))
		var serialized: Dictionary = ProjectStore.document("Parts freedom", main.assembly.graph, program)
		_check(not serialized.is_empty() and ProjectStore.graph_from(serialized) != null, "stage assembly including new stock round trips")
		main.mode_button.button_pressed = true
		_check(main.run_mode.is_built() and main.run_mode.bodies.size() == main.assembly.graph.parts.size(), "all stage parts derive runtime bodies")
		await main.runtime.run(program)
		_check(main.runtime.state == "finished" and main.runtime._variables.get("x") == 3, "new control structure runs in stage context")
		main.mode_button.button_pressed = false
		await process_frame
	main.stages.clear_goal()
	_check(main.stages.current.is_empty(), "Lab can clear the task while retaining assembly")
	main.free()
	await process_frame
	print("parts_freedom_workshop_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
