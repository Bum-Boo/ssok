extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/learned_policy_parity.json"))
	var data: Dictionary = fixture.policy
	_check(LearnedBipedMotion.validate_policy(data).is_empty(), "valid policy accepted")
	var observations := PackedFloat64Array(fixture.observation)
	var result: PackedFloat64Array = LearnedBipedMotion.infer(data, observations)
	# Generated independently with the Python policy and non-identity normalization.
	var expected := PackedFloat64Array(fixture.expected)
	for index: int in 4:
		_check(absf(result[index] - expected[index]) < 1e-9, "Python/GDScript action parity")
	var malformed: Dictionary = data.duplicate(true)
	malformed.weights[0][0] = NAN
	_check(not LearnedBipedMotion.validate_policy(malformed).is_empty(), "reject non-finite weights")
	malformed = data.duplicate(true)
	malformed.obs_var[4] = -1.0
	_check(not LearnedBipedMotion.validate_policy(malformed).is_empty(), "reject negative variance")
	malformed = data.duplicate(true)
	malformed.joint_pins[1] = malformed.joint_pins[0]
	_check(not LearnedBipedMotion.validate_policy(malformed).is_empty(), "reject duplicate pin mapping")
	malformed = data.duplicate(true)
	malformed.godot_joint_signs = [0, 1, 1, 1]
	_check(not LearnedBipedMotion.validate_policy(malformed).is_empty(), "reject missing motor polarity")
	var graph: ConnectionGraph = BipedPreset.build()
	data.graph_fingerprint = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	data.runtime_fingerprint = LearnedBipedMotion.runtime_fingerprint(hardware, graph)
	var controller := LearnedBipedMotion.new()
	root.add_child(controller)
	_check(controller.load_policy(data), "load valid weights")
	_check(controller.configure(hardware, graph), "bind matching graph through wiring")
	hardware.bodies[0].mass += 0.01
	_check(not controller.configure(hardware, graph), "reject changed physical properties")
	hardware.bodies[0].mass -= 0.01
	var shape: CollisionShape3D
	for child: Node in hardware.bodies[0].get_children():
		if child is CollisionShape3D:
			shape = child
			break
	var before: Basis = shape.basis
	shape.rotate_y(0.1)
	_check(not controller.configure(hardware, graph), "reject changed collider orientation")
	shape.basis = before
	hardware.bodies[0].center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	hardware.bodies[0].center_of_mass = Vector3(0.001, 0, 0)
	_check(not controller.configure(hardware, graph), "reject changed center of mass")
	hardware.bodies[0].center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
	hardware.bodies[0].center_of_mass = Vector3.ZERO
	graph.parts[0].transform.origin.x += 0.001
	_check(not controller.configure(hardware, graph), "reject changed assembly")
	controller.queue_free()
	hardware.teardown()
	hardware.queue_free()
	print("learned_policy_check: ", "PASS" if _failures == 0 else "FAIL", " (", _failures, " failures)")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)
