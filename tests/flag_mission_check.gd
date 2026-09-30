extends SceneTree

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var mission: FlagMission = main.flag_mission
	_check(mission._phase == &"Intro", "mission starts before preset")
	mission._action.pressed.emit()
	await process_frame
	_check(main.assembly.graph.parts.size() == 4, "starter loads actual graph")
	_check(mission._phase == &"Ready", "linked arm and graph-wired servo reach ready")
	_check(mission._flag.visible, "flag follows graph part")
	main.run_button.pressed.emit()
	await process_frame
	_check(mission._phase == &"Running", "run enters observed task")
	var sampled_heights: Array[float] = []
	for index: int in 480:
		await physics_frame
		if index % 30 == 0:
			sampled_heights.append(mission._tip_position().y)
		if mission._phase == &"Success":
			break
	print("FLAG_OBSERVATIONS ", JSON.stringify({"start": mission._initial_tip_height, "minimum": mission._lowest_tip_height, "samples": sampled_heights, "phase": mission._phase, "steady": mission._steady_seconds}))
	_check(mission._phase == &"Success", "real simulated arm raises flag after moving")
	mission._action.pressed.emit()
	await process_frame
	_check(mission._phase == &"Ready" and not main.mode_button.button_pressed, "retry restores assembled edit state")
	main.code_edit.text = "from servo import Servo\narm = Servo(9)\narm.write(90)\n"
	main.run_button.pressed.emit()
	for frame: int in 180:
		await physics_frame
	_check(mission._phase == &"Running", "a low-only motion does not satisfy the observed height goal")
	main.stop_button.pressed.emit()
	for frame: int in 30:
		await physics_frame
	_check(mission._phase == &"Ready", "stop prevents a late task success")
	main.mode_button.button_pressed = false
	main.assembly.graph.links.pop_back()
	main.assembly.graph_changed.emit()
	_check(mission._phase == &"Wire", "removing the graph connection removes mission readiness")
	mission._sound.stop()
	mission._sound.stream = null
	mission = null
	main.free()
	main = null
	await process_frame
	await process_frame
	print("flag_mission_check: %d checks, %d failure(s)" % [_checks, _failures])
	quit(1 if _failures else 0)
