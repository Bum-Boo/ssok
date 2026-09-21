extends SceneTree

## Exports the physics description RunMode derives from a preset graph, for tools/rl_lab.
## godot --headless --path . --script tools/godot/export_rl_robot.gd -- --out <path.json>
## The graph stays the source of truth (ADR 0002); this JSON is a derived, disposable view.


func _initialize() -> void:
	_export.call_deferred()


func _export() -> void:
	var out := _arg("--out", "user://rl_biped.json")
	var preset: String = _arg("--preset", "biped")
	if preset not in ["biped", "yaw_biped"]:
		push_error("Unknown robot preset")
		quit(2)
		return
	var graph: ConnectionGraph = YawBipedPreset.build() if preset == "yaw_biped" else BipedPreset.build()
	var run_mode := RunMode.new()
	root.add_child(run_mode)
	run_mode.build(graph)
	for body: RigidBody3D in run_mode.bodies:
		body.gravity_scale = 0.0
	for frame: int in 2:
		await physics_frame

	var bodies: Array = []
	var seen: Dictionary = {}
	for index: int in run_mode.bodies.size():
		var body: RigidBody3D = run_mode.bodies[index]
		if seen.has(body):
			continue
		seen[body] = true
		var definition: PartDef = graph.parts[index].part_def
		var aabb := definition.mesh.get_aabb()
		var members: Array[int] = []
		for part: int in run_mode.bodies.size():
			if run_mode.bodies[part] == body:
				members.append(part)
		var colliders: Array = []
		for child: Node in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				colliders.append({"size": _vec(child.shape.size), "transform": _transform(child.transform)})
		var entry: Dictionary = {
			"index": index, "part_id": String(definition.id), "mass_kg": body.mass,
			"frozen": body.freeze, "transform": _transform(graph.parts[index].transform),
			"box_size": _vec(aabb.size), "box_center": _vec(aabb.get_center()),
			"source_parts": members, "collision_boxes": colliders,
		}
		if not body.freeze:
			var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
			var rotation: Basis = state.transform.basis.orthonormalized()
			var inertia: Basis = rotation.inverse() * state.inverse_inertia_tensor.inverse() * rotation
			entry.center_of_mass = _vec(state.center_of_mass_local)
			entry.full_inertia = [inertia.x.x, inertia.y.y, inertia.z.z, inertia.y.x, inertia.z.x, inertia.z.y]
		bodies.append(entry)

	var channels := {}
	for channel: Dictionary in run_mode.wired_servo_channels():
		channels[channel.part] = channel.pin
	var joints: Array = []
	for child: Node in run_mode.get_children():
		if not child is Joint3D:
			continue
		var joint := child as Joint3D
		var a := _body_index(run_mode, joint.node_a)
		var b := _body_index(run_mode, joint.node_b)
		var entry := {"a": a, "b": b, "type": "fixed", "anchor": _vec(joint.global_transform.origin)}
		if joint is HingeJoint3D:
			entry.type = "hinge"
			entry.axis = _vec(joint.global_transform.basis.z)
			for part: int in run_mode.servos:
				var drive: ServoDrive = run_mode.servos[part]
				if drive.joint == joint:
					entry.servo_part = part
					entry.pin = channels.get(part, -1)
					entry.speed_deg_per_s = drive.speed_deg_per_s
					entry.relative_limit_deg = 90.0
					entry.actuator_torque_nm = drive.torque_limit_nm
		joints.append(entry)

	var data := {"version": 1, "preset": preset, "gravity": _vec(Vector3(0, -ProjectSettings.get_setting("physics/3d/default_gravity"), 0)),
		"physics_ticks_per_second": Engine.physics_ticks_per_second, "floor_y": BipedPreset.FLOOR_TOP,
		"bodies": bodies, "joints": joints, "graph_fingerprint": MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))}
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % out)
		quit(1)
		return
	file.store_string(JSON.stringify(data, "  ", false, true))
	file.close()
	print("exported %d bodies, %d joints -> %s" % [bodies.size(), joints.size(), ProjectSettings.globalize_path(out)])
	run_mode.teardown()
	quit(0)


func _body_index(run_mode: RunMode, path: NodePath) -> int:
	var node := run_mode.get_node_or_null(path)
	return run_mode.bodies.find(node)


func _arg(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback


static func _vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _transform(t: Transform3D) -> Dictionary:
	return {"origin": _vec(t.origin), "basis_x": _vec(t.basis.x), "basis_y": _vec(t.basis.y), "basis_z": _vec(t.basis.z)}
