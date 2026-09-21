extends SceneTree

## Re-evaluates a tools/rl_lab linear policy in ssok's own Godot physics (sim2sim check).
## godot --headless --path . --fixed-fps 60 --script tools/godot/play_rl_policy.gd -- --policy <json>
## Add --window (without --headless) to watch it. Nothing here changes the app or the graph.

const CONTROL_EVERY_FRAMES := 2  # 60 Hz physics -> 30 Hz policy, as in tools/rl_lab/env.py
const FALL_UPRIGHT := 0.5
const FALL_HEIGHT := 0.06

var _hardware: RunMode
var _body: RigidBody3D
var _drives: Array[ServoDrive] = []
var _pairs: Array = []  # [parent body, child body, axis in parent frame, initial relative basis]
var _signs: Array[float] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := _arg("--policy", "")
	var policy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) if not path.is_empty() else {}
	if policy.get("format", "") != "ssok-linear-policy":
		push_error("Pass --policy <tools/rl_lab/runs/.../best_policy.json>")
		quit(2)
		return
	if Engine.physics_ticks_per_second != 60:
		push_error("Policy playback needs 60 Hz physics")
		quit(2)
		return
	if _arg("--window", "") == "":
		root.size = Vector2i(2, 2)
	_add_floor()
	_hardware = RunMode.new()
	root.add_child(_hardware)
	_hardware.build(BipedPreset.build())
	_body = _hardware.bodies[0]
	for pin in policy.joint_pins:
		var drive := _hardware.servo_on_pin(int(pin))
		if drive == null:
			push_error("No servo wired to pin %s" % pin)
			quit(2)
			return
		_drives.append(drive)
		var parent: RigidBody3D = _hardware.get_node(drive.joint.node_a)
		var child: RigidBody3D = _hardware.get_node(drive.joint.node_b)
		var axis_local: Vector3 = parent.global_basis.inverse() * drive.joint.global_basis.z
		_pairs.append([parent, child, axis_local.normalized(), parent.global_basis.inverse() * child.global_basis])

	# Calibrate Godot's write_relative sign against the MuJoCo joint convention.
	for drive in _drives:
		drive.write_relative(0.0)
	await _frames(30)
	for drive in _drives:
		drive.write_relative(10.0)
	await _frames(10)
	for i in _drives.size():
		_signs.append(1.0 if _joint_angle(i) >= 0.0 else -1.0)
		_drives[i].write_relative(0.0)
	await _frames(60)

	var weights: Array = policy.weights
	var mean: Array = policy.obs_mean
	var variance: Array = policy.obs_var
	var scale: float = policy.action_scale_deg
	var gait_hz: float = policy.gait_hz
	var start := _body.global_position
	var forward := Vector3(_body.global_basis.z.x, 0, _body.global_basis.z.z).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var prev_action := PackedFloat64Array([0, 0, 0, 0])
	var prev_angles := _angles()
	var min_upright := 1.0
	var fallen := false
	var steps := 360
	var step := 0
	while step < steps:
		var angles := _angles()
		var obs := PackedFloat64Array()
		for i in angles.size():
			obs.append(angles[i])
		for i in angles.size():
			obs.append((angles[i] - prev_angles[i]) * 30.0 * 0.1)
		obs.append_array(prev_action)
		var inverse := _body.global_basis.orthonormalized().inverse()
		var gravity := inverse * Vector3.DOWN
		var angvel := inverse * _body.angular_velocity * 0.1
		obs.append_array([gravity.x, gravity.y, gravity.z, angvel.x, angvel.y, angvel.z, 1.0])
		var phase := TAU * gait_hz * step / 30.0
		obs.append_array([sin(phase), cos(phase)])
		prev_angles = angles
		var action := PackedFloat64Array()
		for row: Array in weights:
			var total := 0.0
			for j in obs.size():
				total += float(row[j]) * (obs[j] - float(mean[j])) / sqrt(float(variance[j]) + 1e-8)
			action.append(tanh(total))
		for i in _drives.size():
			_drives[i].write_relative(_signs[i] * action[i] * scale)
		prev_action = action
		await _frames(CONTROL_EVERY_FRAMES)
		var upright := _body.global_basis.y.normalized().dot(Vector3.UP)
		min_upright = minf(min_upright, upright)
		if upright < FALL_UPRIGHT or _body.global_position.y - BipedPreset.FLOOR_TOP < FALL_HEIGHT:
			fallen = true
			break
		step += 1

	var moved := _body.global_position - start
	var heading := Vector3(_body.global_basis.z.x, 0, _body.global_basis.z.z).normalized()
	var result := {
		"engine": "godot", "policy": path, "forward_m": moved.dot(forward), "lateral_m": moved.dot(right),
		"yaw_deg": rad_to_deg(forward.signed_angle_to(heading, Vector3.UP)), "fallen": fallen,
		"min_upright": min_upright, "seconds": step / 30.0, "joint_signs": _signs,
	}
	print("RESULT ", JSON.stringify(result))
	quit(0)


## Measured hinge angle: child rotation relative to its parent about the hinge axis (MuJoCo's definition).
func _joint_angle(index: int) -> float:
	var parent: RigidBody3D = _pairs[index][0]
	var child: RigidBody3D = _pairs[index][1]
	var axis: Vector3 = _pairs[index][2]
	var initial: Basis = _pairs[index][3]
	var relative := (parent.global_basis.inverse() * child.global_basis).orthonormalized() * initial.inverse()
	var q := relative.get_rotation_quaternion()
	return 2.0 * atan2(Vector3(q.x, q.y, q.z).dot(axis), q.w)


func _angles() -> PackedFloat64Array:
	var angles := PackedFloat64Array()
	for i in _drives.size():
		angles.append(_joint_angle(i))
	return angles


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _add_floor() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 0.1, 4.0)
	collision.shape = box
	floor.add_child(collision)
	floor.position.y = BipedPreset.FLOOR_TOP - box.size.y * 0.5
	root.add_child(floor)


func _arg(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find(name)
	if at < 0:
		return fallback
	return args[at + 1] if at + 1 < args.size() and not args[at + 1].begins_with("--") else "1"
