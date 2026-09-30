extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var report: Dictionary = {}
	for name: String in ["biped", "yaw_biped"]:
		var variants: Dictionary = {}
		for merged: bool in [false, true]:
			var graph: ConnectionGraph = YawBipedPreset.build() if name == "yaw_biped" else BipedPreset.build()
			for entry: Dictionary in graph.parts:
				entry.part_def = entry.part_def.duplicate(true)
				entry.part_def.merge_fixed_connections = merged
			var hardware := RunMode.new()
			root.add_child(hardware)
			hardware.build(graph)
			for body: RigidBody3D in hardware.bodies: body.gravity_scale = 0.0
			for frame: int in 2: await physics_frame
			var records: Array = []
			var unique: Dictionary = {}
			for index: int in hardware.bodies.size():
				var body: RigidBody3D = hardware.bodies[index]
				if unique.has(body) or body.freeze: continue
				unique[body] = true
				var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
				var members: Array = []
				for other: int in hardware.bodies.size():
					if hardware.bodies[other] == body: members.append(other)
				var tensor: Basis = state.inverse_inertia_tensor.inverse()
				records.append({"members": members, "mass": body.mass, "com": _vec(state.transform.origin + state.center_of_mass), "inertia": [_vec(tensor.x), _vec(tensor.y), _vec(tensor.z)]})
			variants["merged" if merged else "separate"] = records
			hardware.free()
			await physics_frame
		report[name] = variants
	var file: FileAccess = FileAccess.open(_output_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	quit()
func _vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _output_path() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--out")
	return args[index + 1] if index >= 0 and index + 1 < args.size() else "user://compound-audit.json"
