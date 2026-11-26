class_name StageLevels
extends RefCounted

## Playable stage order. Each entry pairs a level scene (environment, goal markers, camera)
## with a StageCatalog definition (robot scene, rules). The robot stays graph-authored.

const FLAG_STARTER: String = "arm = Servo(pin0)\narm.write(0)\nsleep(2000)\n"
const CAR_STARTER: String = "left = Motor(pin0)\nright = Motor(pin12)\nleft.motor_on(\"forward\", 55)\nright.motor_on(\"forward\", 55)\nsleep(500)\nstop()\n"
const HINT_WIRING: String = "In Wiring, pick the input under “Port to connect” and the output under “Connects to”. Then press “Connect wire”."
const HINT_RUN: String = "Turn on the battery switch, then press “Run”."

## Planned course names (2026-09-30 plan). Shown as "coming soon"; not playable yet.
const PLANNED: Array[String] = ["Gap bridge", "Downhill cart", "Open the gate", "Waving robot",
	"Legged robot 30 cm", "Stop at the line", "Draw a square", "Challenge: S course", "Maze escape",
	"Line tracer", "Color sorting delivery", "Parallel parking", "Two-robot relay", "Budget challenge"]


## Beginner course (design 2026-11-11 section 6): each level unlocks a few parts and one
## tool. Levels 1-2 are wiring only; code tabs open at level 3. All use tier 1 power.
const COURSE: Array[Dictionary] = [
	{"unlocks": ["battery_holder_4aa", "microbit", "kit_led", "kit_plate_120_80"], "unlock_text": "Battery, board and LED"},
	{"unlocks": ["tt_motor", "kit_wheel_90", "motor_driver", "kit_plate_220_120", "kit_beam_140", "kit_beam_100", "ball_caster", "kit_spacer_20", "kit_angle_bracket"], "unlock_text": "Motors and wheels"},
	{"unlocks": ["kit_motor_12", "kit_u_bracket_small", "kit_weight_300", "flag"], "unlock_text": "Servo arm and the Blocks and Code tabs"},
	{"unlocks": ["hc_sr04", "kit_plate_60_40", "kit_beam_60", "wheel_65"], "unlock_text": "Distance sensor and condition blocks"},
	{"unlocks": [], "unlock_text": "Every beginner part, with building, wiring and code together"},
]


static func all() -> Array[Dictionary]:
	var levels: Array[Dictionary] = [
		{"id": "light-on", "stage_id": "light-on", "kind": "light-on", "art": "lab", "number": "1", "course": "Beginner",
			"title": "Turn on the light", "topic": "Closing a circuit",
			"goal": "Light the LED by connecting the battery.",
			"story": "The board, LED and battery are already on the plate. Only the power cable is missing.",
			"steps": ["Open the Wiring tab.", "Connect the battery to the board's power input.", "Check that the battery switch is on.", "Press “Run” and keep the LED lit for one second."],
			"hint": "Power flows from the battery to the board. Connect them in the Wiring tab.",
			"scene": "res://stages/raise_flag/level.tscn", "starter_code": BeginnerBuilds.LED_CODE,
			"tabs": ["Wiring"], "power_tier": 1, "start": "partial", "metric_label": "LED brightness", "answer_hint": true},
		{"id": "finish-line", "stage_id": "finish-line", "kind": "finish-line", "number": "2", "course": "Beginner",
			"title": "Cross the finish line", "topic": "Motors need power",
			"goal": "Move every part of your robot past the checkered finish line.",
			"story": "The car is built and its program is ready. Power the motor driver and the board so the wheels turn.",
			"steps": ["Open the Wiring tab.", "Connect the battery to the motor driver, then the driver to the board.", "Check that the battery switch is on.", "Press “Run” and move every part past the checkered line."],
			"hint": "Motors get power through the motor driver. Connect battery → driver → board.",
			"scene": "res://stages/finish_line/level.tscn", "starter_code": RobotCarPreset.ANSWER_CODE,
			"tabs": ["Wiring"], "power_tier": 1, "start": "partial", "remove": ["hc_sr04"], "metric_label": "Distance driven", "answer_hint": true},
		{"id": "raise-flag", "stage_id": "raise-flag", "kind": "raise-flag", "number": "3", "course": "Beginner",
			"title": "Raise the flag", "topic": "Servo angle",
			"goal": "Raise the flag up to the green line.",
			"story": "The servo arm is built. Power it, then use the new Blocks and Code tabs to raise the flag.",
			"steps": ["Connect the battery to the board and the board to the servo.", "Open Blocks or Code.", "Change the servo angle so the flag rises.", "Press “Run” and keep the flag on the green line for one second."],
			"hint": "Wire the servo to a board pin, then use that pin in Servo(...). Try changing its angle.",
			"scene": "res://stages/raise_flag/level.tscn", "starter_code": FLAG_STARTER,
			"tabs": ["Blocks", "Code", "Wiring", "Controls"], "power_tier": 1, "start": "partial", "metric_label": "Flag height", "lower_arm": true,
			"answer_hint": true, "answer_code_hint": "Open Code and use this program to raise the flag."},
		{"id": "wall-brake", "stage_id": "wall-brake", "kind": "wall-brake", "number": "4", "course": "Beginner",
			"title": "Brake before the wall", "topic": "Sensor and conditions",
			"goal": "Stop inside the yellow zone without touching the wall.",
			"story": "The car has a distance sensor. Use a condition block to stop 5 to 10 cm from the wall.",
			"steps": ["Power the driver, the board and the distance sensor.", "Read the sensor in Blocks or Code.", "Repeat while the wall is far, then stop.", "Press “Run” and stay still inside the yellow zone."],
			"hint": "Use “Repeat while” with the sensor's distance. The goal measures your nearest part.",
			"scene": "res://stages/wall_brake/level.tscn", "starter_code": RobotCarPreset.ANSWER_CODE,
			"tabs": ["Blocks", "Code", "Wiring", "Controls"], "power_tier": 1, "start": "partial", "battery_on": "driver", "metric_label": "Distance to wall"},
		{"id": "first-robot", "stage_id": "first-robot", "kind": "finish-line", "art": "finish-line", "number": "5", "course": "Beginner",
			"title": "My first robot", "topic": "Build, wire and code",
			"goal": "Build a robot from scratch and drive it past the finish line.",
			"story": "An empty workbench this time. Use everything you learned: build, wire power and signals, then write the program.",
			"steps": ["Build a car from the parts tray.", "Wire power and the motor signals.", "Write code using your wired pins.", "Press “Run” and move every part past the checkered line."],
			"hint": "Start from the car you powered in stage 2. Remember the battery.",
			"scene": "res://stages/finish_line/level.tscn", "starter_code": "",
			"tabs": ["Blocks", "Code", "Wiring", "Controls"], "power_tier": 1, "start": "empty", "metric_label": "Distance driven"},
	]
	var allowed: Array = []
	for index: int in levels.size():
		for id: String in COURSE[index].unlocks:
			if id not in allowed:
				allowed.append(id)
		levels[index]["parts"] = allowed.duplicate()
		levels[index]["unlocks"] = COURSE[index].unlocks.duplicate()
		levels[index]["unlock_text"] = COURSE[index].unlock_text
	return levels


