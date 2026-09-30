extends SceneTree

var failures: int = 0
var checks: int = 0
var world: Node3D
var run_mode: RunMode
var runtime: MiniRuntime

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.1, 20)
	shape.shape = box
	floor_body.add_child(shape)
	world.add_child(floor_body)
	run_mode = RunMode.new()
	world.add_child(run_mode)
	runtime = MiniRuntime.new()
	runtime.hardware = run_mode
	world.add_child(runtime)
	runtime.failed.connect(func(line: int, message: String) -> void: _check(false, "runtime line %d: %s" % [line, message]))
	var graph: ConnectionGraph = RobotCarPreset.build(1.2)
	_check(not ProjectStore.document("Car", graph, RobotCarPreset.BRAKE_CODE).is_empty(), "car catalog graph can be shared")
	run_mode.build(graph)
	_check(run_mode.motor_on_pin(0) != null and run_mode.motor_on_pin(12) != null, "driver and paired graph pins resolve both motors")
	_check(run_mode.servo_on_pin(0) == null, "DC motor cannot be a positional servo")
	_check(run_mode.sonar_on_pins(1, 2) != null and run_mode.sonar_on_pins(2, 1) == null, "sonar trigger/echo graph roles")
	for tick: int in 60:
		await physics_frame
	var sonar: SonarSensor = run_mode.sonar_on_pins(1, 2)
	var initial: float = sonar.distance_cm()
	print("sensor pose ", run_mode.part_global_transform(8))
	print("initial sonar ", initial, " chassis ", run_mode.bodies[0].position)
	_check(initial > 90 and initial < 120, "nine ray cone measures wall and excludes connected robot")
	_check(absf(sonar.time_pulse_us() / 58.0 - initial) < 0.1, "pulse microseconds match distance")
	var start: Vector3 = run_mode.bodies[0].position
	runtime.run(RobotCarPreset.ANSWER_CODE)
	for tick: int in 240:
		await physics_frame
		if tick == 100:
			print("mid ", run_mode.bodies[0].position, " motor speed ", run_mode.motor_on_pin(0).measured_rad_s, " torque ", run_mode.motor_on_pin(0).applied_torque_nm)
	var travel: Vector3 = run_mode.bodies[0].position - start
	print("travel ", travel, " sonar ", sonar.distance_cm(), " torque ", run_mode.motor_on_pin(0).applied_torque_nm)
	_check(travel.x > 0.2, "code produces actual forward wheel travel")
	_check(absf(travel.z) < 0.10, "two wheel straight drift under 10 cm")
	_check(not runtime.is_running() and run_mode.motor_on_pin(0).duty == 0, "program stops and brakes motors")
	runtime.stop()
	run_mode.teardown()
	graph = RobotCarPreset.build(0.8)
	run_mode.build(graph)
	for tick: int in 30:
		await physics_frame
	runtime.run(RobotCarPreset.BRAKE_CODE)
	for tick: int in 480:
		await physics_frame
	sonar = run_mode.sonar_on_pins(1, 2)
	print("brake sonar ", sonar.distance_cm(), " body ", run_mode.bodies[0].position)
	_check(not runtime.is_running(), "sensor condition terminates loop")
	_check(sonar.distance_cm() >= 5 and sonar.distance_cm() <= 14, "brakes before wall from measured distance")
	_check(run_mode.bodies[0].global_basis.y.dot(Vector3.UP) > 0.95, "car remains upright")
	await process_frame
	world.free()
	print("robot_car_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
