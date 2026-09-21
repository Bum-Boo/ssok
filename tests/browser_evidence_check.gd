extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 950)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var observer: Node = preload("res://src/ui/browser_evidence.gd").new()
	main.add_child(observer)
	_check(not observer.is_physics_processing(), "ordinary native application does not run the Web observer")
	# Exercise the real observer through actual native app inputs; no simulation state is injected.
	observer.set_physics_process(true)
	main._on_learned_biped_pressed()
	main.mode_button.button_pressed = true
	for frame: int in 60:
		await physics_frame
	_check(observer.snapshot.ready, "observer resolves actual supported application bodies")
	_check(observer.snapshot.graph_fingerprint == observer.snapshot.policy_graph_fingerprint, "observer binds policy and actual graph")
	_check(observer.snapshot.runtime_fingerprint == observer.snapshot.policy_runtime_fingerprint, "observer binds policy and actual runtime")
	_key(KEY_W, true)
	for frame: int in 760:
		await physics_frame
	_check(observer.snapshot.has("walk"), "walk snapshot completes despite delayed test polling")
	if not observer.snapshot.has("walk"):
		main.free()
		quit(1)
		return
	var measured: Dictionary = observer.snapshot.walk.duplicate(true)
	_check(measured.frames == 720 and measured.seconds == 12.0 and measured.failure.is_empty(), "measurement freezes at exactly 720 intervals")
	_check(measured.finite and measured.minimum_upright >= 0.85 and measured.minimum_height > 0.09, "observer records actual upright trajectory")
	_check(measured.foot_air_frames.size() == 2 and measured.foot_air_frames.min() > 0, "both actual feet leave the floor")
	_check(measured.maximum_foot_clearance_m.min() > 0.0005, "both collision soles clear the floor by at least 0.5 mm")
	print("BROWSER_OBSERVER " + JSON.stringify(measured))
	_key(KEY_W, false)
	for frame: int in 120:
		await physics_frame
	_check(observer.snapshot.walk == measured, "completed measurement stays unchanged after stopping")
	_check(observer.snapshot.has("stop") and observer.snapshot.stop.frames == 90, "stop snapshot freezes at 90 intervals")
	_check(observer.snapshot.stop.command == [0.0, 0.0], "stop snapshot records released command")
	_check(observer.snapshot.stop.graph_fingerprint == measured.graph_fingerprint, "observation leaves authored graph unchanged")
	main.mode_button.button_pressed = false
	main.mode_button.button_pressed = true
	for frame: int in 60:
		await physics_frame
	_check(not observer.snapshot.has("walk"), "new run clears the previous measurement")
	_key(KEY_W, true)
	for frame: int in 30:
		await physics_frame
	_key(KEY_W, false)
	for frame: int in 10:
		await physics_frame
	_check(observer.snapshot.walk.failure == "command_released_before_horizon", "early W release remains an explicit failure")
	_check(observer.snapshot.walk.frames < 720, "incomplete measurements cannot claim the full horizon")
	main.free()
	print("browser_evidence_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
