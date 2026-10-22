extends SceneTree

var checks: int = 0
var failures: int = 0
var shots: bool = false
var _prefs: InterfacePreferences
const MESSAGES: String = "res://tools/localization/workshop_guide_messages.json"


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + message)


func _settle() -> void:
	for index: int in 5:
		await process_frame


func _capture(name: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://scene_workshop_previews/" + name + ".png")


func _run() -> void:
	_prefs = root.get_node("Preferences")
	shots = "--screenshots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("user://scene_workshop_previews")
	root.size = Vector2i(1440, 900)
	for locale: String in ["ko", "ja", "zh_CN"]:
		var translation: Translation = load("res://assets/locales/" + locale + ".po")
		for item: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(MESSAGES)):
			_check(not translation.get_message(item.en).is_empty(), locale + " explicit new key " + item.en)
	var runtime := MiniRuntime.new()
	var empty := ConnectionGraph.new()
	var state: Dictionary = WorkshopGuide.snapshot(empty, "", runtime, false)
	_check(state.current == 0 and state.completed == [false, false, false, false], "empty build starts at assembly")
	var arm: ConnectionGraph = ServoArmPreset.build_microbit()
	_check(WorkshopGuide.snapshot(arm, "arm = Servo(pin0)\narm.write(90)", runtime, false).completed == [true, true, true, false], "graph-wired arm and valid source checked independently")
	arm.links = arm.links.filter(func(link: Dictionary) -> bool: return link.a_port != &"pin_0" and link.b_port != &"pin_0")
	_check(WorkshopGuide.snapshot(arm, "invalid???", runtime, false).current == 1, "removing the servo wire returns to wiring")
	var car: ConnectionGraph = RobotCarPreset.build()
	_check(WorkshopGuide.snapshot(car, RobotCarPreset.ANSWER_CODE, runtime, false).completed[1], "DC motors resolve both driver channels through graph wiring")
	car.links = car.links.filter(func(link: Dictionary) -> bool: return link.a_port != &"pin_8" and link.b_port != &"pin_8")
	_check(not WorkshopGuide.snapshot(car, RobotCarPreset.ANSWER_CODE, runtime, false).completed[1], "an incomplete driver input pair is not a completed wire step")
	runtime.free()
	for level: Dictionary in StageLevels.all():
		var main: Node3D = load("res://scenes/main.tscn").instantiate()
		main.session = {"mode": "stage", "level": level}
		root.add_child(main)
		await _settle()
		_check(not main.stage_hud.briefing.visible and not main.flag_mission.visible, level.id + " no central introduction")
		_check(main._ui_root.get_node("PartsLibrary").visible and not main._side_panel.visible, level.id + " empty stage opens the parts tray")
		_check(main.stage_hud.chips.size() == 4 and main._guide_phase == 0, level.id + " empty state points to assembly")
		_check(main.goal_display.label != null and not main.goal_display.label.text.is_empty(), level.id + " goal label exists in screen space")
		main._load_preset(StageLevels.starting_graph(level, StageLevels.stage_definition(level)), StageLevels.stage_definition(level).author_solution.source, "")
		await _settle()
		main.stage_hud.program_requested.emit()
		_check(main._side_panel.visible, "program overlay can open")
		main.stage_hud.program_requested.emit()
		_check(not main._side_panel.visible, "program overlay can collapse")
		main.code_edit.text = "invalid???"
		await _settle()
		_check(main._guide_phase == 2 and main._side_panel.visible, "invalid source reopens programming without graph edits")
		main.code_edit.text = StageLevels.stage_definition(level).author_solution.source
		main.blocks.reset_source(main.code_edit.text)
		await _settle()
		main.program_tabs.current_tab = 2
		main.stage_hud.run_requested.emit()
		await _settle()
		_check(main.mode_button.button_pressed and main._guide_phase == 3 and not main._side_panel.visible, "run mode completes run chip and exposes scene")
		_check(main.program_tabs.current_tab == 2, "running blocks never changes to code")
		for index: int in 5:
			await physics_frame
		await _settle()
		main._process(0.0)
		_check(not main.goal_display.samples.is_empty(), "goal display receives real evaluator samples")
		_check(main.goal_display.samples == main.stages.evaluator.measurements, "displayed values equal evaluator observations")
		_check(main.goal_display.label.text.contains("/"), "actual held time accompanies thresholds")
		main._reset_attempt()
		await _settle()
		_check(main.goal_display.samples.is_empty() and not main.stage_hud.result.visible, "retry clears observations and result")
		if level.id == "wall-brake":
			main.code_edit.text = RobotCarPreset.BRAKE_CODE
			main.blocks.reset_source(main.code_edit.text)
		for locale: String in ["en", "ko", "ja", "zh_CN"]:
			SsokLocale.select_locale(locale, false)
			for appearance: String in ["light", "dark"]:
				_prefs.values.appearance = appearance
				_prefs.changed.emit()
				await _settle()
				_check(Rect2(Vector2.ZERO, root.size).encloses(main.stage_hud.goal_card.get_global_rect()), "strip fits " + locale + appearance)
				main.stage_hud.parts_requested.emit()
				main.stage_hud.program_requested.emit()
				_check(not main._ui_root.get_node("PartsLibrary").visible and main._side_panel.visible, "only one manually opened overlay")
				main.program_tabs.current_tab = 2
				await _settle()
				for card: Control in main.blocks.rows.get_children():
					if card is not VBoxContainer:
						continue
					var line: HFlowContainer = card.get_child(0)
					var height: float = 0.0
					for token: Control in line.get_children():
						if token.visible:
							height = maxf(height, token.size.y)
					_check(line.size.y <= height + 1.0, "default blocks are one action line " + level.id + locale)
				await _capture(level.id + "-" + locale + "-" + appearance)
			root.size = Vector2i(1152, 648)
			_prefs.values.text_scale = 2.0
			_prefs.changed.emit()
			await _settle()
			_check(main._side_panel.get_global_rect().position.y >= main.stage_hud.goal_card.get_global_rect().end.y, "enlarged compact panels remain below strip")
			_check(Rect2(Vector2.ZERO, root.size).encloses(main.stage_hud.run_action.get_global_rect()), "enlarged compact run action fits " + locale)
			await _capture(level.id + "-" + locale + "-compact")
			root.size = Vector2i(1440, 900)
			_prefs.values.text_scale = 1.0
			_prefs.changed.emit()
		main.stage_hud.show_failure("The program stopped with an error. Fix the highlighted code and try again.")
		await _settle()
		_check(not main.stage_hud.run_action.visible and main.stage_hud.retry_button.theme_type_variation == &"PrimaryButton", "result has a single primary action")
		_check(main.stage_hud.find_child("ListButton", true, false) == null, "result only offers retry and next")
		main.stage_hud.retry_button.pressed.emit()
		main._open_settings()
		await _settle()
		main.settings.close_panel()
		await _settle()
		_check(main.stage_hud.help_action.has_focus(), "settings returns keyboard focus to visible Help")
		main.free()
		await _settle()
	var lab: Node3D = load("res://scenes/main.tscn").instantiate()
	lab.session = {"mode": "lab"}
	root.add_child(lab)
	await _settle()
	_check(lab._guide_phase == 0 and lab._ui_root.get_node("PartsLibrary").visible and not lab._side_panel.visible, "Lab opens parts for empty assembly")
	_check(not lab.examples_menu.visible and lab._starter_controls.all(func(c: Control) -> bool: return not c.visible), "starter answers leave the parts tray")
	lab._on_microbit_arm_pressed()
	await _settle()
	_check(not lab.flag_mission.visible and lab._guide_phase == 3, "a help example retains the scene layout and advances actual steps")
	await _capture("lab")
	lab.free()
	await _settle()
	print("scene_workshop_ui_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
