extends SceneTree

## Writes synthetic save data with main's own writers so r3 can be checked against it.
## Run from a main checkout; REVIEW_OUT names the output directory (with trailing slash).
var OUT: String = OS.get_environment("REVIEW_OUT")


func _initialize() -> void:
	_run.call_deferred()


func _write(name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(OUT + name, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _run() -> void:
	var graphs: Dictionary = {
		"servo_arm": ServoArmPreset.build(), "servo_arm_microbit": ServoArmPreset.build_microbit(),
		"robot_car": RobotCarPreset.build(), "robot_car_wall": RobotCarPreset.build(0.8),
		"humanoid": HumanoidPreset.build(), "modular": ModularHumanoidPreset.build(),
		"kit": ConstructionKitHumanoidPreset.build(), "kit_bridge": ConstructionKitHumanoidPreset.build_bridge(),
		"biped": BipedPreset.build(), "yaw_biped": YawBipedPreset.build()}
	var count: int = 0
	for key: String in graphs:
		var record: Dictionary = ProjectStore.document("Main " + key, graphs[key], "# main source %s\n" % key)
		if record.is_empty():
			print("SKIP ", key)
			continue
		_write("project_%s.json" % key, ProjectStore.serialize(record))
		_write("encode_%s.json" % key, JSON.stringify(MotionSnapshot.encode(graphs[key]), "", true, true))
		count += 1
	for stage: Dictionary in StageCatalog.builtins():
		_write("stage_%s.json" % stage.id, StageDefinition.serialize(stage))
	StageProgress.path = OUT + "progress_main.json"
	DirAccess.remove_absolute(StageProgress.path)
	StageProgress.mark_cleared("raise-flag")
	StageProgress.mark_cleared("finish-line")
	var preferences := InterfacePreferences.new()
	preferences.values.appearance = "system"
	preferences.values.text_scale = 1.3
	preferences.values.volume = 25.0
	preferences.save_preferences(OUT + "interface_main.cfg")
	preferences.free()
	print("gen_main_fixtures: wrote %d projects" % count)
	quit(0)
