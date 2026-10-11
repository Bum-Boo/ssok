extends SceneTree

## Rendered observer regression: ready or driving context changes cannot certify stale metrics.
var app: Node3D
var evaluator: Node
var events: Array[Dictionary] = []
var checks: int = 0
var failures: int = 0
var mode: String = "normal_stop"
var phase: String = "initialize"
var action_mode: String = "normal_stop"
var started_msec: int = Time.get_ticks_msec()


func _initialize() -> void:
	_run.call_deferred()


func _progress(label: String) -> void:
	phase = label
	var row: Dictionary = {"mode": mode, "phase": label,
		"elapsed_msec": Time.get_ticks_msec() - started_msec,
		"physics_tick": Engine.get_physics_frames()}
	if is_instance_valid(app) and is_instance_valid(app.agent_loop):
		row.merge({"state": app.agent_loop.state, "enabled": app.agent_loop.enabled,
			"episode_id": app.agent_loop.episode_id, "generation": app.agent_loop.control_generation})
	if is_instance_valid(evaluator):
		row.merge({"evaluator_started": evaluator.started, "evaluator_finished": evaluator.finished})
	var file: FileAccess = FileAccess.open("user://lifecycle-progress.jsonl", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://lifecycle-progress.jsonl", FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(JSON.stringify(row))
	print("LIFECYCLE_PROGRESS ", JSON.stringify(row))


func _wait_ready(require_evaluator: bool) -> bool:
	var deadline: int = Time.get_ticks_msec() + 25000
	for tick: int in 900:
		await physics_frame
		if app.agent_loop.state == "ready" and (not require_evaluator or evaluator.started):
			_progress("ready")
			return true
		if not app.agent_loop.enabled or app.agent_loop.state == "fault":
			_progress("ready_fault")
			return false
		if Time.get_ticks_msec() >= deadline:
			_progress("ready_deadline")
			return false
		if tick % 60 == 0:
			_progress("waiting_ready")
	_progress("ready_tick_budget")
	return false


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--lifecycle-mode")
	if index >= 0 and index + 1 < args.size():
		mode = args[index + 1]
	var driving_modes: Dictionary = {"driving_stop": "normal_stop", "driving_rebuild": "rebuild",
		"driving_app_free": "app_free", "driving_new_episode": "new_episode"}
	action_mode = driving_modes.get(mode, mode)
	if DisplayServer.get_name() == "headless":
		print("Rendered lifecycle regression required")
		quit(2)
		return
	for name: String in ["camera-evaluation.json", "camera-calibration.jsonl", "lifecycle-result.json", "lifecycle-progress.jsonl"]:
		var path: String = "user://" + name
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK,
				"previous process evidence cleared before this case")
	_progress("before_main_load")
	root.size = Vector2i(1600, 1000)
	app = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(app)
	_progress("main_added")
	await process_frame
	_progress("before_preset")
	app._load_preset(RobotCarPreset.build(0.6), RobotCarPreset.BRAKE_CODE, "")
	app.control_source.select(app.CONTROL_CODE)
	app.mode_button.button_pressed = true
	app.program_tabs.current_tab = app.agent_panel.get_index()
	app.agent_loop.event_recorded.connect(func(event: Dictionary) -> void: events.append(event.duplicate(true)))
	# Finish scene shader setup before the unchanged finite camera-operation watchdog.
	_progress("warming_rendered_scene")
	for frame: int in 2:
		await RenderingServer.frame_post_draw
	app.agent_loop.begin()
	_progress("loop_started")
	evaluator = load("res://tools/app_control/camera_evaluator.gd").new()
	evaluator.app = app
	root.add_child(evaluator)
	_check(await _wait_ready(true), "real graph camera ready and evaluator started")
	if failures > 0:
		_finish()
		return
	var old_body: int = app.run_mode.bodies[0].get_instance_id()
	var old_generation: int = app.agent_loop.control_generation
	var old_episode: String = app.agent_loop.episode_id
	if mode == "drive_stop":
		for step: int in 3:
			var meta: Dictionary = app.agent_loop.metadata
			var result: Dictionary = app.agent_loop.drive_step({"episode_id": meta.episode_id,
				"frame_id": meta.frame_id, "revision": meta.revision,
				"control_generation": meta.control_generation, "action": "forward", "ticks": 25})
			_check(result.get("pending") == true, "finite real motor action accepted")
			_progress("drive_step_" + str(step))
			_check(await _wait_ready(false), "motor action reaches measured rest")
			if failures > 0:
				_finish()
				return
			app.agent_loop.observe()
			_check(await _wait_ready(false), "fresh rendered observation after drive")
			if failures > 0:
				_finish()
				return
	if mode.begins_with("driving_"):
		var meta: Dictionary = app.agent_loop.metadata
		var response: Dictionary = app.agent_loop.drive_step({"episode_id": meta.episode_id,
			"frame_id": meta.frame_id, "revision": meta.revision,
			"control_generation": meta.control_generation, "action": "forward", "ticks": 25})
		_check(response.get("pending") == true, "real pending drive accepted before context action")
		for tick: int in 5:
			await physics_frame
		_check(app.agent_loop.enabled and app.agent_loop.state == "driving", "context action happens during real active drive")
		_progress("drive_pending")
		if failures > 0:
			_finish()
			return
	_progress("before_context_action")
	match action_mode:
		"normal_stop", "drive_stop":
			app._on_stop_pressed()
		"teardown":
			app.run_mode.teardown()
		"mode_off":
			app.mode_button.button_pressed = false
		"app_free":
			app.free()
		"rebuild":
			app.run_mode.build(app.assembly.graph)
		"new_episode":
			app.agent_loop.begin()
		_:
			_check(false, "known mode")
	_progress("context_action_done")
	var first_result: String = ""
	var first_calibration: String = ""
	if action_mode not in ["normal_stop", "drive_stop"]:
		for tick: int in 2:
			await physics_frame
		_check(evaluator.finished and FileAccess.file_exists("user://camera-evaluation.json"), "invalid context finishes observer promptly")
		if FileAccess.file_exists("user://camera-evaluation.json"):
			first_result = FileAccess.get_file_as_string("user://camera-evaluation.json")
		if FileAccess.file_exists("user://camera-calibration.jsonl"):
			first_calibration = FileAccess.get_file_as_string("user://camera-calibration.jsonl")
	var settle_deadline: int = Time.get_ticks_msec() + 20000
	for tick: int in 165:
		await physics_frame
		if Time.get_ticks_msec() >= settle_deadline:
			_check(false, "bounded post-action physical observation")
			break
	_progress("after_observation")
	var evaluation: Dictionary = {}
	if FileAccess.file_exists("user://camera-evaluation.json"):
		evaluation = JSON.parse_string(FileAccess.get_file_as_string("user://camera-evaluation.json"))
	_check(not evaluation.is_empty(), "explicit final evaluator result exists")
	if action_mode in ["normal_stop", "drive_stop"]:
		_check(evaluation.get("valid") == true and evaluation.get("stopped_state") == "stopped",
			"local Stop retains valid physical measurement")
		_check(evaluation.get("final", {}).has("gap_x"), "Stop retains measured gap")
		_check(not app.agent_loop.enabled and app.agent_loop.control_generation > old_generation,
			"local Stop revokes generation")
		for motor: DriveMotor in app.run_mode.motors.values():
			_check(motor.duty == 0.0, "local Stop clears all motor duty")
		if mode == "drive_stop":
			_check(float(evaluation.get("travel_x", 0.0)) > 0.03, "control includes over 3cm real motor travel")
			_check(int(evaluation.get("rest_ticks", 0)) >= 12, "stopped robot has measured rest")
	else:
		_check(evaluation.get("valid") == false, "invalid context never certifies physical success")
		_check(not str(evaluation.get("invalid_reason", "")).is_empty(), "invalid result names its reason")
		var reasons: Dictionary = {"teardown": ["physics_removed"], "mode_off": ["physics_removed"],
			"app_free": ["app_removed"], "rebuild": ["body_removed", "body_context_changed"],
			"new_episode": ["episode_changed"]}
		_check(evaluation.get("invalid_reason") in reasons.get(action_mode, []), "reason identifies the intended context change")
		_check(not evaluation.get("final", {}).has("gap_x"), "invalid result contains no stale final gap")
	if is_instance_valid(app) and action_mode in ["teardown", "mode_off", "rebuild"]:
		_check(not app.agent_loop.enabled and app.agent_loop.control_generation > old_generation,
			"real loop revokes old generation")
	if is_instance_valid(app) and action_mode == "rebuild":
		_check(app.run_mode.bodies[0].get_instance_id() != old_body, "same graph rebuild replaces body context")
	if is_instance_valid(app) and action_mode == "new_episode":
		_check(app.agent_loop.enabled and app.agent_loop.episode_id != old_episode,
			"observer leaves replacement owner enabled")
	if action_mode not in ["normal_stop", "drive_stop"]:
		_check(not first_result.is_empty() and FileAccess.get_file_as_string("user://camera-evaluation.json") == first_result,
			"invalid result bytes remain unchanged across later physics frames")
		var calibration: String = ""
		if FileAccess.file_exists("user://camera-calibration.jsonl"):
			calibration = FileAccess.get_file_as_string("user://camera-calibration.jsonl")
		_check(calibration == first_calibration, "invalid observer appends no later calibration or replacement-frame samples")
	if mode == "driving_stop":
		_check(int(evaluation.get("rest_ticks", 0)) >= 12, "pending local Stop reaches measured physical rest")
	_write_result(evaluation)
	_finish()


func _write_result(evaluation: Dictionary = {}) -> void:
	var file: FileAccess = FileAccess.open("user://lifecycle-result.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"mode": mode, "phase": phase, "checks": checks,
			"failures": failures, "events": events, "evaluation": evaluation,
			"elapsed_msec": Time.get_ticks_msec() - started_msec}, "\t") + "\n")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("LIFECYCLE_FAIL: ", label)


func _finish() -> void:
	if not FileAccess.file_exists("user://lifecycle-result.json"):
		_write_result()
	_progress("cleanup")
	if is_instance_valid(evaluator):
		evaluator.free()
	if is_instance_valid(app):
		app.free()
	print("camera_evaluator_lifecycle ", mode, ": ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
