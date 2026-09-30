class_name StageCatalog
extends RefCounted


static func builtins() -> Array[Dictionary]:
	return [
		StageDefinition.create("raise-flag", "Raise the flag", ServoArmPreset.build_microbit(), "arm = Servo(pin0)\narm.write(90)\nsleep(1000)\narm.write(0)\nsleep(2000)\n",
			[StageDefinition.rule("height", "arm_link", 0.155, 100.0, 1.0)]),
		StageDefinition.create("finish-line", "Cross the finish line", RobotCarPreset.build(), RobotCarPreset.ANSWER_CODE,
			[StageDefinition.rule("x", "car_chassis", 0.5, 100.0), StageDefinition.rule("upright", "car_chassis", 0.95, 1.0)]),
		StageDefinition.create("wall-brake", "Brake before the wall", RobotCarPreset.build(0.8), RobotCarPreset.BRAKE_CODE,
			[StageDefinition.rule("sonar_distance", "hc_sr04", 5.0, 10.0, 0.3), StageDefinition.rule("speed", "car_chassis", 0.0, 0.015, 0.3), StageDefinition.rule("wall_contact", "car_chassis", 0, 0)])
	]