## True when the level shows a programming tab (Blocks or Code).
static func has_code(level: Dictionary) -> bool:
	var tabs: Array = level.get("tabs", ["Blocks", "Code"])
	return "Blocks" in tabs or "Code" in tabs


## The same resolved answer graph supplies the guide and the applied build.
static func answer_hint_links(graph: ConnectionGraph) -> Dictionary:
	var power: Array[Dictionary] = []
	var signals: Array[Dictionary] = []
	for link: Dictionary in graph.links:
		var source: PartDef = graph.parts[link.a_part].part_def
		var target: PartDef = graph.parts[link.b_part].part_def
		if RunMode._port(source, link.a_port).kind != Port.Kind.ELEC:
			continue
		var row: Dictionary = {"source": source.display_name, "source_port": link.a_port,
			"target": target.display_name, "target_port": link.b_port}
		if BeginnerBuilds._is_power(graph, link.a_part, link.a_port) or BeginnerBuilds._is_power(graph, link.b_part, link.b_port):
			power.append(row)
		else:
			signals.append(row)
	return {"power": power, "signals": signals}


static func find(id: String) -> Dictionary:
	for level: Dictionary in all():
		if level.id == id:
			return level
	return {}


static func next_after(id: String) -> Dictionary:
	var levels: Array[Dictionary] = all()
	for index: int in levels.size() - 1:
		if levels[index].id == id:
			return levels[index + 1]
	return {}


## Lower the output-side mechanism around its graph-authored shaft, preserving holes.
## With power tier 1, the author graph gains a battery; `wired` adds its power cables
## (the answer), otherwise the learner closes the circuit (the semi-assembled start).
static func starting_graph(level: Dictionary, stage: Dictionary, wired: bool = true) -> ConnectionGraph:
	var graph: ConnectionGraph = ProjectStore.graph_from(stage.author_solution)
	var removed: Array[StringName] = []
	for id: String in level.get("remove", []):
		removed.append(StringName(id))
	BeginnerBuilds.without(graph, removed)
	if int(level.get("power_tier", 0)) >= 1:
		BeginnerBuilds.strip_power(graph)
		if BeginnerBuilds._first(graph, &"battery_holder_4aa") < 0:
			BeginnerBuilds.with_battery(graph, level.get("battery_on", "board") == "driver")
		if wired:
			BeginnerBuilds.wire_power(graph)
	if not level.get("lower_arm", false):
		return graph
	for link: Dictionary in graph.links:
		var port: Port = RunMode._port(graph.parts[link.a_part].part_def, link.a_port)
		if not port.rotates:
			continue
		var pivot: Vector3 = graph.parts[link.a_part].transform * port.local_position
		var axis: Vector3 = graph.parts[link.a_part].transform.basis * port.local_normal
		var moving: Array[int] = [link.b_part]
		var cursor: int = 0
		while cursor < moving.size():
			var part: int = moving[cursor]
			cursor += 1
			for connection: Dictionary in graph.links:
				var other: int = -1
				if connection.a_part == part:
					other = connection.b_part
				elif connection.b_part == part:
					other = connection.a_part
				if other < 0 or other == link.a_part or other in moving:
					continue
				if RunMode._port(graph.parts[part].part_def, connection.a_port if connection.a_part == part else connection.b_port).kind == Port.Kind.MECH:
					moving.append(other)
		# Kit torque actuators turn the connected arm in the positive port direction;
		# legacy ideal servos use the opposite hinge convention.
		var lower_angle: float = -PI / 2.0 if graph.parts[link.a_part].part_def.actuator_drives_connected_body else PI / 2.0
		var turn := Transform3D(Basis(axis.normalized(), lower_angle), pivot)
		for part: int in moving:
			graph.parts[part].transform = turn * Transform3D.IDENTITY.translated(-pivot) * graph.parts[part].transform
		break
	return graph


static func stage_definition(level: Dictionary) -> Dictionary:
	for stage: Dictionary in StageCatalog.builtins():
		if stage.id == level.stage_id:
			return stage
	return {}
