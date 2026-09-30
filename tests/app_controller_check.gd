extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var api := AppController.new()
	api.app = main
	var scene: Dictionary = api.invoke("get_scene")
	_check(scene.data.graph.is_empty() or scene.data.graph.parts.is_empty(), "read-only scene query")
	_check(api.invoke("list_parts").data.size() >= 20, "catalog includes concrete ports")
	_check(api.invoke("set_program", {"source": "x = 1"}, api.revision).get("error") == "edits_disabled", "read-only capability is default")
	api.allow_edits = true
	_check(api.invoke("set_program", {"source": "x = 1"}, api.revision - 1).get("error") == "stale_revision", "stale edits rejected")
	_check(api.invoke("place_part", {"id": "base", "transform": [1,0,0,0,1,0,0,0,1,0,0.06,0]}, api.revision).has("data"), "part placement uses assembly path")
	_check(api.invoke("place_part", {"id": "../secret", "transform": []}, api.revision).has("error"), "arbitrary resources rejected")
	_check(api.invoke("remove_part", {"part": -1}, api.revision).has("error"), "invalid indices rejected")
	_check(api.invoke("set_program", {"source": "while True:\n    pass"}, api.revision).has("data"), "explicit code application")
	_check(not main.mode_button.button_pressed, "setting source never runs it")
	api.record_events = true
	_check(api.invoke("run", {}, api.revision).data.running, "agent run uses learner VM")
	for tick: int in 3:
		await physics_frame
	_check(api.invoke("get_result").data.running, "observe running simulation")
	api.allow_edits = false
	_check(api.invoke("stop").data.running == false and not main.runtime.is_running(), "local stop works without edit capability")
	_check(api.events.size() >= 3 and api.events[0].origin == "agent", "opt-in local journal distinguishes origin")
	_check(api.invoke("execute").get("error") == "unknown_tool", "tool dispatch cannot execute arbitrary methods")
	main.free()
	await process_frame
	await process_frame
	print("app_controller_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
