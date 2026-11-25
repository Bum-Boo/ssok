extends SceneTree

## Two-way title (ADR 0043): Play -> stage list -> level load -> unmet starter -> observed clear
## -> next stage, and Free building -> Lab, whose Help menu holds projects, examples and the
## experiments that stages never show. Run with --fixed-fps 60 (as tools/ci/verify.py does).
## `-- --screenshots` (without --headless) saves each screen to user://game_flow_previews.

var checks: int = 0
var failures: int = 0
var _app: Node
var _shots: bool = false
var _folder: String = "user://game_flow_previews"


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	print("CHECK %s %s" % ["ok  " if value else "FAIL", label])
	if not value:
		failures += 1
		push_error(label)


func _frames(count: int) -> void:
	for index: int in count:
		await process_frame


func _shot(name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_folder.path_join(name + ".png"))


func _run() -> void:
	_shots = "--screenshots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--locale="):
			SsokLocale.select_locale(argument.trim_prefix("--locale="), false)
	DirAccess.make_dir_recursive_absolute(_folder)
	root.size = Vector2i(1440, 900)
	StageProgress.path = "user://game_flow_test_progress_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(StageProgress.path)
	_app = load("res://scenes/app.tscn").instantiate()
	root.add_child(_app)
	await _frames(3)
	_check(_app.current_name == "title", "app opens on the title screen")
	# Untyped like the rest of this script: naming menu classes here would compile them before autoloads.
	var title: Node = _app.current
	var ways_in: Array = title.menu.get_children().filter(func(node: Node) -> bool: return node is Button)
	_check(ways_in == [title.play_button, title.lab_button], "the title offers exactly two ways in")
	_check(title.play_button.text == "Play stages" and title.lab_button.text == "Free building", "the two ways in are play and free building")
	_check(title.play_button.has_focus(), "play has the default focus")
	_check(title.language_picker.is_visible_in_tree() and title.find_child("SettingsButton", true, false).is_visible_in_tree(), "language and settings stay on the title")
	_check(not title.has_signal("examples_requested") and not title.has_signal("projects_requested"), "examples and projects left the title")
	await _shot("01_title")
	title.play_button.pressed.emit()
	await _frames(2)
	_check(_app.current_name == "stages", "play opens the stage list")
	var select: Node = _app.current
	_check(select.play_buttons.size() == StageLevels.all().size(), "every playable stage has a card")
	await _shot("02_stages")
	select.play_buttons["raise-flag"].pressed.emit()
	await _frames(1)
	_check(_app.current_name == "loading", "a loading screen appears before the level")
	await _shot("03_loading")
	await _frames(4)
	var main: Node3D = _app.current as Node3D
	_check(main != null and main.get("session").get("mode") == "stage", "the stage opens a workshop in stage mode")
	if main == null:
		await _finish()
		return
	_check(main.get_node_or_null("Floor") == null and main._level != null and main._level.name == "RaiseFlagLevel", "the stage level replaces the default floor")
	_check(main._ui_root.get_node("PartsLibrary").visible and main.assembly.graph.parts.is_empty(), "an empty stage opens the full parts library")
	_check(not main.projects_button.visible and not main.motion_lab_button.visible and not main.mode_button.visible, "stage mode hides projects, AI lab and the physics toggle")
	_check(not main.examples_menu.visible and main._starter_controls.all(func(c: Control) -> bool: return not c.visible), "stage mode hides example robots")
	_check(not main.flag_mission.visible, "the old flag panel is replaced by the stage HUD")
	_check(main.program_tabs.is_tab_hidden(4) and not main.program_tabs.is_tab_hidden(1), "stage mode keeps manual control and hides challenge authoring")
	_check(main.program_tabs.get_current_tab_control().name == "Blocks", "the flag stage starts on blocks")
	_check(main.stage_hud != null and not main.stage_hud.briefing.visible, "the scene opens without a central briefing")
	_check(main.code_edit.text.is_empty(), "the code editor starts empty")
	var stage_help: PopupMenu = main._help_menu.get_popup()
	var stage_submenus: int = 0
	for index: int in stage_help.item_count:
		stage_submenus += int(stage_help.get_item_submenu_node(index) != null)
	_check(stage_submenus == 0 and stage_help.get_item_index(main.HELP_AI_CAMERA) < 0 and stage_help.get_item_index(main.HELP_MOTION_LAB) < 0, "stage help offers no examples or experiments")
	_check(_tab_hidden(main, "AI") and not main.motion_lab_button.is_visible_in_tree(), "stage mode hides the AI camera and motion lab")
	await _shot("04_briefing")
	await _frames(2)
	_check(not main.stage_hud.briefing.visible, "the scene remains unobstructed")
	_check(not main._ui_root.get_node("WorkspaceHeader").visible and not main._ui_root.get_node("WorkspaceFooter").visible and main._ui_root.get_node("ViewportTools").visible, "stage hides header and footer while retaining edit tools")
	_check(main._side_panel.get_global_rect().position.y > main.stage_hud.goal_card.get_global_rect().end.y, "the program overlay starts below the task strip")
	var camera_area: Rect2 = main._camera_framing_rect()
	_check(camera_area.position.y >= main.stage_hud.goal_card.get_global_rect().end.y, "camera framing starts below the goal card")
	await _shot("05_stage")
	main._load_preset(StageLevels.starting_graph(main.session.level, StageCatalog.builtins()[0]), StageLevels.FLAG_STARTER, "")
	await _frames(3)
	# The deliberately incomplete learner program keeps the arm down: the attempt must end unmet, not wait for the time limit.
	main.run_button.pressed.emit()
	await _frames(2)
	_check(main.run_button.text == "Reset robot", "while an attempt runs the run button resets the robot")
	await _wait_result(main, 12.0)
	_check(main.stage_hud.result.visible and not main.stages.evaluator.success, "starter program ends as not met")
	_check(main.stages.evaluator.reason == "program_finished", "a finished program is reported without waiting 60 s: " + main.stages.evaluator.reason)
	_check(not StageProgress.is_cleared("raise-flag"), "an unmet attempt is not recorded")
	await _shot("06_not_yet")
	main.stage_hud.retry_button.pressed.emit()
	await _frames(2)
	_check(not main.mode_button.button_pressed, "try again returns to edit mode")
	main.code_edit.text = "arm = Servo(pin0)\narm.write(90)\nsleep(3000)\n"
	main.blocks.reset_source(main.code_edit.text)
	main._on_run_pressed()
	await _wait_result(main, 12.0)
	_check(main.stages.evaluator.success, "raising the arm clears the stage from observed physics")
	_check(StageProgress.is_cleared("raise-flag"), "the clear is recorded")
	_check(main.stage_hud.next_button.visible, "a next stage is offered")
	await _shot("07_cleared")
	main.stage_hud.next_button.pressed.emit()
	await _frames(6)
	main = _app.current as Node3D
	_check(main != null and main._level != null and main._level.name == "FinishLineLevel", "next loads the finish-line level")
	if main != null:
		await _frames(2)
		await _shot("08_finish_line")
		main._load_preset(ProjectStore.graph_from(StageCatalog.builtins()[1].author_solution), StageLevels.CAR_STARTER, "")
		main._on_run_pressed()
		await _wait_result(main, 15.0)
		_check(not main.stages.evaluator.success, "the short starter drive does not reach the finish line")
		main.stage_hud.retry_button.pressed.emit()
		await _frames(2)
		main.code_edit.text = RobotCarPreset.ANSWER_CODE
		main.blocks.reset_source(main.code_edit.text)
		main._on_run_pressed()
		await _wait_result(main, 15.0)
		_check(main.stages.evaluator.success, "a longer drive crosses the finish line")
		main.stage_hud.list_requested.emit()
		await _frames(3)
		_check(_app.current_name == "stages", "stage list returns to the map")
		var cards: Node = _app.current
		cards.play_buttons["wall-brake"].pressed.emit()
		await _frames(6)
		main = _app.current as Node3D
		_check(main != null and main._level != null and main._level.name == "WallBrakeLevel", "wall-brake level loads from the map")
		if main != null:
			await _frames(2)
			await _shot("09_wall_brake")
			main._load_stage_solution()
			main.code_edit.text = RobotCarPreset.BRAKE_CODE
			main.blocks.reset_source(main.code_edit.text)
			main._on_run_pressed()
			await _wait_result(main, 20.0)
			_check(main.stages.evaluator.success, "the sensor loop stops in the zone")
			main.exit_button.pressed.emit()
			await _frames(3)
	_check(_app.current_name == "stages", "leaving a stage returns to the stage list")
	_app.current.back_requested.emit()
	await _frames(2)
	_check(_app.current_name == "title", "the stage list goes back to the title")
	_app.current.lab_button.pressed.emit()
	await _frames(6)
	main = _app.current as Node3D
	_check(main != null and main.session.mode == "lab", "free building opens a lab workshop")
	if main != null:
		_check(main._ui_root.get_node("PartsLibrary").visible and main.get_node_or_null("Floor") != null, "lab keeps the full library and default floor")
		_check(not main.stages._picker.visible and main.program_tabs.is_tab_hidden(4), "lab starts with the everyday tabs and no stage picker")
		_check(_tab_hidden(main, "AI") and not main.motion_lab_button.is_visible_in_tree(), "lab starts without the AI camera or motion lab on screen")
		var help: PopupMenu = main._help_menu.get_popup()
		var examples: PopupMenu = _submenu(help, "Load an example")
		var experiments: PopupMenu = _submenu(help, "Experiments")
		_check(help.get_item_index(main.HELP_PROJECTS) == 0, "saved projects open first from the Lab help menu")
		_check(examples != null and examples.item_count == main.examples_menu.get_popup().item_count, "finished examples moved into the Lab help menu")
		_check(experiments != null and experiments.get_item_index(main.HELP_AI_CAMERA) >= 0 and experiments.get_item_index(main.HELP_MOTION_LAB) >= 0, "the AI camera and motion lab sit under Experiments")
		help.id_pressed.emit(main.HELP_PROJECTS)
		await _frames(2)
		_check(main.projects.visible, "projects open from the Lab help menu")
		await _shot("10_lab_projects")
		main.projects.close_panel()
		await _frames(2)
		help.id_pressed.emit(main.HELP_STAGES)
		_check(not main.program_tabs.is_tab_hidden(4) and main.program_tabs.current_tab == 4 and main._side_panel.visible, "lab keeps authoring, opened from Help")
		experiments.id_pressed.emit(main.HELP_AI_CAMERA)
		await _frames(1)
		_check(not _tab_hidden(main, "AI") and main.program_tabs.get_current_tab_control().name == "AI", "the AI camera opens from Experiments")
		_check(not main.examples_menu.visible, "lab keeps example robots out of the parts tray")
		_check(not main.flag_mission.visible and not main._empty_panel.visible, "lab shows no flag mission")
		await _shot("11_lab")
		main.exit_button.pressed.emit()
		await _frames(2)
	_check(_app.current_name == "title", "an unchanged lab exits straight to the title")
	_app.current.lab_button.pressed.emit()
	await _frames(6)
	main = _app.current as Node3D
	if main != null:
		_submenu(main._help_menu.get_popup(), "Load an example").id_pressed.emit(1)
		await _frames(6)
		_check(main.session.mode == "lab" and main.assembly.graph.parts.size() > 3, "an example loads its robot inside the Lab")
		_check(not main.flag_mission.get("_flag").visible, "a non-flag example shows no flag visual")
		await _shot("12_lab_example")
		_submenu(main._help_menu.get_popup(), "Experiments").id_pressed.emit(main.HELP_MOTION_LAB)
		await _frames(2)
		_check(main.motion_lab.visible, "the AI motion lab opens from Experiments")
		main.motion_lab.close_requested.emit()
		await _frames(2)
	await _finish()


func _tab_hidden(main: Node3D, tab_name: String) -> bool:
	for index: int in main.program_tabs.get_tab_count():
		if String(main.program_tabs.get_tab_control(index).name) == tab_name:
			return main.program_tabs.is_tab_hidden(index)
	return true


func _submenu(menu: PopupMenu, label: String) -> PopupMenu:
	for index: int in menu.item_count:
		if menu.get_item_text(index) == label:
			return menu.get_item_submenu_node(index)
	return null


func _wait_result(main: Node3D, seconds: float) -> void:
	var limit: int = int(seconds * 60.0)
	for tick: int in limit:
		await physics_frame
		if main.stages.evaluator.status in ["success", "not_met", "cancelled", "indeterminate"]:
			break
	print("RESULT ", main.stages.evaluator.result(), " measurements=", main.stages.evaluator.measurements)
	await _frames(3)


func _finish() -> void:
	DirAccess.remove_absolute(StageProgress.path)
	_app.free()
	await process_frame
	print("game_flow_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
