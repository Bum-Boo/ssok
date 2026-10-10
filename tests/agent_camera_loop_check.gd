extends SceneTree

var app: Node3D
var checks: int = 0
var failures: int = 0
var loop: AgentCameraLoop


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	app = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(app)
	await process_frame
	root.get_node("Preferences").set_preference("appearance", "dark")
	loop = app.agent_loop
	if DisplayServer.get_name() == "headless":
		_check(loop.begin().get("error") == "rendered_desktop_required", "headless cannot fabricate camera observations")
		app.free()
		_finish()
		return
	app._load_preset(RobotCarPreset.build(0.8), RobotCarPreset.BRAKE_CODE, "")
	_check(not app.agent_panel._enable_button.disabled, "graph load refreshes agent readiness")
	app.control_source.select(app.CONTROL_CODE)
	app.mode_button.button_pressed = true
	app.program_tabs.current_tab = app.agent_panel.get_index()
	loop.begin()
	await _ready_frame()
	if loop.state != "ready":
		_finish()
		return
	if "--capture-only" in OS.get_cmdline_user_args():
		await _screenshots()
		app.free()
		_finish()
		return
	var first: Dictionary = loop.metadata.duplicate()
	var image := Image.new()
	_check(image.load_png_from_buffer(loop.png) == OK and image.get_size() == Vector2i(640, 480), "real sensor PNG decoded")
	_check(first.part_id == 0 and first.robot_instance_id == str(app.run_mode.bodies[0].get_instance_id()), "camera refers to graph-derived body")
	_check(first.settle_confirmed_tick <= first.capture_requested_tick and first.capture_requested_tick <= first.physics_tick, "capture follows measured settling")
	_save("sensor-before.png", loop.png)
	var origin: Vector3 = app.run_mode.bodies[0].global_position
	var args: Dictionary = _action(first)
	var other_episode: Dictionary = args.duplicate()
	other_episode.episode_id = "different-episode"
	_check(loop.drive_step(other_episode).get("error") == "stale_observation", "another episode cannot command current robot")
	_check(loop.drive_step(args).get("pending", false), "bounded step accepted")
	await _wait_ready()
	var travel: float = app.run_mode.bodies[0].global_position.x - origin.x
	print("measured_forward_m=", travel, " velocity=", app.run_mode.bodies[0].linear_velocity.length())
	_check(travel > 0.008, "actual forward travel, not stay-still success")
	_check(app.run_mode.bodies[0].linear_velocity.length() <= 0.015, "measured body settled after braking")
	_check(loop.drive_step(args).get("error") == "stale_observation", "consumed frame cannot command twice")
	loop.observe()
	await _ready_frame()
	_check(loop.frame_id > first.frame_id and loop.metadata.sha256 != first.sha256, "re-observation is new rendered content")
	_check(loop.drive_step(args).get("error") == "stale_observation", "old frame rejected after recapture")
	_save("sensor-after.png", loop.png)
	var bad: Dictionary = _action(loop.metadata)
	bad.ticks = 31
	_check(loop.drive_step(bad).get("error") == "invalid_action" and not loop.enabled, "oversized action revokes ownership")
	_check(app.run_mode.motor_on_pin(0).duty == 0, "invalid request leaves brake engaged")
	loop.begin()
	await _ready_frame()
	var late: Dictionary = _action(loop.metadata)
	loop.drive_step(late)
	var generation: int = loop.control_generation
	app._on_stop_pressed()
	await physics_frame
	_check(not loop.enabled and loop.control_generation > generation and app.run_mode.motor_on_pin(0).duty == 0, "local Stop brakes by next physics tick")
	_check(loop.drive_step(late).has("error"), "late response after Stop cannot restart")
	loop.begin()
	await _ready_frame()
	app.code_edit.text += "\n# changed"
	await process_frame
	_check(not loop.enabled, "human source change revokes old context")
	loop.begin()
	await _ready_frame()
	app._on_control_source_selected(app.CONTROL_CODE)
	_check(not loop.enabled, "mode handoff revokes agent")
	loop.begin()
	await _ready_frame()
	loop._deadline = Time.get_ticks_msec() - 1
	await process_frame
	await process_frame
	_check(not loop.enabled and loop.state == "fault", "decision timeout stops without automatic retry")
	loop.begin()
	await _ready_frame()
	# Force is a failure-injection fixture only; the production actuator never adds translation forces.
	app.run_mode.bodies[0].constant_force = Vector3(0, 50.0, 0)
	app.run_mode.bodies[0].sleeping = false
	for tick: int in 3:
		await physics_frame
	loop.observe()
	for tick: int in 300:
		await physics_frame
		if not loop.enabled:
			break
	_check(not loop.enabled and loop.state == "fault", "unsettled physics fails closed")
	app.run_mode.bodies[0].constant_force = Vector3.ZERO
	app.mode_button.button_pressed = false
	app.mode_button.button_pressed = true
	loop.begin()
	await _ready_frame()
	await _screenshots()
	app.free()
	_finish()


func _ready_frame() -> void:
	await _wait_ready()
	_check(loop.state == "ready" and not loop.png.is_empty(), "rendered observation ready (" + loop.state + ")")


func _wait_ready() -> void:
	for tick: int in 600:
		await physics_frame
		if loop.state in ["ready", "fault", "stopped"]:
			return


func _action(meta: Dictionary) -> Dictionary:
	return {"episode_id": meta.episode_id, "frame_id": meta.frame_id, "revision": meta.revision, "control_generation": meta.control_generation, "ticks": 20, "action": "forward"}


func _screenshots() -> void:
	app.program_tabs.current_tab = app.agent_panel.get_index()
	app.get_viewport().gui_release_focus()
	var receipt: Dictionary = loop.receipt({"episode_id": loop.episode_id, "frame_id": loop.frame_id, "control_generation": loop.control_generation, "sha256": loop.metadata.sha256, "summary": "UI rendering fixture: short forward, then inspect a new frame.", "provider": "UI test fixture", "max_calls": 8})
	_check(receipt.get("receipt") == "hash_matched", "reported receipt matches displayed frame")
	for locale: String in ["en", "ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(locale, false)
		for frame: int in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		_save("panel-" + locale + ".png", root.get_texture().get_image().save_png_to_buffer())
	root.size = Vector2i(1152, 648)
	for frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("panel-compact.png", root.get_texture().get_image().save_png_to_buffer())
	root.get_node("Preferences").set_preference("appearance", "light")
	for frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("panel-light.png", root.get_texture().get_image().save_png_to_buffer())
	app.agent_panel._scroll.scroll_vertical = 100000
	for frame: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("panel-scrolled.png", root.get_texture().get_image().save_png_to_buffer())
	app.agent_panel._scroll.scroll_vertical = 0
	loop.drive_step(_action(loop.metadata))
	for tick: int in 2:
		await physics_frame
	await RenderingServer.frame_post_draw
	_save("panel-driving.png", root.get_texture().get_image().save_png_to_buffer())
	app._on_stop_pressed()
	await physics_frame
	_check(app.run_mode.motor_on_pin(0).duty == 0 and not loop.enabled, "pinned Stop during screenshot action brakes")


func _save(name: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute("user://agent-loop-evidence")
	var file: FileAccess = FileAccess.open("user://agent-loop-evidence/" + name, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _finish() -> void:
	print("agent_camera_loop_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
