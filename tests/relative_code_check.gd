extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _runtime_errors: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4.0, 0.1, 4.0)
	collision.shape = shape
	floor.add_child(collision)
	floor.position.y = HumanoidPreset.FLOOR_TOP - 0.05
	root.add_child(floor)
	var graph: ConnectionGraph = HumanoidPreset.build()
	var first_wire: Dictionary = {}
	var second_wire: Dictionary = {}
	for link: Dictionary in graph.links:
		if link.a_port == &"signal":
			if first_wire.is_empty():
				first_wire = link
			elif second_wire.is_empty():
				second_wire = link
	var original_port: StringName = first_wire.b_port
	first_wire.b_port = second_wire.b_port
	second_wire.b_port = original_port
	var hardware: RunMode = RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var runtime: MiniRuntime = MiniRuntime.new()
	runtime.hardware = hardware
	root.add_child(runtime)
	runtime.failed.connect(func(line: int, message: String) -> void: _runtime_errors.append("%d:%s" % [line, message]))
	var pin: int = Wiring.pin_number(RunMode._port(graph.parts[first_wire.b_part].part_def, first_wire.b_port))
	var drive: ServoDrive = hardware.servo_on_pin(pin)
	_check(drive == hardware.servos[first_wire.a_part], "code address follows the actual rewired graph")
	await runtime.run("from servo import Servo\nhip = Servo(pin=%d)\nhip.write_relative(-30.5)" % pin)
	_check(_runtime_errors.is_empty() and not runtime.is_running(), "signed learner command parses and finishes")
	_check(drive.target_deg == -30.5, "negative fractional command reaches the wired motor")
	await runtime.run("hip = Servo(%d)\nhip.write_relative(-999)" % pin)
	_check(drive.target_deg == drive.relative_min_deg, "learner negative target obeys anatomical limit")
	await runtime.run("hip = Servo(%d)\nhip.write_relative(999)" % pin)
	_check(drive.target_deg == drive.relative_max_deg, "learner positive target obeys anatomical limit")
	await runtime.run("hip = Servo(%d)\nhip.write_relative(1 + 2)" % pin)
	_check(drive.target_deg == 3.0, "bounded arithmetic is accepted in a device argument")
	for expression: String in ["NAN", "INF", "__import__('os')"]:
		var previous: float = drive.target_deg
		var error_count: int = _runtime_errors.size()
		await runtime.run("hip = Servo(%d)\nhip.write_relative(%s)" % [pin, expression])
		_check(_runtime_errors.size() == error_count + 1 and drive.target_deg == previous, "nonliteral/generated expression is not executed")
	runtime.run("hip = Servo(%d)\nhip.write_relative(-10)\nsleep(0.2)\nhip.write_relative(-40)" % pin)
	_check(runtime.is_running() and drive.target_deg == -10.0, "asynchronous signed program starts")
	runtime.stop()
	await runtime.run("hip = Servo(%d)\nhip.write_relative(-20)" % pin)
	await create_timer(0.3).timeout
	_check(drive.target_deg == -20.0 and not runtime.is_running(), "cancelled sleep cannot overwrite the newer signed program")
	runtime.run("hip = Servo(%d)\nsleep(0.2)\nhip.write_relative(-50)" % pin)
	runtime.stop()
	hardware.teardown()
	hardware.build(graph)
	var replacement: ServoDrive = hardware.servo_on_pin(pin)
	await runtime.run("hip = Servo(%d)\nhip.write_relative(-12)" % pin)
	await create_timer(0.3).timeout
	_check(replacement.target_deg == -12.0, "cancelled old-graph program cannot mutate rebuilt hardware")
	runtime.stop()
	hardware.teardown()
	hardware.build(BipedPreset.build())
	var legacy_pin: int = hardware.wired_servo_channels()[0].pin
	var legacy_drive: ServoDrive = hardware.servo_on_pin(legacy_pin)
	await runtime.run("joint = Servo(%d)\njoint.write(-20)" % legacy_pin)
	_check(legacy_drive.target_deg == 0.0, "legacy write retains its nonnegative clamp")
	await runtime.run("joint = Servo(%d)\njoint.write(999)" % legacy_pin)
	_check(legacy_drive.target_deg == 180.0, "legacy write retains its180-degree maximum")
	await runtime.run("joint = Servo(%d)\njoint.write_relative(-999)" % legacy_pin)
	_check(legacy_drive.target_deg == -90.0, "legacy actuator supports bounded rest-relative command")
	runtime.stop()
	hardware.teardown()
	var modular_graph: ConnectionGraph = ModularHumanoidPreset.build()
	var wires: Array[Dictionary] = []
	for link: Dictionary in modular_graph.links:
		if link.a_port == &"signal":
			wires.append(link)
	var port: StringName = wires[0].b_port
	wires[0].b_port = wires[1].b_port
	wires[1].b_port = port
	hardware.build(modular_graph)
	var error_count: int = _runtime_errors.size()
	await runtime.run(ModularHumanoidPreset.answer_code(modular_graph))
	_check(_runtime_errors.size() == error_count and not runtime.is_running(), "rewired modular example runs in learner interpreter")
	for channel: Dictionary in hardware.wired_servo_channels():
		var actuator: ServoDrive = hardware.servo_on_pin(channel.pin)
		_check(actuator.powered and actuator.target_deg >= actuator.relative_min_deg and actuator.target_deg <= actuator.relative_max_deg, "each separately wired modular motor receives a bounded code command")
	runtime.stop()
	runtime.free()
	hardware.teardown()
	hardware.free()
	floor.free()
	await process_frame
	await process_frame
	print("relative_code_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
