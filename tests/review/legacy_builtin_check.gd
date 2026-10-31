extends SceneTree

## Review repro: stage definitions exported by main's StageCatalog must still parse and clear
## with their own author solutions in Lab on this branch (old indexed/kind metric semantics).

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var stages: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("REVIEW_IN") if OS.has_environment("REVIEW_IN") else "res://tests/review/fixtures/main/main_builtins.json"))
	for raw: Variant in stages:
		var stage: Dictionary = StageDefinition.parse(JSON.stringify(raw, "", true, true))
		_check(not stage.is_empty(), "main stage parses: " + String(raw.id))
		if stage.is_empty():
			continue
		var main: Node3D = load("res://scenes/main.tscn").instantiate()
		main.session = {"mode": "lab"}
		root.add_child(main)
		for tick: int in 8:
			await process_frame
		main._load_preset(ProjectStore.graph_from(stage.author_solution), stage.author_solution.source, "")
		main.stages.load_goal(stage)
		main._on_run_pressed()
		for tick: int in 1500:
			await physics_frame
			if main.stages.evaluator.status in ["success", "not_met", "indeterminate"]:
				break
		print("LEGACY_RESULT ", stage.id, " ", main.stages.evaluator.status, " ", main.stages.evaluator.reason, " ", JSON.stringify(main.stages.evaluator.measurements))
		_check(main.stages.evaluator.success, stage.id + " main-authored stage clears with its author solution in Lab")
		main.free()
		for tick: int in 4:
			await process_frame
	print("legacy_builtin_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
