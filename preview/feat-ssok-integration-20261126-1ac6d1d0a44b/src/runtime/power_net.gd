class_name PowerNet
extends RefCounted

## Tier 1 electrical model: connectivity only. Power flows from a source part through
## power cables (one ELEC link carries both supply and ground, like a two-pin plug) to
## every part whose power_in port leads back to that source.

const POWER_IN: StringName = &"power_in"
const SOURCE_TAG: StringName = &"power_source"
const MOTOR_POWER_TAG: StringName = &"motor_power"

const NO_SOURCE: String = "no_source"
const SWITCH_OFF: String = "switch_off"
const NOT_CONNECTED: String = "not_connected"
const UPSTREAM: String = "upstream_unpowered"


## Returns { "powered": Array[bool] per part, "problems": Array[{ "code", "part" }] }.
## Problems are ordered by what a learner should fix first.
static func evaluate(graph: ConnectionGraph, switched_on: bool = true) -> Dictionary:
	var count: int = graph.parts.size()
	var feeder: Array[int] = []
	feeder.resize(count)
	feeder.fill(-1)
	var motor_driver: Array[int] = []
	motor_driver.resize(count)
	motor_driver.fill(-1)
	for link: Dictionary in graph.links:
		for side: Array in [["a", "b"], ["b", "a"]]:
			var part: int = link[side[0] + "_part"]
			var other: int = link[side[1] + "_part"]
			var port: Port = _port(graph.parts[part].part_def, link[side[0] + "_port"])
			var other_port: Port = _port(graph.parts[other].part_def, link[side[1] + "_port"])
			if port == null or other_port == null or port.kind != Port.Kind.ELEC:
				continue
			if port.id == POWER_IN and other_port.tag == SOURCE_TAG:
				feeder[part] = other
			elif port.tag == MOTOR_POWER_TAG:
				motor_driver[part] = other
	var has_source: bool = false
	for part: int in count:
		if graph.parts[part].part_def.power_source_voltage > 0.0:
			has_source = true
	var state: Array[int] = []
	state.resize(count)
	state.fill(-1)
	var powered: Array[bool] = []
	powered.resize(count)
	for part: int in count:
		powered[part] = _resolve(graph, part, feeder, motor_driver, state, switched_on) == 1
	var problems: Array[Dictionary] = []
	var consumers: bool = false
	for part: int in count:
		var definition: PartDef = graph.parts[part].part_def
		if not definition.needs_power and not definition.dc_motor:
			continue
		consumers = true
		# A motor's cause is its driver, which is reported on its own.
		if powered[part] or definition.dc_motor:
			continue
		problems.append({"code": NOT_CONNECTED if feeder[part] < 0 else UPSTREAM, "part": part})
	# Boards first: nothing else matters while the program cannot start.
	problems.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var board_a: bool = not graph.parts[a.part].part_def.board_profile_id.is_empty()
		var board_b: bool = not graph.parts[b.part].part_def.board_profile_id.is_empty()
		if board_a != board_b:
			return board_a
		if (a.code == NOT_CONNECTED) != (b.code == NOT_CONNECTED):
			return a.code == NOT_CONNECTED
		return a.part < b.part)
	if consumers and not has_source:
		problems.push_front({"code": NO_SOURCE, "part": -1})
	elif consumers and not switched_on and not problems.is_empty():
		problems.push_front({"code": SWITCH_OFF, "part": -1})
	return {"powered": powered, "problems": problems}


## The board that runs the program, or -1 when the build has none.
static func board_part(graph: ConnectionGraph) -> int:
	for part: int in graph.parts.size():
		if not graph.parts[part].part_def.board_profile_id.is_empty():
			return part
	return -1


static func _resolve(graph: ConnectionGraph, part: int, feeder: Array[int], motor_driver: Array[int], state: Array[int], switched_on: bool) -> int:
	if state[part] >= 0:
		return state[part]
	# A loop of cables without a source powers nothing.
	state[part] = 0
	var definition: PartDef = graph.parts[part].part_def
	var result: int = 0
	if definition.power_source_voltage > 0.0:
		result = 1 if switched_on else 0
	elif definition.dc_motor:
		result = _resolve(graph, motor_driver[part], feeder, motor_driver, state, switched_on) if motor_driver[part] >= 0 else 0
	elif feeder[part] >= 0:
		result = _resolve(graph, feeder[part], feeder, motor_driver, state, switched_on)
	elif not definition.needs_power:
		# Passive parts (plates, LEDs driven from a pin) never block anything.
		result = 1
	state[part] = result
	return result


static func _port(definition: PartDef, id: StringName) -> Port:
	for port: Port in definition.ports:
		if port.id == id:
			return port
	return null
