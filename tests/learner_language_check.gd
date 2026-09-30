extends SceneTree

var failures: int = 0
var checks: int = 0
var runtime: MiniRuntime
var errors: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	runtime = MiniRuntime.new()
	root.add_child(runtime)
	runtime.failed.connect(func(line: int, message: String) -> void: errors.append([line, message]))
	var program: String = "x = 0\nwhile x < 5:\n    x = x + 1\n    if x == 2:\n        continue\n    elif x == 4:\n        break\n    else:\n        pass\ny = x * 2 + 3\nz = not False and y == 11"
	_check(runtime.validate(program, false).is_empty(), "nested AST with elif/else/continue/break")
	await runtime.run(program)
	_check(runtime._variables.get("x") == 4 and runtime._variables.get("y") == 11 and runtime._variables.get("z") == true, "variables, arithmetic and control flow")
	_check(runtime.validate("if True\n    pass", false).get("line") == 1, "missing colon has source line")
	_check(runtime.validate("while True:\npass", false).get("line") == 1, "missing indentation")
	_check(not runtime.validate("if x = 2:\n    pass", false).is_empty(), "assignment in condition rejected")
	_check(runtime.validate("counter = 1\nx = countr + 1", false).get("error", "").contains("counter"), "name typo suggests nearby declared name")
	_check(not runtime.validate("break", false).is_empty(), "break outside loop rejected")
	_check(not runtime.validate("while True:\n    "+"(".repeat(40)+"True"+")".repeat(40), false).is_empty(), "bounded expression nesting")
	runtime.run("while True:\n    pass")
	_check(runtime.is_running(), "infinite loop yields to caller")
	for tick: int in 5:
		await physics_frame
	_check(runtime.is_running(), "scene ticks continue during infinite loop")
	runtime.stop()
	_check(not runtime.is_running(), "stop immediately interrupts infinite loop")
	runtime.run("sleep(0.1)\nx = 7")
	_check(runtime.is_running(), "sleep yields")
	await runtime.settled
	_check(runtime._variables.get("x") == 7 and runtime._ticks >= 6, "sleep uses physics ticks")
	await runtime.run("x = 1 / 0")
	_check(not errors.is_empty() and not runtime.is_running(), "division by zero is controlled failure")
	await process_frame
	runtime.free()
	print("learner_language_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
