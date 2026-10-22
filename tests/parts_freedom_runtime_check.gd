extends SceneTree

var checks: int = 0
var failures: int = 0
var runtime: MiniRuntime
var run_mode: RunMode


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	runtime = MiniRuntime.new()
	root.add_child(runtime)
	await runtime.run("total = 0\nfor i in range(5):\n    total = total + i\nfor j in range(6, 0, -2):\n    total = total + j")
	_check(runtime._variables.get("total") == 22 and runtime._variables.get("j") == 2, "one and three argument ranges")
	await runtime.run("n = 3\ntotal = 0\nfor i in range(1, n):\n    for j in range(4):\n        if j == 1:\n            continue\n        elif j == 3:\n            break\n        total = total + j\n    n = 99")
	_check(runtime._variables.get("total") == 4 and runtime._variables.get("i") == 2, "nested ranges, continue, break and bounds evaluated once")
	await runtime.run("x = 8\nfor i in range(0):\n    x = 0\nfor j in range(1, 4, -1):\n    x = 0\ny = 2 + 3 * 4 == 14 and not False\nz = False and 1 / 0 == 0")
	_check(runtime._variables.get("x") == 8 and runtime._variables.get("y") and not runtime._variables.get("z"), "empty ranges, precedence and short circuit")
	for source: String in ["for i in range(1, 2, 0):\n    pass", "for i in range(1.5):\n    pass", "for i in range(10001):\n    pass", "for Servo in range(3):\n    pass", "for i in range(range(2)):\n    pass", "x = range(2)", "break"]:
		_check(not runtime.validate(source, false).is_empty(), "preflight rejects: " + source.get_slice("\n", 0))
	for source: String in ["n = 10001\nfor i in range(n):\n    pass", "step = 0\nfor i in range(0, 3, step):\n    pass", "n = 1.5\nfor i in range(n):\n    pass"]:
		await runtime.run(source)
		_check(runtime.state == "failed", "dynamic range bounds fail safely")
	runtime.run("for i in range(10000):\n    pass")
	for step: int in 1000:
		if not runtime.is_running():
			break
		runtime._step()
	_check(runtime.state == "finished" and runtime._iterations == MiniRuntime.MAX_LOOP_ITERATIONS, "exact iteration boundary is allowed")
	await process_frame
	runtime.run("while True:\n    pass")
	for step: int in 1000:
		if not runtime.is_running():
			break
		runtime._step()
	_check(runtime.state == "failed" and runtime._iterations == MiniRuntime.MAX_LOOP_ITERATIONS + 1, "infinite while fails at total iteration limit")
	await process_frame
	runtime.run("for i in range(101):\n    for j in range(100):\n        pass")
	for step: int in 2000:
		if not runtime.is_running():
			break
		runtime._step()
	_check(runtime.state == "failed", "nested loops share total budget")
	await process_frame
	runtime.run("sleep(60)")
	runtime._ticks = int(MiniRuntime.MAX_EXECUTION_SECONDS * Engine.physics_ticks_per_second)
	runtime._step()
	_check(runtime.state == "failed", "simulated time limit checked even while sleeping")
	await process_frame
	runtime.run("sleep(60)")
	runtime._started_msec -= int(MiniRuntime.MAX_EXECUTION_SECONDS * 1000)
	runtime._step()
	_check(runtime.state == "failed", "wall clock execution limit")
	await process_frame
	await runtime.run("n = 0\nfor i in range(100):\n    n = n + 1")
	_check(runtime.state == "finished" and runtime._variables.get("n") == 100, "new execution resets budgets")

	run_mode = RunMode.new()
	root.add_child(run_mode)
	runtime.hardware = run_mode
	var graph: ConnectionGraph = RobotCarPreset.build(0.8)
	run_mode.build(graph)
	for body: RigidBody3D in run_mode.bodies:
		body.freeze = true
	await physics_frame
	await physics_frame
	_check(run_mode.motor_on_pins(0, 8) == run_mode.motor_on_pin(0), "two pins resolve same driver channel")
	_check(run_mode.motor_on_pins(0, 16) == null and run_mode.motor_on_pins(8, 0) == null, "mismatched and reversed driver pins rejected")
	await runtime.run("left = Motor(pin0, pin8)\nsonar = Sonar(pin1, pin2)\nd = sonar.distance()\nif d > 10 and d < 100:\n    left.forward(35)\nelse:\n    left.backward(20)")
	_check(runtime.state == "finished" and run_mode.motor_on_pin(0).duty > 0 and runtime._variables.get("d", 0) > 10, "real sonar value selects motor branch")
	await runtime.run("left = Motor(0, 8)\nleft.backward(25)")
	_check(is_equal_approx(run_mode.motor_on_pin(0).duty, -0.25), "backward sets signed motor power")
	await runtime.run("left = Motor(0, 8)\nleft.stop()")
	_check(run_mode.motor_on_pin(0).duty == 0 and run_mode.motor_on_pin(0).braking, "no argument stop brakes")
	await runtime.run("left = Motor(0, 8)\nleft.forward(20)\nmissing = Motor(0, 16)")
	_check(runtime.state == "failed" and run_mode.motor_on_pin(0).duty == 0, "whole source preflight rejects wrong pin pair before actuation")
	await runtime.run("left = Motor(0, 8)\nleft.forward(101)")
	_check(runtime.state == "failed" and run_mode.motor_on_pin(0).duty == 0, "invalid power fails and brakes")
	runtime.run("left = Motor(0, 8)\nleft.forward(20)\nwhile True:\n    sleep(1)")
	runtime._ticks = int(MiniRuntime.MAX_EXECUTION_SECONDS * Engine.physics_ticks_per_second)
	runtime._step()
	_check(runtime.state == "failed" and run_mode.motor_on_pin(0).duty == 0, "execution limit brakes a running motor")
	await process_frame
	runtime.run("left = Motor(0, 8)\nleft.forward(20)\nwhile True:\n    sleep(1)")
	runtime.stop()
	_check(run_mode.motor_on_pin(0).duty == 0 and runtime.state == "stopped", "Stop cancels loop and motors")
	await process_frame
	runtime.free()
	run_mode.free()
	await process_frame
	print("parts_freedom_runtime_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1
