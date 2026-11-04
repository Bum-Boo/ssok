class_name StageCatalog
extends RefCounted


static func builtins() -> Array[Dictionary]:
	return [
		StageDefinition.create("raise-flag", "Raise the flag", _flag_answer(), "arm = Servo(pin0)\narm.write(90)\nsleep(1000)\narm.write(0)\nsleep(2000)\n",
			[StageDefinition.rule("max_height", "flag", 0.155, 100.0, 1.0)]),
		StageDefinition.create("finish-line", "Cross the finish line", RobotCarPreset.build(), RobotCarPreset.ANSWER_CODE,
			[StageDefinition.rule("min_x", "*", 0.5, 100.0)]),
		StageDefinition.create("wall-brake", "Brake before the wall", RobotCarPreset.build(0.8), RobotCarPreset.BRAKE_CODE,
			[StageDefinition.rule("wall_distance", "*", 0.05, 0.10, 0.3), StageDefinition.rule("robot_speed", "*", 0.0, 0.015, 0.3), StageDefinition.rule("wall_contact", "*", 0, 0)])
	]


static func _flag_answer() -> ConnectionGraph:
	var graph: ConnectionGraph = ServoArmPreset.build_microbit()
	var flag: PartDef = load("res://assets/parts/flag.tres")
	var arm: int = 2
	var anchor: Vector3 = graph.parts[arm].transform * RunMode._port(graph.parts[arm].part_def, &"flag_mount").local_position
	var index: int = graph.parts.size()
	graph.parts.append({"part_def": flag, "transform": Transform3D(Basis.IDENTITY, anchor - flag.ports[0].local_position)})
	graph.links.append({"a_part": arm, "a_port": &"flag_mount", "b_part": index, "b_port": &"mount"})
	return graph
