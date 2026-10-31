extends SceneTree

## Review repros for the own-build aggregate goals in real Stage sessions.
## Each probe prints its observed outcome; checks assert the EXPECTED behaviour, so a failure
## here is a reproduced defect or contract gap.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _settle() -> void:
	for tick: int in 8:
		await process_frame


func _open(level_id: String) -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = {"mode": "stage", "level": StageLevels.find(level_id)}
	root.add_child(main)
	await _settle()
	return main


func _attempt(main: Node3D, label: String) -> Dictionary:
	main._on_run_pressed()
	for tick: int in 1500:
		await physics_frame
		if main.stages.evaluator.status in ["success", "not_met", "indeterminate", "cancelled"]:
			break
	var result: Dictionary = main.stages.evaluator.result()
	print("REVIEW ", label, " ui_status=", main.status.text, " status=", result.status, " reason=", result.reason, " measurements=", JSON.stringify(result.measurements))
	main._reset_attempt()
	await _settle()
	return result


func _part(id: String, origin: Vector3) -> Dictionary:
	return {"part_def": MotionSnapshot._catalog()[id], "transform": Transform3D(Basis.IDENTITY, origin)}


func _run() -> void:
	root.size = Vector2i(1440, 900)
	StageProgress.path = "user://review_aggregate_progress.json"
	DirAccess.remove_absolute(StageProgress.path)

	# 1. Finish line: one passive part placed past the line, no actuator, trivial program.
	var main: Node3D = await _open("finish-line")
	var single := ConnectionGraph.new()
	single.parts.append(_part("kit_weight_100", Vector3(0.8, 0.08, 0)))
	main._load_preset(single, "sleep(1)\n", "")
	var result: Dictionary = await _attempt(main, "finish_line_placed_block")
	_check(result.status != "success", "a passive block placed past the line without moving does not clear finish-line")
	main.free()
	await _settle()

	# 2. Finish line: the author car plus an environment line tile behind the start.
	main = await _open("finish-line")
	var stage: Dictionary = StageLevels.stage_definition(main.session.level)
	var graph: ConnectionGraph = StageLevels.starting_graph(main.session.level, stage)
	main._load_preset(graph, stage.author_solution.source, "")
	result = await _attempt(main, "finish_line_author_only")
	_check(result.status == "success", "author car clears finish-line")
	graph = StageLevels.starting_graph(main.session.level, stage)
	graph.parts.append(_part("kit_env_line_straight", Vector3(-0.1, 0.0, 0.3)))
	main._load_preset(graph, stage.author_solution.source, "")
	result = await _attempt(main, "finish_line_author_plus_env_tile")
	_check(result.status == "success", "an environment line tile is not part of the robot set for min_x")
	main.free()
	await _settle()

	# 3. Wall brake: stationary block far from the real wall, plus a palette stage_wall prop.
	main = await _open("wall-brake")
	var block := ConnectionGraph.new()
	block.parts.append(_part("kit_weight_100", Vector3(0.0, 0.08, 0)))
	main._load_preset(block, "sleep(1)\n", "")
	var bounds_x: float = 0.0
	main.run_mode.build(main.assembly.graph)
	bounds_x = StageEvaluator.part_bounds(main.run_mode, 0).end.x
	main.run_mode.teardown()
	var wall_def: PartDef = MotionSnapshot._catalog()["stage_wall"]
	var wall_origin: Vector3 = Vector3(bounds_x + 0.07 - wall_def.mesh.get_aabb().position.x, 0.15, 0)
	main.assembly.spawn_part(wall_def, Transform3D(Basis.IDENTITY, wall_origin))
	_check(main.assembly.graph.parts.size() == 2, "learner can add a stage_wall prop from the tray in Stage mode")
	result = await _attempt(main, "wall_brake_learner_placed_wall")
	_check(result.status != "success", "a learner-placed stage_wall prop is not the stage's environment wall")
	main.free()
	await _settle()

	# 4. Save trap: an oversized program cannot be stored, so Back never leaves the stage.
	main = await _open("raise-flag")
	var exited: Array[bool] = [false]
	main.exit_requested.connect(func() -> void: exited[0] = true)
	main.code_edit.text = "# pad\n".repeat(12000)
	main.blocks.reset_source(main.code_edit.text)
	main._request_exit()
	print("REVIEW save_trap exited=", exited[0], " status=", main.status.text)
	_check(exited[0] or main.status.text.contains("too large") or main.status.text.contains("64"), "oversized stage workspace either leaves or explains why it cannot be saved")
	main.free()
	await _settle()
	DirAccess.remove_absolute(StageProgress.path)
	print("stage_aggregate_review_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
