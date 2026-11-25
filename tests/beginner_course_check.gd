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
