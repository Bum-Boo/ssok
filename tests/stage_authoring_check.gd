extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var catalog: Array[Dictionary] = StageCatalog.builtins()
	_check(catalog.size() == 3, "three executable stage definitions")
	for stage: Dictionary in catalog:
		_check(StageDefinition.valid(stage), "catalog stage schema: " + str(stage.get("id")))
		var decoded: Dictionary = StageDefinition.parse(StageDefinition.serialize(stage))
		_check(not decoded.is_empty() and decoded.scene.source == stage.scene.source and MotionSnapshot.fingerprint(decoded.scene.graph) == MotionSnapshot.fingerprint(stage.scene.graph), "stage file round-trip retains exact graph and source")
	var bad: Dictionary = catalog[0].duplicate(true)
	bad.rules[0].metric = "execute"
	_check(not StageDefinition.valid(bad), "arbitrary judge code rejected")
	bad = catalog[0].duplicate(true)
	bad.rules[0].min = NAN
	_check(not StageDefinition.valid(bad), "nonfinite thresholds rejected")
	bad = catalog[0].duplicate(true)
	bad.rules[0].part_id = "../../secret"
	_check(not StageDefinition.valid(bad), "unknown target cannot load files")
	for stage: Dictionary in catalog:
		main._load_preset(ProjectStore.graph_from(stage.author_solution), stage.author_solution.source, "")
		main.stages.load_goal(stage)
		_check(not main.stages._export(), "cannot export without observed proof")
		main.run_button.pressed.emit()
		for tick: int in 900:
			await physics_frame
			if main.stages.evaluator.success:
				break
		print("STAGE_RESULT ", stage.id, " ", JSON.stringify(main.stages.evaluator.result()))
		_check(main.stages.evaluator.success, "actual author solution clears " + stage.id)
		_check(main.stages._export(), "fresh observed proof enables export")
		main.blocks.instructions.append({"op": "raw", "raw": "# pending edit"})
		_check(not main.stages._export(), "unapplied block draft cannot export an older verified program")
		main.blocks.instructions.pop_back()
		_check(not StageDefinition.parse(main.stages._transfer.text).is_empty(), "exported challenge validates")
		main.code_edit.text += "\n# changed"
		_check(not main.stages._export(), "changed source invalidates proof")
		main._ensure_assembly_mode()
	main._practice_flag_arm()
	_check(main.flag_mission._phase == &"Assembly" and main.assembly.graph.links.size() == 1, "first-five-minute practice has loose arm and unwired servo")
	main.flag_mission._action.pressed.emit()
	_check(main.flag_mission._phase == &"Wire" and main.assembly.graph.links.size() == 2, "practice snaps through actual assembly graph")
	main.program_tabs.current_tab = 3
	main.wiring_panel.pin_choice.select(1)
	main.wiring_panel.connect_button.pressed.emit()
	_check(main.flag_mission._wire_pin == 1, "wrong programmed pin is identified by actual wiring")
	main.code_edit.text = ServoArmPreset.microbit_code().replace("pin0", "pin1")
	main.blocks.reset_source(main.code_edit.text)
	main.run_button.pressed.emit()
	for tick: int in 240:
		await physics_frame
		if main.flag_mission._phase == &"Success":
			break
	_check(main.flag_mission._phase == &"Success", "corrected pin clears actual tutorial")
	main._ensure_assembly_mode()
	var program: String = "left = Motor(pin0)\nright = Motor(pin12)\nsonar = Sonar(pin1, pin2)\ncount = 0\nwhile sonar.distance_cm() > 10:\n    if count < 4:\n        left.motor_on(\"forward\", 35)\n    else:\n        right.stop(\"coast\")\n    count = count + 1\n    sleep(20)\nstop()"
	var profile: BoardProfile = BoardProfile.for_id("microbit")
	main._load_preset(ConnectionGraph.new(), "", "")
	main._on_palette_pressed(load("res://assets/parts/microbit.tres"))
	_check(main.blocks.profile.id == "microbit" and main.runtime.sleep_scale == 0.001, "Lab palette board selects its actual profile and sleep unit")
	_check(main.runtime.validate("sleep(500)", false).is_empty(), "Lab micro:bit preflight accepts milliseconds")
	main.blocks._add_block()
	var draft: Array = main.blocks.instructions.duplicate(true)
	main.assembly.remove_part(main.assembly._part_nodes[0])
	_check(main.blocks.has_draft() and main.blocks.instructions == draft and main.blocks.profile.id == "generic-servo", "board deletion preserves unapplied blocks and updates the palette")
	main.assembly.undo()
	_check(main.blocks.profile.id == "microbit" and main.blocks.instructions == draft, "undo restores the graph-derived board profile")
	var parsed: Dictionary = ServoProgram.parse(program, profile)
	_check(not parsed.has("error") and parsed.get("ast") is Array, "blocks use learner AST")
	if not parsed.has("error"):
		_check(ServoProgram.generate(parsed.instructions, profile).get("source") == program, "while/if/motor/sensor untouched round-trip")
		for item: Dictionary in parsed.instructions:
			if item.op == "sleep":
				item.args.seconds = 30
				item.erase("raw")
		var regenerated: Dictionary = ServoProgram.generate(parsed.instructions, profile)
		_check(regenerated.get("source", "").contains("    sleep(30)"), "editing a nested block preserves indentation")
	main.free()
	await process_frame
	await process_frame
	print("stage_authoring_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
