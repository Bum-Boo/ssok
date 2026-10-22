class_name WorkshopGuide
extends RefCounted

## Read-only projection of workshop state. It never edits the graph or executes code.
const NAMES: Array[String] = ["Assemble", "Wire", "Code", "Run"]
const HINTS: Array[String] = ["Place parts on the workbench.", "Connect the motors to board pins.", "Edit the blocks or code.", "Press “Run” and watch the goal marker."]


static func snapshot(graph: ConnectionGraph, source: String, runtime: MiniRuntime, running: bool) -> Dictionary:
	var assembled: bool = not graph.parts.is_empty()
	var wired: bool = _motors_wired(graph)
	var valid: bool = not source.strip_edges().is_empty() and runtime.validate(source, false).is_empty()
	var completed: Array[bool] = [assembled, wired, valid, running]
	var current: int = 3
	for index: int in 3:
		if not completed[index]:
			current = index
			break
	return {"completed": completed, "current": current}


static func _motors_wired(graph: ConnectionGraph) -> bool:
	var pins: Dictionary = Wiring.pin_map(graph)
	var motors: int = 0
	for index: int in graph.parts.size():
		var definition: PartDef = graph.parts[index].part_def
		var servo: bool = false
		for port: Port in definition.ports:
			servo = servo or port.tag == &"pwm_signal"
		if not servo and not definition.dc_motor:
			continue
		motors += 1
		var connected: bool = false
		for channel: Dictionary in pins.values():
			connected = connected or (servo and channel.part == index)
		if definition.dc_motor:
			for link: Dictionary in graph.links:
				var driver: int = -1
				var output: StringName
				if link.a_part == index and link.a_port == &"power":
					driver = link.b_part
					output = link.b_port
				elif link.b_part == index and link.b_port == &"power":
					driver = link.a_part
					output = link.a_port
				if driver < 0 or graph.parts[driver].part_def.id not in [&"motor_driver", &"tb6612_driver"]:
					continue
				var inputs: Array = ["input_0", "input_8"] if output == &"motor_1" else ["input_12", "input_16"]
				if graph.parts[driver].part_def.id == &"tb6612_driver":
					inputs = ["input_3", "input_4"] if output == &"motor_1" else ["input_6", "input_7"]
				var found: Array[String] = []
				for channel: Dictionary in pins.values():
					if channel.part == driver:
						found.append(String(channel.port))
				connected = connected or (inputs[0] in found and inputs[1] in found)
		if not connected:
			return false
	return motors > 0
