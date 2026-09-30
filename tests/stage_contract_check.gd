extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _run() -> void:
	ServoArmPreset.build_microbit()
	_check(Wiring.pin_map(ServoArmPreset.build()).has(9), "microbit starter does not mutate generic starter")
	var stage: Dictionary = StageCatalog.builtins()[0]
	var graph: ConnectionGraph = ProjectStore.graph_from(stage.scene)
	var duplicate: Dictionary = graph.parts[2].duplicate(true)
	graph.parts.append(duplicate)
	var judge := StageEvaluator.new()
	judge.configure(stage, graph)
	_check(not judge.start(graph) and judge.reason == "target_ambiguous", "duplicate catalog targets cannot silently select first")
	graph.parts[4].transform.origin.x = 3.0
	var explicit: Dictionary = StageDefinition.create("two-arms", "Two arms", graph, "", [StageDefinition.rule("x", "arm_link", 2.9, 3.1, 0, 4)])
	_check(StageDefinition.valid(explicit), "indexed target stage validates")
	judge.configure(explicit, graph)
	_check(judge.start(graph) and judge.resolve_target(0, graph).index == 4, "explicit second arm resolves")
	var selected_run := RunMode.new()
	root.add_child(selected_run)
	selected_run.build(graph)
	judge.observe(selected_run, graph, 0.01)
	_check(judge.success and judge.measurements[0].part_index == 4, "physics judges chosen second instance instead of first")
	selected_run.teardown()
	selected_run.free()
	graph.parts.remove_at(4)
	graph.parts.append(duplicate.duplicate(true))
	# A replacement must not inherit the deleted instance's runtime token.
	graph.parts[4].erase("stage_target_token")
	_check(judge.resolve_target(0, graph).get("error") == "target_changed", "same-kind replacement does not inherit target")
	var legacy: Dictionary = stage.duplicate(true)
	legacy.version = 1
	for rule: Dictionary in legacy.rules:
		rule.erase("target_index")
	_check(StageDefinition.valid(legacy), "legacy v1 stage remains readable")
	var invalid: Dictionary = explicit.duplicate(true)
	invalid.rules[0].target_index = 999
	_check(not StageDefinition.valid(invalid), "out-of-bounds target rejected")
	invalid = explicit.duplicate(true)
	invalid.rules[0].target_index = 0
	_check(not StageDefinition.valid(invalid), "index pointing to different catalog kind rejected")
	graph = ProjectStore.graph_from(stage.scene)
	var context: Dictionary = StageDefinition.runtime_context()
	var proof: String = StageDefinition.fingerprint(stage, graph, "", context)
	var changed: Dictionary = stage.duplicate(true)
	changed.scene.graph.parts[0].transform[9] += 0.01
	_check(proof != StageDefinition.fingerprint(changed, graph, "", context), "start environment invalidates clear proof")
	changed = stage.duplicate(true)
	changed.author_solution.source = "sleep(1)"
	_check(proof != StageDefinition.fingerprint(changed, graph, "", context), "author solution invalidates proof")
	changed = context.duplicate(true)
	changed.engine.hash = "different"
	_check(proof != StageDefinition.fingerprint(stage, graph, "", changed), "engine identity invalidates proof")
	changed = context.duplicate(true)
	changed.sensor_conditions = [{"part": 0, "seed": 9, "realistic": true}]
	_check(proof != StageDefinition.fingerprint(stage, graph, "", changed), "sensor conditions invalidate proof")
	judge.configure(stage, graph)
	judge.start(graph)
	var previous: int = judge.execution_id
	judge.finish("cancelled", "user_stop")
	judge.finish("success", "", previous)
	_check(judge.status == "cancelled" and not judge.success and not judge.expired, "cancelled run cannot become success")
	judge.start(graph)
	judge.finish("success", "", previous)
	_check(judge.status == "running", "old execution completion cannot settle new attempt")
	var run_mode := RunMode.new()
	root.add_child(run_mode)
	judge.observe(run_mode, graph, 0.1)
	_check(judge.status == "indeterminate" and judge.reason == "physics_unavailable", "lost physics is not learner failure")
	run_mode.build(graph)
	judge.start(graph)
	judge.observe(run_mode, graph, 61.0)
	_check(judge.status == "not_met" and judge.expired and judge.reason == "time_limit", "time limit is ordinary unmet goal")
	judge.start(graph)
	judge.finish("not_met", "program_error")
	_check(judge.status == "not_met" and not judge.expired, "program error distinct from timeout")
	judge.start(graph)
	judge.observe(run_mode, graph, NAN)
	_check(judge.status == "indeterminate" and judge.reason == "invalid_time_step", "invalid timing cannot clear")
	var sensor := SonarSensor.new()
	_check(sensor.distance_cm() == 401 and sensor.last_state == "unavailable", "missing runtime sensor is explicitly unavailable")
	run_mode.teardown()
	var car: ConnectionGraph = RobotCarPreset.build()
	var sonar_stage: Dictionary = StageDefinition.create("sensor-test", "Sensor test", car, "", [StageDefinition.rule("sonar_distance", "hc_sr04", 0, 10)])
	judge.configure(sonar_stage, car)
	run_mode.build(car)
	judge.start(car)
	judge.observe(run_mode, car, 0.01)
	_check(judge.reason == "sensor_missing" and judge.status == "indeterminate", "unwired/unavailable observation differs from range miss")
	run_mode.sonar_on_pins(1, 2)
	judge.start(car)
	await physics_frame
	judge.observe(run_mode, car, 0.01)
	_check(judge.status == "running" and judge.measurements[0].value == null and judge.measurements[0].state == "out_of_range", "out of range does not become zero or system failure")
	run_mode.teardown()
	run_mode.free()
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._load_preset(ProjectStore.graph_from(stage.scene), "arm = Servo(pin0)\narm.write(90)\nsleep(5000)\n", "")
	main.stages.load_goal(stage)
	main._on_run_pressed()
	_check(main.stages.evaluator.status == "running", "real UI starts stage")
	main._on_stop_pressed()
	_check(main.stages.evaluator.status == "cancelled" and not main.stages._export(), "UI stop invalidates proof")
	main._ensure_assembly_mode()
	main.code_edit.text = "arm = Servo(pin0)\narm.write(90)\nx = 1 / 0\n"
	main.blocks.reset_source(main.code_edit.text)
	main._on_run_pressed()
	_check(main.stages.evaluator.reason == "program_error" and not main.stages._observing, "runtime code error reaches stage UI")
	main._ensure_assembly_mode()
	main._load_preset(ProjectStore.graph_from(stage.author_solution), stage.author_solution.source, "")
	main.stages.load_goal(stage)
	main._on_run_pressed()
	for tick: int in 900:
		await physics_frame
		if main.stages.evaluator.status != "running":
			break
	_check(main.stages.evaluator.success and main.stages._export(), "measured success still exports")
	main._ensure_assembly_mode()
	_check(main.stages._export(), "unchanged success stays exportable in edit mode")
	var settings_before: Variant = ProjectSettings.get_setting("physics/3d/solver/solver_iterations")
	ProjectSettings.set_setting("physics/3d/solver/solver_iterations", int(settings_before) + 1)
	_check(not main.stages._export(), "changed physics setting invalidates UI proof")
	ProjectSettings.set_setting("physics/3d/solver/solver_iterations", settings_before)
	main.stages.current.scene.graph.parts[0].transform[9] += 0.01
	_check(not main.stages._export(), "UI export rejects altered stage environment")
	main.free()
	await process_frame
	await process_frame
	print("stage_contract_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
