extends SceneTree

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


func _open(level: Dictionary) -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = {"mode": "stage", "level": level}
	root.add_child(main)
	await _settle()
	return main


func _wait(main: Node3D) -> void:
	for tick: int in 1200:
		await physics_frame
		if main.stages.evaluator.status in ["success", "not_met", "indeterminate"]:
			break
	print("OWN_BUILD_RESULT ", main.session.level.id, " ", JSON.stringify(main.stages.evaluator.result()))
	await _settle()


func _run() -> void:
	root.size = Vector2i(1440, 900)
	StageProgress.path = "user://own_build_check.json"
	DirAccess.remove_absolute(StageProgress.path)
	for level: Dictionary in StageLevels.all():
		var main: Node3D = await _open(level)
		_check(main.assembly.graph.parts.is_empty() and main.code_edit.text.is_empty(), level.id + " starts with empty graph and code")
		_check(main._ui_root.get_node("PartsLibrary").visible and main.part_buttons.size() == 81, level.id + " full tray including B parts and task flag")
		_check(main._ui_root.get_node("ViewportTools").visible, level.id + " edit tools available")
		for tab: String in ["Code", "Blocks", "Wiring", "Controls"]:
			var found: bool = false
			for index: int in main.program_tabs.get_tab_count():
				found = found or (main.program_tabs.get_tab_control(index).name == tab and not main.program_tabs.is_tab_hidden(index))
			_check(found, level.id + " tab " + tab)
		_check(main._guide_phase == 0, level.id + " assembly is first step")
		# Load graph + source through the same assembly/project API, with no answer-use signal.
		var stage: Dictionary = StageLevels.stage_definition(level)
		main._load_preset(StageLevels.starting_graph(level, stage), stage.author_solution.source, "")
		main._on_run_pressed()
		await _wait(main)
		_check(main.stages.evaluator.success, level.id + " author graph and code physically clear")
		_check(not StageProgress.cleared_with_solution(level.id), level.id + " independent API build is not marked as answer use")
		main._reset_attempt()
		# Confirm cancel is harmless, then exercise the confirmed replacement API.
		var before: String = main._workspace_key()
		main.stage_hud.solution_requested.emit()
		_check(main._stage_replace_dialog.visible and main._workspace_key() == before and not main._used_solution, "answer waits for confirmation")
		main._stage_replace_dialog.hide()
		main._clear_stage_build()
		_check(main.assembly.graph.parts.is_empty() and main.code_edit.text.is_empty() and not main._used_solution, "clear returns to empty editor")
		main.stage_hud.solution_requested.emit()
		main._stage_replace_dialog.confirmed.emit()
		main._stage_replace_dialog.hide()
		_check(main._used_solution and not main.assembly.graph.parts.is_empty() and main.code_edit.text == stage.author_solution.source, "confirmed answer replaces graph and code")
		_check(StageProgress.load_workspace(level.id).used_solution, "answer use survives workspace save")
		var key: String = main._workspace_key()
		main._request_exit()
		main.free()
		await _settle()
		main = await _open(level)
		_check(main._workspace_key() == key and main._used_solution and not main.run_mode.is_built(), "return restores assembly and source without execution")
		main.free()
		await _settle()
	# A short drive genuinely runs and fails before the finish.
	var main: Node3D = await _open(StageLevels.find("finish-line"))
	main._clear_stage_build()
	var stage: Dictionary = StageLevels.stage_definition(main.session.level)
	main._load_preset(ProjectStore.graph_from(stage.author_solution), StageLevels.CAR_STARTER, "")
	main._on_run_pressed()
	await _wait(main)
	_check(main.stages.evaluator.status == "not_met" and not main.stages.evaluator.success, "short drive fails whole-robot finish goal")
	main._reset_attempt()
	# Four wheels and another chassis, with no car_chassis or upright requirement.
	var alternate := ConnectionGraph.new()
	for id: String in ["chassis_plate", "tt_motor", "tt_motor", "wheel_65", "wheel_65", "kit_wheel_40", "kit_wheel_90"]:
		alternate.parts.append({"part_def": MotionSnapshot._catalog()[id], "transform": Transform3D(Basis.IDENTITY, Vector3(0.8, 0.15, 0))})
	for link: Array in [[0, "mount_left", 1, "mount"], [0, "mount_right", 2, "mount"], [1, "shaft_left", 3, "hub"], [2, "shaft_right", 4, "hub"], [1, "shaft_right", 5, "hub"], [2, "shaft_left", 6, "hub"]]:
		alternate.links.append({"a_part": link[0], "a_port": StringName(link[1]), "b_part": link[2], "b_port": StringName(link[3])})
	_check(not ProjectStore.document("Four wheels", alternate, "").is_empty(), "different chassis and four-wheel graph validates")
	main._load_preset(alternate, "sleep(1000)", "")
	main.run_mode.build(alternate)
	var judge := StageEvaluator.new()
	judge.configure(stage, alternate)
	_check(judge.start(alternate), "whole selector accepts different composition")
	judge.observe(main.run_mode, alternate, 0.02)
	_check(judge.success, "every part beyond line passes without named chassis")
	main.run_mode.teardown()
	alternate.parts[-1].transform.origin.x = 0.4
	main.run_mode.build(alternate)
	judge.start(alternate)
	judge.observe(main.run_mode, alternate, 0.02)
	_check(not judge.success, "one wheel left behind prevents whole-robot clear")
	main.run_mode.teardown()
	# Wall distances use environment geometry; a sensor-free robot can satisfy the goal.
	var block := ConnectionGraph.new()
	block.parts.append({"part_def": MotionSnapshot._catalog()["kit_weight_100"], "transform": Transform3D(Basis.IDENTITY, Vector3(0.7, 0.08, 0))})
	main.run_mode.build(block)
	judge.configure(StageCatalog.builtins()[2], block)
	var bounds: AABB = StageEvaluator.part_bounds(main.run_mode, 0)
	judge.environment_walls = [AABB(Vector3(bounds.end.x + 0.075, 0, -0.2), Vector3(0.02, 0.4, 0.4))]
	_check(judge.start(block), "wall task needs no sonar")
	judge.observe(main.run_mode, block, 0.31)
	_check(judge.success and is_equal_approx(judge.measurements[0].value, 0.075), "nearest surface distance and stationary hold clear")
	judge.start(block)
	main.run_mode.bodies[0].linear_velocity = Vector3(0.1, 0, 0)
	judge.observe(main.run_mode, block, 0.31)
	_check(not judge.success, "moving robot cannot clear stop goal")
	main.run_mode.teardown()
	# Contact comes from the physics engine and remains latched after separation.
	main._level.install_wall(0.8)
	block.parts[0].transform.origin = Vector3(0.79, 0.15, 0)
	main.run_mode.build(block)
	judge.configure(StageCatalog.builtins()[2], block)
	judge.environment_walls = main._level.wall_bounds()
	judge.start(block)
	for tick: int in 30:
		await physics_frame
		judge.observe(main.run_mode, block, 1.0 / 60.0)
	_check(judge.had_wall_contact and not judge.success, "actual wall collision prevents success")
	main.run_mode.bodies[0].position.x = 0.6
	judge.observe(main.run_mode, block, 0.31)
	_check(judge.had_wall_contact and not judge.success, "wall contact stays latched after separation")
	main.run_mode.teardown()
	# A flag on a different support, with no servo/arm/board, is a valid target set.
	var flags := ConnectionGraph.new()
	for id: String in ["base", "flag", "flag"]:
		flags.parts.append({"part_def": MotionSnapshot._catalog()[id], "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0))})
	main.run_mode.build(flags)
	judge.configure(StageCatalog.builtins()[0], flags)
	_check(judge.start(flags), "multiple flags and no servo remain judgeable")
	judge.observe(main.run_mode, flags, 0.6)
	_check(not judge.success, "flag height needs a full continuous second")
	judge.observe(main.run_mode, flags, 0.41)
	_check(judge.success, "flag target does not require servo or arm")
	main.run_mode.teardown()
	var invalid: Dictionary = stage.duplicate(true)
	invalid.rules[0].target_index = 0
	_check(not StageDefinition.valid(invalid) and StageDefinition.parse(JSON.stringify(invalid)).is_empty(), "wildcard indexed target rejected consistently")
	invalid = StageCatalog.builtins()[0].duplicate(true)
	invalid.rules[0].target_index = 4
	_check(not StageDefinition.valid(invalid), "aggregate kind selector requires index minus one")
	main.free()
	await _settle()
	# A fresh learner's physical answer clear carries the badge into the stage map.
	StageProgress.path = "user://own_build_solution_check.json"
	DirAccess.remove_absolute(StageProgress.path)
	main = await _open(StageLevels.find("raise-flag"))
	main._load_stage_solution()
	main._on_run_pressed()
	await _wait(main)
	_check(main.stages.evaluator.success and StageProgress.cleared_with_solution("raise-flag"), "physical answer clear records answer use")
	main._reset_attempt()
	var menu: Node = load("res://scenes/screens/stage_select.tscn").instantiate()
	root.add_child(menu)
	await _settle()
	var badges: Array[Node] = menu.find_children("*", "Label", true, false)
	_check(badges.any(func(label: Label) -> bool: return label.text == "Cleared with solution"), "stage map displays answer clear badge")
	menu.free()
	var preferences: InterfacePreferences = root.get_node("Preferences")
	for locale: String in SsokLocale.LOCALES:
		SsokLocale.select_locale(locale, false)
		for appearance: String in ["light", "dark"]:
			preferences.values.appearance = appearance
			for scale: float in [1.0, 2.0]:
				preferences.values.text_scale = scale
				preferences.changed.emit()
				root.size = Vector2i(1152, 648) if scale == 2.0 else Vector2i(1440, 900)
				for reset: bool in [false, true]:
					if reset:
						main.stage_hud.reset_build_requested.emit()
					else:
						main.stage_hud.solution_requested.emit()
					await _settle()
					var dialog: ConfirmationDialog = main._stage_reset_dialog if reset else main._stage_replace_dialog
					_check(dialog.size.x <= root.size.x and dialog.size.y <= root.size.y, locale + appearance + str(scale) + " confirmation fits viewport")
					_check(tr(dialog.get_label().text) == tr("Clear this stage's assembly and code and start from an empty workbench?" if reset else "Replace your assembly and code with the author solution?"), locale + " confirmation translated")
					dialog.get_cancel_button().grab_focus()
					_check(dialog.get_cancel_button().has_focus(), locale + " confirmation cancel keyboard focus")
					dialog.hide()
	preferences.values.text_scale = 1.0
	preferences.changed.emit()
	var current_path: String = StageProgress.path
	StageProgress.path = "user://nonexistent_own_build_folder/progress.json"
	var exited: Array[bool] = [false]
	main.exit_requested.connect(func() -> void: exited[0] = true)
	var kept: String = main._workspace_key()
	main._on_run_pressed()
	_check(main.stages.evaluator.status == "running", "save-failure probe starts a live attempt")
	main._request_exit()
	_check(not exited[0] and main._workspace_key() == kept, "write failure keeps the learner in the editor with unchanged build")
	_check(not main.run_mode.is_built() and main.stages.evaluator.status == "cancelled", "failed exit cancels observation and restores edit mode")
	StageProgress.path = current_path
	main.blocks.instructions.append({"op": "raw", "raw": "# keep this draft"})
	main.code_edit.text += "# conflicting code"
	_check(not main._save_stage_workspace() and main.blocks.has_draft(), "unapplied conflicting block draft blocks exit-save without discarding changes")
	main.free()
	await _settle()
	DirAccess.remove_absolute(StageProgress.path)
	StageProgress.path = "user://own_build_check.json"
	# Progress v1 migration and answer annotation keep one another's data.
	var file: FileAccess = FileAccess.open(StageProgress.path, FileAccess.WRITE)
	file.store_string('{"format":"ssok-progress","version":1,"cleared":{"old":true}}')
	file.close()
	_check(StageProgress.mark_cleared("answer", true) == OK and StageProgress.cleared_with_solution("answer") and StageProgress.is_cleared("old"), "v1 clears survive answer clear migration")
	_check(StageProgress.mark_cleared("answer", false) == OK and not StageProgress.cleared_with_solution("answer"), "independent clear replaces answer badge")
	DirAccess.remove_absolute(StageProgress.path)
	print("stage_own_build_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
