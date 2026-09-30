extends SceneTree

var checks: int = 0
var failures: int = 0
var world: Node3D
var run_mode: RunMode
var runtime: MiniRuntime

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.1, 20)
	collision.shape = box
	floor_body.add_child(collision)
	world.add_child(floor_body)
	run_mode = RunMode.new()
	world.add_child(run_mode)
	runtime = MiniRuntime.new()
	runtime.hardware = run_mode
	world.add_child(runtime)
	var random := RandomNumberGenerator.new()
	random.seed = 20260930
	var distances: Array[float] = [random.randf_range(0.50, 0.60), random.randf_range(0.75, 0.85), random.randf_range(1.00, 1.10)]
	var sensor_wins: int = 0
	var timer_wins: int = 0
	for mode: String in ["sensor", "timer"]:
		for distance: float in distances:
			runtime.stop()
			run_mode.teardown()
			var graph: ConnectionGraph = RobotCarPreset.build(distance)
			run_mode.build(graph)
			for tick: int in 30:
				await physics_frame
			var evaluator := StageEvaluator.new()
			var stage: Dictionary = StageCatalog.builtins()[2]
			evaluator.configure(stage, graph)
			_check(evaluator.start(graph), "start sensor challenge")
			var program: String = RobotCarPreset.BRAKE_CODE if mode == "sensor" else RobotCarPreset.ANSWER_CODE.replace("55", "35").replace("3000", "1400")
			runtime.run(program)
			var stopped_ticks: int = 0
			for tick: int in 900:
				await physics_frame
				evaluator.observe(run_mode, graph, 1.0 / 60.0)
				stopped_ticks = stopped_ticks + 1 if not runtime.is_running() else 0
				if stopped_ticks >= 90:
					break
			if evaluator.success:
				if mode == "sensor": sensor_wins += 1
				else: timer_wins += 1
			print("SONAR_STAGE ", JSON.stringify({"mode": mode, "wall_x": distance, "result": evaluator.result()}))
			if mode == "sensor":
				_check(evaluator.success and not evaluator.had_wall_contact, "sensor solution from randomized start")
	_check(sensor_wins == 3 and timer_wins < 3, "sensor passes fixed randomized gate while timer-only solution fails")
	runtime.stop()
	run_mode.teardown()
	var graph: ConnectionGraph = RobotCarPreset.build(0.8)
	run_mode.build(graph)
	for tick: int in 30:
		await physics_frame
	var sensor: SonarSensor = run_mode.sonar_on_pins(1, 2)
	var baseline: float = sensor.distance_cm()
	_check(sensor.last_valid and baseline > 2 and baseline < 400, "valid 2-400 cm range")
	_check(sensor.time_pulse_us(10) == -1, "pulse API reports timeout")
	sensor.realistic = true
	sensor.noise_seed = 1234
	var first: float = sensor.distance_cm()
	sensor._sample = 0
	_check(is_equal_approx(first, sensor.distance_cm()), "realistic noise is reproducible by seed")
	sensor.realistic = false
	var wall: RigidBody3D = run_mode.bodies[-1]
	var sensor_pose: Transform3D = run_mode.part_global_transform(8)
	wall.position.x = sensor_pose.origin.x + 0.012 + 0.01 + 0.01
	await physics_frame
	_check(sensor.distance_cm() == 401 and not sensor.last_valid and sensor.time_pulse_us() == -2, "below 2 cm is invalid, not a false near measurement")
	wall.position.x = 5.0
	await physics_frame
	_check(sensor.distance_cm() == 401 and sensor.time_pulse_us() == -2, "beyond 400 cm is no echo")
	world.free()
	await process_frame
	print("sonar_stage_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
