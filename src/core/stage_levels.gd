class_name StageLevels
extends RefCounted

## Playable stage order. Each entry pairs a level scene (environment, goal markers, camera)
## with a StageCatalog definition (robot scene, rules). The robot stays graph-authored.

const FLAG_STARTER: String = "arm = Servo(pin0)\narm.write(0)\nsleep(2000)\n"
const CAR_STARTER: String = "left = Motor(pin0)\nright = Motor(pin12)\nleft.motor_on(\"forward\", 55)\nright.motor_on(\"forward\", 55)\nsleep(500)\nstop()\n"

## Planned course names (2026-09-30 plan). Shown as "coming soon"; not playable yet.
const PLANNED: Array[String] = ["Gap bridge", "Downhill cart", "Open the gate", "Waving robot",
	"Legged robot 30 cm", "Stop at the line", "Draw a square", "Challenge: S course", "Maze escape",
	"Line tracer", "Color sorting delivery", "Parallel parking", "Two-robot relay", "Budget challenge"]


static func all() -> Array[Dictionary]:
	return [
		{"id": "raise-flag", "stage_id": "raise-flag", "number": "1",
			"title": "Raise the flag", "topic": "Servo angle",
			"goal": "Raise the flag up to the green line.",
			"story": "Build a robot and attach the task flag. Raise it to the green line using your own mechanism.",
			"steps": ["Attach a board, servo, arm and task flag, or design another mechanism.", "Wire the actuator to board pins.", "Write code using your wired pins, then press “Run”.", "Press “Run” and keep the flag on the green line for one second."],
			"hint": "Wire the servo to a board pin, then use that pin in Servo(...). Try changing its angle.",
			"scene": "res://stages/raise_flag/level.tscn", "starter_code": FLAG_STARTER,
			"parts": [], "tabs": ["Blocks", "Code", "Wiring", "Controls"], "metric_label": "Flag height", "lower_arm": true},
		{"id": "finish-line", "stage_id": "finish-line", "number": "2",
			"title": "Cross the finish line", "topic": "Motor power and time",
			"goal": "Move every part of your robot past the checkered finish line.",
			"story": "Build your own moving robot. Every part must cross the finish line; tipping over is allowed.",
			"steps": ["Attach a board, motor driver, motors and wheels to a chassis.", "Wire the actuator to board pins.", "Write code using your wired pins, then press “Run”.", "Press “Run” and move every part past the checkered line."],
			"hint": "Wire board pins to the driver and the driver to the motors. Use those pins in your code.",
			"scene": "res://stages/finish_line/level.tscn", "starter_code": CAR_STARTER,
			"parts": [], "tabs": ["Blocks", "Code", "Wiring", "Controls"], "metric_label": "Distance driven"},
		{"id": "wall-brake", "stage_id": "wall-brake", "number": "3",
			"title": "Brake before the wall", "topic": "Sensor and conditions",
			"goal": "Stop inside the yellow zone without touching the wall.",
			"story": "Build a robot that stops 5 to 10 cm from the wall. Any mechanism works; touching the wall does not count.",
			"steps": ["Build a moving robot; add a distance sensor if you want.", "Wire the actuator to board pins.", "Write code using your wired pins, then press “Run”.", "Press “Run” and stay still inside the yellow zone."],
			"hint": "A wired distance sensor can help. The goal measures your nearest part, not the sensor reading.",
			"scene": "res://stages/wall_brake/level.tscn", "starter_code": RobotCarPreset.ANSWER_CODE,
			"parts": [], "tabs": ["Blocks", "Code", "Wiring", "Controls"], "metric_label": "Distance to wall"},
	]


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


## The catalog arm is assembled upright, so servo 0 degrees already meets the goal. The flag
## stage starts with the arm lying toward +Z instead: write(0) keeps it down and write(90)
## raises it (measured 2026-09-30: tip 8.9 cm vs 16.5 cm).
static func starting_graph(level: Dictionary, stage: Dictionary) -> ConnectionGraph:
	var graph: ConnectionGraph = ProjectStore.graph_from(stage.author_solution)
	if level.get("lower_arm", false):
		var pivot: Vector3 = Vector3(0.0115, 0.09, 0)
		for part: Dictionary in graph.parts:
			if part.part_def.id in [&"arm_link", &"flag"]:
				var turn := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
				part.transform = Transform3D.IDENTITY.translated(pivot) * turn * Transform3D.IDENTITY.translated(-pivot) * part.transform
	return graph


static func stage_definition(level: Dictionary) -> Dictionary:
	for stage: Dictionary in StageCatalog.builtins():
		if stage.id == level.stage_id:
			return stage
	return {}
