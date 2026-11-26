extends SceneTree

## Beginner course (E3): five levels, semi-assembled starts without power cables, a
## per-level parts tray, wiring-only first levels, tier 1 power and an unlock line.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + message)


func _settle() -> void:
	for tick: int in 8:
		await process_frame


func _tab_visible(main: Node3D, tab: String) -> bool:
	for index: int in main.program_tabs.get_tab_count():
		if main.program_tabs.get_tab_control(index).name == tab:
			return not main.program_tabs.is_tab_hidden(index)
	return false


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame


func _load_hint_answer(main: Node3D, level: Dictionary, stage: Dictionary, expected_power_wires: int) -> void:
	var hud: StageHud = main.stage_hud
	var before: Dictionary = MotionSnapshot.encode(main.assembly.graph)
	var answer: ConnectionGraph = StageLevels.starting_graph(level, stage, true)
	hud.hint_action.grab_focus()
	await _key(KEY_ENTER)
	_check(hud.hint_panel.is_visible_in_tree() and hud.hint_action.button_pressed, level.id + " Enter opens the answer hint")
	_check(MotionSnapshot.encode(main.assembly.graph) == before and main.code_edit.text == level.starter_code, level.id + " opening the hint preserves the build and source")
	var power_wires: int = 0
	for label: Label in hud._hint_wire_labels:
		var wire: Dictionary = label.get_meta("answer_wire")
		power_wires += int(wire.target_port == PowerNet.POWER_IN)
		_check(label.text.contains(" → ") and not label.text.contains(String(wire.source_port)), level.id + " lists a learner-facing wire direction")
		_check(label.text.begins_with("#%d " % (wire.source_part + 1))
			and label.text.contains(" → #%d " % (wire.target_part + 1)), level.id + " shows both matching Wiring part numbers")
	_check(power_wires == expected_power_wires, level.id + " lists exactly the power wires for this answer")
	var code: Label = hud.hint_panel.find_child("AnswerCode", true, false)
	if level.id == "raise-flag":
		_check(code != null and code.text == stage.author_solution.source.strip_edges(), "the flag hint previews the actual author code")
	else:
		_check(code == null, level.id + " has no code preview in its wiring-only hint")
	if level.id == "light-on":
		var power_link: Dictionary = answer.links.filter(func(link: Dictionary) -> bool: return link.b_port == PowerNet.POWER_IN)[0]
		main._reveal_tab("Wiring")
		var wiring: WiringPanel = main.wiring_panel
		var input: int = wiring.sources.find({"part": power_link.b_part, "port": power_link.b_port})
		_check(input >= 0, "the hinted power input appears in Wiring")
		if input >= 0:
			wiring.source_choice.select(input)
			wiring.source_choice.item_selected.emit(input)
			var output: int = wiring.pins.find({"part": power_link.a_part, "port": power_link.a_port})
			_check(output >= 0, "the hinted output is compatible")
			if output >= 0:
				wiring.pin_choice.select(output)
				wiring.pin_choice.item_selected.emit(output)
				wiring.connect_button.pressed.emit()
				_check(PowerNet.evaluate(main.assembly.graph).problems.is_empty() and hud.hint_panel.visible, "the learner can make the circuit with the hint open")
	await _key(KEY_ESCAPE)
	_check(not hud.hint_panel.visible and hud.hint_action.has_focus(), level.id + " Escape closes the hint and returns focus")
	hud.hint_action.button_pressed = true
	hud.hint_action.button_pressed = false
	_check(not hud.hint_panel.visible, level.id + " the button also toggles the hint closed")
	hud.hint_action.button_pressed = true
	hud.hint_answer_action.pressed.emit()
	_check(not hud.hint_panel.visible and not main.run_mode.is_built() and hud.run_action.has_focus(), level.id + " loading the answer returns to Run without executing")
	_check(main._used_solution and main.code_edit.text == stage.author_solution.source, level.id + " loading uses the author program and marks the attempt")
	_check(MotionSnapshot.encode(main.assembly.graph) == MotionSnapshot.encode(answer), level.id + " loading applies the exact answer graph")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	StageProgress.path = "user://beginner_course_check.json"
	DirAccess.remove_absolute(StageProgress.path)
	var levels: Array[Dictionary] = StageLevels.all()
	var ids: Array = levels.map(func(level: Dictionary) -> String: return level.id)
	_check(ids == ["light-on", "finish-line", "raise-flag", "wall-brake", "first-robot"], "five beginner levels in order")
	for index: int in levels.size():
		var level: Dictionary = levels[index]
		var stage: Dictionary = StageLevels.stage_definition(level)
		_check(not stage.is_empty(), level.id + " has a stage definition")
		_check(int(level.power_tier) == 1, level.id + " uses tier 1 power")
		_check(level.parts.size() < PartTray.ids().size(), level.id + " limits the tray")
		_check(StageLevels.has_code(level) == (index >= 2), level.id + " code tabs from level 3")
		var answer: ConnectionGraph = StageLevels.starting_graph(level, stage, true)
		for part: Dictionary in answer.parts:
			if part.part_def.id != &"stage_wall":
				_check(String(part.part_def.id) in level.parts, level.id + " answer part is in the tray: " + String(part.part_def.id))
		_check(PowerNet.evaluate(answer).problems.is_empty(), level.id + " answer is fully powered")
		_check(not PowerNet.evaluate(StageLevels.starting_graph(level, stage, false)).problems.is_empty(), level.id + " start is missing power")
	_check(levels[0].parts.size() <= 4, "level 1 shows at most four parts")

	for index: int in levels.size():
		var level: Dictionary = levels[index]
		var stage: Dictionary = StageLevels.stage_definition(level)
		var main: Node3D = load("res://scenes/main.tscn").instantiate()
		main.session = {"mode": "stage", "level": level}
		root.add_child(main)
		await _settle()
		var shown: int = 0
		for button: Button in main.part_buttons:
			if button.visible:
				shown += 1
				_check(String((button.get_meta("part_definition") as PartDef).id) in level.parts, level.id + " tray shows only level parts")
		var offered: int = level.parts.filter(func(id: String) -> bool: return id in PartTray.ids()).size()
		_check(shown == offered, level.id + " tray shows every level part (%d/%d)" % [shown, offered])
		_check(_tab_visible(main, "Wiring"), level.id + " wiring tab")
		_check(_tab_visible(main, "Code") == StageLevels.has_code(level) and _tab_visible(main, "Blocks") == StageLevels.has_code(level), level.id + " code/blocks tabs follow the level")
		_check(main.stage_hud.chips[2].visible == StageLevels.has_code(level), level.id + " code step chip follows the level")
		_check(main.stage_hud.hint_action.is_visible_in_tree() == (index < 3), level.id + " the HUD Hint action is limited to stages 1–3")
		if level.start == "partial":
			_check(not main.assembly.graph.parts.is_empty() and main.code_edit.text == level.starter_code, level.id + " starts semi-assembled with its program")
			# Running before wiring power must not clear the stage.
			main._on_run_pressed()
			for tick: int in 90:
				await physics_frame
			_check(not main.stages.evaluator.success, level.id + " does not clear without power")
			main._reset_attempt()
			await _settle()
		else:
			_check(main.assembly.graph.parts.is_empty(), level.id + " starts on an empty workbench")
		if index < 3:
			await _load_hint_answer(main, level, stage, [1, 2, 2][index])
		else:
			main._load_preset(StageLevels.starting_graph(level, stage, true), stage.author_solution.source, "")
		main._on_run_pressed()
		for tick: int in 1200:
			await physics_frame
			if main.stages.evaluator.status in ["success", "not_met", "indeterminate"]:
				break
		print("BEGINNER_RESULT ", level.id, " ", JSON.stringify(main.stages.evaluator.result()))
		_check(main.stages.evaluator.success, level.id + " powered answer clears in physics")
		await _settle()
		var has_next: bool = index < levels.size() - 1
		_check(main.stage_hud.result.visible, level.id + " result card shown")
		_check(main.stage_hud.unlock_label.visible == has_next, level.id + " unlock line only when a next stage exists")
		if has_next:
			_check(main.stage_hud.next_button.visible, level.id + " next stage button")
		main.free()
		await _settle()
	DirAccess.remove_absolute(StageProgress.path)
	print("beginner_course_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
