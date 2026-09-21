extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/learned_tracking_parity.json"))
	var policy: Dictionary = fixture.policy
	_check(LearnedBipedMotion.validate_policy(policy).is_empty(), "serialized v2 policy accepted")
	var action: PackedFloat64Array = LearnedBipedMotion.infer(policy, PackedFloat64Array(fixture.observation))
	for index: int in 4:
		_check(absf(action[index] - float(fixture.expected[index])) < 1e-9, "24-feature Python/Godot numerical parity")
	for bad_version: float in [1.0, 1.5, 3.0]:
		var invalid: Dictionary = policy.duplicate(true)
		invalid.version = bad_version
		_check(not LearnedBipedMotion.validate_policy(invalid).is_empty(), "reject version/dimension mismatch")
	var invalid: Dictionary = policy.duplicate(true)
	invalid.weights[0][23] = INF
	_check(not LearnedBipedMotion.validate_policy(invalid).is_empty(), "reject nonfinite tracking weight")
	var graph: ConnectionGraph = YawBipedPreset.build()
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	policy.graph_fingerprint = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
	policy.runtime_fingerprint = LearnedBipedMotion.runtime_fingerprint(hardware, graph, 1)
	var motion := LearnedBipedMotion.new()
	root.add_child(motion)
	motion.load_policy(policy)
	_check(not motion.configure(hardware, graph), "v2 rejects v1 timing/observation fingerprint")
	policy.runtime_fingerprint = LearnedBipedMotion.runtime_fingerprint(hardware, graph, 2)
	motion.load_policy(policy)
	_check(motion.configure(hardware, graph), "v2 binds matching graph and runtime")
	var body: RigidBody3D = hardware.bodies[motion.body_part]
	# Coordinate fixtures do not advance physics or serve as locomotion evidence.
	for rotation: float in [0.0, 1.1, -2.0]:
		var frame := Basis(Vector3.UP, rotation)
		var origin := Vector3(4.0, 2.0, -3.0)
		body.global_transform = Transform3D(frame, origin)
		body.linear_velocity = Vector3.ZERO
		motion.set_enabled(true)
		motion.set_move_input(Vector2(0, 1))
		motion._physics_process(1.0 / 60.0)
		var observation: PackedFloat64Array = motion.observation()
		_check(observation.size() == 24, "v2 appends exactly three observations")
		_check(absf(observation[21]) < 1e-6 and absf(observation[23]) < 1e-6, "command captures current position and heading")
		body.global_position = origin + frame * Vector3(0.07, 0, 0.4)
		body.linear_velocity = frame * Vector3(-0.03, 0, 0.1)
		body.global_basis = frame * Basis(Vector3.UP, 0.2) * Basis(Vector3.RIGHT, 0.3)
		observation = motion.observation()
		_check(absf(observation[21] - 0.07) < 1e-6, "lateral position invariant under world frame")
		_check(absf(observation[22] + 0.03) < 1e-6, "lateral velocity invariant under world frame")
		_check(absf(observation[23] - 0.2) < 1e-6, "horizontal heading ignores pitch and world frame")
		motion.set_move_input(Vector2.ZERO)
		motion._physics_process(1.0 / 60.0)
		motion.set_move_input(Vector2(0, 1))
		motion._physics_process(1.0 / 60.0)
		observation = motion.observation()
		_check(absf(observation[21]) < 1e-6 and absf(observation[23]) < 1e-6, "restart captures a new command frame")
		motion.set_enabled(false)
	motion.free()
	hardware.teardown()
	hardware.free()
	print("learned_tracking_check: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)
