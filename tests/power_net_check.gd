extends SceneTree

## Tier 1 power: a robot only moves while its parts lead back to a switched-on battery.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + label)


func _index(graph: ConnectionGraph, id: StringName) -> int:
	for part: int in graph.parts.size():
		if graph.parts[part].part_def.id == id:
			return part
	return -1


func _cable(graph: ConnectionGraph, from: int, from_port: StringName, to: int, to_port: StringName) -> void:
	graph.links.append({"a_part": from, "a_port": from_port, "b_part": to, "b_port": to_port})


## The kit car with a battery feeding the driver, the driver feeding the board and the
## board feeding the distance sensor.
func _powered_car() -> ConnectionGraph:
	var graph: ConnectionGraph = KitCarPreset.build()
	var holder: PartDef = load("res://assets/power/parts/battery_holder_4aa.tres")
	var chassis: Transform3D = graph.parts[0].transform
	graph.parts.append({"part_def": holder, "transform": chassis.translated(Vector3(0, 0.06, 0))})
	var battery: int = graph.parts.size() - 1
	var driver: int = _index(graph, &"motor_driver")
	var board: int = _index(graph, &"microbit")
	var sonar: int = _index(graph, &"hc_sr04")
	_cable(graph, battery, &"power_out", driver, &"power_in")
	_cable(graph, driver, &"power_out", board, &"power_in")
	_cable(graph, board, &"power_out_1", sonar, &"power_in")
	return graph


func _drive(run: RunMode, graph: ConnectionGraph, tier: int, switched_on: bool) -> float:
	run.power_tier = tier
	run.power_on = switched_on
	run.build(graph)
	for tick: int in 30:
		await physics_frame
	var before: float = run.part_global_transform(0).origin.x
	for pin: int in [0, 12]:
		var motor: DriveMotor = run.motor_on_pin(pin)
		if motor != null:
			motor.motor_on("forward", 55)
	for tick: int in 120:
		await physics_frame
	var moved: float = run.part_global_transform(0).origin.x - before
	run.teardown()
	return moved


func _run() -> void:
	var holder: PartDef = load("res://assets/power/parts/battery_holder_4aa.tres")
	_check(holder != null and holder.power_source_voltage > 0.0 and holder.mesh != null, "battery holder is a power source with a mesh")
	_check("battery_holder_4aa" in PartTray.ids(), "battery holder is in the tray")

	var bare: ConnectionGraph = KitCarPreset.build()
	var report: Dictionary = PowerNet.evaluate(bare)
	var board: int = PowerNet.board_part(bare)
	_check(board >= 0 and not report.powered[board], "a car without a battery has an unpowered board")
	_check(report.problems[0].code == PowerNet.NO_SOURCE, "the first problem names the missing battery")

	var wired: ConnectionGraph = _powered_car()
	report = PowerNet.evaluate(wired)
	_check(report.problems.is_empty(), "battery, driver, board and sensor in a chain are all powered")
	for part: int in wired.parts.size():
		_check(report.powered[part], "powered " + String(wired.parts[part].part_def.id))

	report = PowerNet.evaluate(wired, false)
	_check(report.problems[0].code == PowerNet.SWITCH_OFF, "switching the battery off is the first problem")
	_check(not report.powered[PowerNet.board_part(wired)], "switching off removes power from the board")

	var loose: ConnectionGraph = _powered_car()
	loose.links.pop_back()
	report = PowerNet.evaluate(loose)
	var sonar: int = _index(loose, &"hc_sr04")
	_check(report.problems.size() == 1 and report.problems[0].part == sonar and report.problems[0].code == PowerNet.NOT_CONNECTED, "an unplugged sensor is the only problem")
	_check(report.powered[PowerNet.board_part(loose)], "the board keeps its power when a sensor is unplugged")

	var broken: ConnectionGraph = _powered_car()
	broken.links = broken.links.filter(func(link: Dictionary) -> bool: return link.b_port != &"power_in" or broken.parts[link.b_part].part_def.id != &"motor_driver")
	report = PowerNet.evaluate(broken)
	_check(report.problems[0].part == PowerNet.board_part(broken) and report.problems[0].code == PowerNet.UPSTREAM, "a board fed by an unpowered driver is reported first")

	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.1, 20)
	collision.shape = box
	floor_body.add_child(collision)
	world.add_child(floor_body)
	var run := RunMode.new()
	world.add_child(run)

	var legacy: float = await _drive(run, KitCarPreset.build(), 0, true)
	_check(legacy > 0.1, "tier 0 keeps the original always-powered drive (%.3f m)" % legacy)
	var unpowered: float = await _drive(run, KitCarPreset.build(), 1, true)
	_check(absf(unpowered) < 0.01, "tier 1 without a battery does not move (%.3f m)" % unpowered)
	var powered: float = await _drive(run, _powered_car(), 1, true)
	_check(powered > 0.1, "tier 1 with a wired battery drives (%.3f m)" % powered)
	var switched_off: float = await _drive(run, _powered_car(), 1, false)
	_check(absf(switched_off) < 0.01, "tier 1 with the switch off does not move (%.3f m)" % switched_off)
	print("POWER_MEASUREMENTS ", JSON.stringify({"legacy_m": legacy, "unpowered_m": unpowered, "powered_m": powered, "switched_off_m": switched_off}))

	world.free()
	await process_frame
	print("power_net_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
