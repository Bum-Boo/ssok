class_name StageCatalog
extends RefCounted


static func builtins() -> Array[Dictionary]:
	var stages: Array[Dictionary] = [
		StageDefinition.create("raise-flag", "Raise the flag", KitFlagArmPreset.build(), "arm = Servo(pin0)\narm.write(90)\nsleep(1000)\narm.write(0)\nsleep(2000)\n",
			[StageDefinition.rule("max_height", "flag", 0.155, 100.0, 1.0)]),
		StageDefinition.create("finish-line", "Cross the finish line", KitCarPreset.build(), RobotCarPreset.ANSWER_CODE,
			[StageDefinition.rule("min_x", "*", 0.5, 100.0)]),
		StageDefinition.create("wall-brake", "Brake before the wall", KitCarPreset.build(0.8), RobotCarPreset.BRAKE_CODE,
			[StageDefinition.rule("wall_distance", "*", 0.05, 0.10, 0.3), StageDefinition.rule("robot_speed", "*", 0.0, 0.015, 0.3), StageDefinition.rule("wall_contact", "*", 0, 0)])
	]
	return stages
