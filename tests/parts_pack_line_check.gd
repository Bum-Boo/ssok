extends SceneTree

var checks: int = 0
var failures: int = 0
const PARTS: String = "res://assets/construction_kit/parts/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 0.02, 4)
	collider.shape = shape
	floor.add_child(collider)
	root.add_child(floor)
	floor.position.y = -0.01
	var graph := ConnectionGraph.new()
	graph.parts.append({"part_def": load(PARTS + "kit_line_sensor.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0))})
	graph.parts.append({"part_def": load("res://assets/parts/microbit.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(1, 0.2, 0))})
	graph.parts.append({"part_def": load(PARTS + "kit_env_line_straight.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(0, 0.001, 0))})
	graph.links.append({"a_part": 0, "a_port": &"signal_pin", "b_part": 1, "b_port": &"pin_1"})
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	hardware.bodies[0].freeze = true
	await physics_frame
	await physics_frame
	var sensor: LineSensor = hardware.line_on_pin(1)
	var dark: int = sensor.value()
	_check(sensor.last_valid and sensor.is_dark() and dark < 250, "three floor rays detect black material")
	hardware.bodies[0].position.x = 0.08
	await physics_frame
	await physics_frame
	var white: int = sensor.value()
	print("LINE dark=%d white=%d" % [dark, white])
	_check(not sensor.is_dark() and white > 900, "moving outside line detects bright floor")
	_check(hardware.line_on_pin(2) == null and hardware.device("Motor", [1]) == null, "typed signal wiring rejects wrong or missing device")
	sensor.realistic = true
	var noisy: Array[int] = []
	for sample: int in 8:
		noisy.append(sensor.value())
	sensor._sample = 0
	var repeated: Array[int] = []
	for sample: int in 8:
		repeated.append(sensor.value())
	_check(noisy == repeated and noisy.min() >= 0 and noisy.max() <= 1023, "opt-in bounded seeded noise follows sonar rule")
	var runtime := MiniRuntime.new()
	root.add_child(runtime)
	runtime.hardware = hardware
	await runtime.run("line = LineSensor(pin1)\nlight = line.value()\ndark = line.is_dark()")
	_check(runtime.state == "finished" and runtime._variables.get("light", 0) > 900, "VM invokes actual floor observation")
	for profile_id: String in ["generic-servo", "microbit", "uno"]:
		var profile: BoardProfile = BoardProfile.for_id(profile_id)
		var source: String = "line = LineSensor(pin1)\nlight = line.value()\ndark = line.is_dark()"
		var blocks: Dictionary = ServoProgram.parse(source, profile)
		_check(not blocks.has("error") and blocks.instructions[0].op == "line_sensor" and blocks.instructions[1].op == "line_value" and blocks.instructions[2].op == "line_dark", "three editable observation cards " + profile_id)
		for item: Dictionary in blocks.instructions:
			item.erase("raw")
		_check(ServoProgram.generate(blocks.instructions, profile).get("source", "") == source.replace("pin1", profile.format_pin(1)), "edited block generation " + profile_id)
	hardware.free()
	runtime.free()
	await process_frame
	await _follow_line()
	floor.free()
	await process_frame
	print("parts_pack_line_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _follow_line() -> void:
	var graph: ConnectionGraph = RobotCarPreset.build()
	# Replace the sonar with a graph-wired down-facing reflectance sensor.
	graph.links = graph.links.filter(func(link: Dictionary) -> bool: return link.a_part != 8 and link.b_part != 8)
	graph.parts[8].part_def = load(PARTS + "kit_line_sensor.tres")
	RobotCarPreset._place(graph, 0, &"sensor_mount", 8, &"mount")
	RobotCarPreset._link(graph, 5, &"pin_1", 8, &"signal_pin")
	# A broad gentle elbow is built from the same straight strips the learner can place.
	for segment: int in 10:
		var angle: float = 0.0 if segment < 3 else deg_to_rad((segment - 2) * 6.0)
		var x: float = 0.1 + segment * 0.14
		var z: float = 0.008 + maxf(0, segment - 2) * maxf(0, segment - 2) * 0.007
		graph.parts.append({"part_def": load(PARTS + "kit_env_line_straight.tres"), "transform": Transform3D(Basis(Vector3.UP, PI / 2 - angle), Vector3(x, 0.001, z))})
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var runtime := MiniRuntime.new()
	root.add_child(runtime)
	runtime.hardware = hardware
	# Follow the edge with a single reflectance sensor; every turn derives from its rays.
	var source: String = "left = Motor(pin0, pin8)\nright = Motor(pin12, pin16)\nline = LineSensor(pin1)\nfor i in range(400):\n    if line.is_dark():\n        left.forward(4)\n        right.forward(20)\n    else:\n        left.forward(20)\n        right.forward(4)\n    sleep(20)\nstop()"
	runtime.run(source)
	var samples: int = 0
	var on_line: int = 0
	for tick: int in 850:
		await physics_frame
		if tick % 60 == 0:
			print("TRACK ",tick," pose=",hardware.part_global_transform(8).origin," value=",hardware.line_on_pin(1).value())
		if tick % 10 == 0:
			samples += 1
			if hardware.line_on_pin(1).is_dark():
				on_line += 1
		if not runtime.is_running():
			break
	var end: Vector3 = hardware.part_global_transform(0).origin
	print("LINE_FOLLOW end=%s dark_samples=%d/%d runtime=%s" % [end, on_line, samples, runtime.state])
	_check(runtime.state == "finished" and end.x > 0.65 and end.z > 0.035 and absf(end.z - 0.007 * pow(maxf(0, (end.x - 0.1) / 0.14 - 2), 2)) < 0.06, "actual sensor code follows a bent line with differential wheel physics")
	_check(on_line > samples / 4 and on_line < samples - 3, "sensor transitions steer the robot")
	runtime.free()
	hardware.free()
	await process_frame


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
