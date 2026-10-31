extends SceneTree

const PARTS: String = "res://assets/construction_kit/parts/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var builders: Dictionary = {"car": RobotCarPreset.build, "kit_humanoid": ConstructionKitHumanoidPreset.build, "modular_humanoid": ModularHumanoidPreset.build, "humanoid": HumanoidPreset.build}
	for name: String in builders:
		var graph: ConnectionGraph = builders[name].call()
		graph.parts.append({"part_def": load(PARTS + "kit_env_cup.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(2, 0, 0))})
		graph.parts.append({"part_def": load(PARTS + "kit_env_ball.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(2, 0.03, 0))})
		var hardware := RunMode.new()
		root.add_child(hardware)
		hardware.build(graph)
		var started: int = Time.get_ticks_usec()
		var value: int = 0
		for repeat: int in 10:
			value = hardware.cup_object_count()
		print("PRESET %s parts=%d links=%d count=%d ms_per_call=%.2f" % [name, graph.parts.size(), graph.links.size(), value, (Time.get_ticks_usec() - started) / 10000.0])
		hardware.free()
		await process_frame
	quit(0)
