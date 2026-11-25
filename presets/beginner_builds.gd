class_name BeginnerBuilds
extends RefCounted

## Graph helpers for the beginner course (design 2026-11-11, sections 6 and 7 E3).
## A level starts semi-assembled: the answer graph with a battery on board but no
## power cables, so the learner's first job is closing the circuit (tier 1 power).

const BATTERY: String = "res://assets/power/parts/battery_holder_4aa.tres"
const LED_CODE: String = "led = LED(pin0)\nled.on()\nsleep(3000)\n"


## A plate with a board, a signal LED wired to pin 0 and a battery stacked on the board.
static func light_board() -> ConnectionGraph:
	var graph := ConnectionGraph.new()
	var flat := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	var deck: int = KitCarPreset._add(graph, "kit_plate_120_80", Vector3(0, 0.004, 0), flat)
	var board: int = KitCarPreset._attach(graph, deck, KitCarPreset._hole(graph, deck, Vector3(-0.03, -0.01, 0.002)), "microbit", "kit_h0_back")
	var led: int = KitCarPreset._attach(graph, deck, KitCarPreset._hole(graph, deck, Vector3(0.03, 0.01, 0.002)), "kit_led", "mount_0_back", flat)
	KitCarPreset._link(graph, board, "pin_0", led, "signal_pin")
	return with_battery(graph)


## Stacks a battery holder on the free top holes of the board, or of the motor driver
## when `on_driver` (keeps the weight over the wheels of the compact car). Mechanical only.
static func with_battery(graph: ConnectionGraph, on_driver: bool = false) -> ConnectionGraph:
	var board: int = _first(graph, &"motor_driver") if on_driver else -1
	if board < 0:
		board = PowerNet.board_part(graph)
	if board < 0:
		return graph
	var holder: PartDef = load(BATTERY)
	var basis: Basis = graph.parts[board].transform.basis
	graph.parts.append({"part_def": holder, "transform": Transform3D(basis, Vector3.ZERO)})
	var battery: int = graph.parts.size() - 1
	var anchor: Vector3 = graph.parts[board].transform * RunMode._port(graph.parts[board].part_def, &"kit_h0_front").local_position
	graph.parts[battery].transform.origin = anchor - basis * RunMode._port(holder, &"kit_h0_back").local_position
	KitCarPreset._link(graph, board, "kit_h0_front", battery, "kit_h0_back")
	return graph


## Adds power cables: battery to driver (or board), driver to board, board to the rest.
static func wire_power(graph: ConnectionGraph) -> ConnectionGraph:
	var battery: int = _first(graph, &"battery_holder_4aa")
	var board: int = PowerNet.board_part(graph)
	if battery < 0:
		return graph
	var feed: int = battery
	var feed_port: String = "power_out"
	for driver_id: StringName in [&"motor_driver", &"tb6612_driver"]:
		var driver: int = _first(graph, driver_id)
		if driver >= 0:
			KitCarPreset._link(graph, feed, feed_port, driver, "power_in")
			feed = driver
			feed_port = "power_out"
			break
	if board < 0:
		return graph
	KitCarPreset._link(graph, feed, feed_port, board, "power_in")
	var output: int = 1
	for part: int in graph.parts.size():
		var definition: PartDef = graph.parts[part].part_def
		if part == board or not definition.needs_power or definition.id in [&"motor_driver", &"tb6612_driver"]:
			continue
		if RunMode._port(definition, PowerNet.POWER_IN) == null or RunMode._port(graph.parts[board].part_def, StringName("power_out_%d" % output)) == null:
			continue
		KitCarPreset._link(graph, board, "power_out_%d" % output, part, "power_in")
		output += 1
	return graph


## Removes every power cable, keeping mechanical and signal links.
static func strip_power(graph: ConnectionGraph) -> ConnectionGraph:
	graph.links = graph.links.filter(func(link: Dictionary) -> bool:
		return not (_is_power(graph, link.a_part, link.a_port) or _is_power(graph, link.b_part, link.b_port)))
	return graph


## Removes parts by id and renumbers the remaining links.
static func without(graph: ConnectionGraph, ids: Array[StringName]) -> ConnectionGraph:
	for index: int in range(graph.parts.size() - 1, -1, -1):
		if graph.parts[index].part_def.id not in ids:
			continue
		graph.parts.remove_at(index)
		graph.links = graph.links.filter(func(link: Dictionary) -> bool: return link.a_part != index and link.b_part != index)
		for link: Dictionary in graph.links:
			if link.a_part > index:
				link.a_part -= 1
			if link.b_part > index:
				link.b_part -= 1
	return graph


static func _is_power(graph: ConnectionGraph, part: int, port_id: StringName) -> bool:
	var port: Port = RunMode._port(graph.parts[part].part_def, port_id)
	return port != null and port.kind == Port.Kind.ELEC and (port.id == PowerNet.POWER_IN or port.tag == PowerNet.SOURCE_TAG)


static func _first(graph: ConnectionGraph, id: StringName) -> int:
	for part: int in graph.parts.size():
		if graph.parts[part].part_def.id == id:
			return part
	return -1
