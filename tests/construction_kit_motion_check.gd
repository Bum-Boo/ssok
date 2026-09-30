extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _contact_before_grasp: bool = false
var _invalid_contact: bool = false
var _policy: Dictionary = PickupPolicy.defaults()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--crouch="):
			_policy.crouch_height = argument.trim_prefix("--crouch=").to_float()
		if argument.begins_with("--hand-offset="):
			_policy.hand_height_offset = argument.trim_prefix("--hand-offset=").to_float()
	_check(PickupPolicy.validate(_policy).is_empty(), "test policy stays within the same bounded search family")
	if not PickupPolicy.validate(_policy).is_empty():
		_finish()
		return
	print("construction_kit_test_policy: " + JSON.stringify(_policy))
	var graph: ConnectionGraph = ConstructionKitHumanoidPreset.build()
	var initial_snapshot: Dictionary = MotionSnapshot.encode(graph)
	var fingerprint: String = MotionSnapshot.fingerprint(initial_snapshot)
	var hardware: RunMode = RunMode.new()
	root.add_child(hardware)
	var motion: KitHumanoidMotion = KitHumanoidMotion.new()
	root.add_child(motion)
	_check_topology(hardware, motion, graph)
	var floor: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(20.0, 0.10, 20.0)
	collider.shape = shape
	floor.add_child(collider)
	floor.position.y = HumanoidPreset.FLOOR_TOP - 0.05
	root.add_child(floor)
	hardware.build(graph)
	_check(motion.configure(hardware, graph), "fresh construction graph resolves ten generic joint roles")
	if not motion.is_supported():
		_finish()
		return
	motion.pickup_contact_confirmed.connect(func() -> void: _observe_contact(motion, hardware))
	_check(PickupPolicy.apply(motion, _policy), "explicit bounded test policy applies without changing assembled geometry")
	motion.set_enabled(true)
	for frame: int in range(180):
		await physics_frame
	var torso: RigidBody3D = hardware.bodies[motion.body_part]
	var box: RigidBody3D = hardware.bodies[motion._box_part]
	var initial_box_height: float = box.global_position.y
	_check(not motion.fallen, "elementary construction settles under gravity without collapsing")
	_check(motion.request_pickup(), "pickup request starts the actual assembled kit")
	var maximum_lift: float = 0.0
	var minimum_upright: float = 1.0
	var held_frames: int = 0
	var evaluated_frames: int = 0
	for frame: int in range(900):
		await physics_frame
		evaluated_frames = frame + 1
		maximum_lift = maxf(maximum_lift, box.global_position.y - initial_box_height)
		var upright: float = torso.global_basis.y.normalized().dot(Vector3.UP)
		minimum_upright = minf(minimum_upright, upright)
		var stable_hold: bool = motion.grasped and motion.pickup_state == "holding" and box.global_position.y - initial_box_height >= PickupTrial.REQUIRED_LIFT and upright >= PickupTrial.REQUIRED_UPRIGHT
		held_frames = held_frames + 1 if stable_hold else 0
		if frame % (15 if "--verbose" in OS.get_cmdline_user_args() else 120) == 0:
			_check(torso.global_transform.is_finite() and box.global_transform.is_finite(), "physics remains finite through reach and lift")
			_check(not torso.freeze and not box.freeze and torso.gravity_scale == 1.0 and box.gravity_scale == 1.0, "evaluation does not freeze or suppress gravity")
			if "--verbose" in OS.get_cmdline_user_args():
				print("kit_pick t=%.2f state=%s lift=%.3f up=%.3f torso=%s box=%s" % [float(frame) / 60.0, motion.pickup_state, box.global_position.y - initial_box_height, upright, torso.global_position, box.global_position])
				var total_mass: float = 0.0
				var center: Vector3 = Vector3.ZERO
				var seen: Dictionary = {}
				for body: RigidBody3D in hardware.bodies:
					if seen.has(body) or body == box and not motion.grasped:
						continue
					seen[body] = true
					total_mass += body.mass
					center += body.to_global(body.center_of_mass) * body.mass
				print("kit_balance com=%s pitch=%.3f vel=%s" % [center / total_mass, atan2(torso.global_basis.y.z, torso.global_basis.y.y), torso.angular_velocity])
				for side: String in ["left", "right"]:
					var foot: RigidBody3D = hardware.bodies[motion.role_parts[side + "_ankle"]]
					print("kit_foot side=%s pos=%s up=%s" % [side, foot.global_position, foot.global_basis.y])
					var hand: RigidBody3D = hardware.bodies[motion.role_parts[side + "_elbow"]]
					print("kit_hand side=%s shoulder=%s tip=%s contact=%s" % [side, motion._shoulder_position(side), motion._grip_tip(side), box in hand.get_colliding_bodies()])
					var anatomy: Dictionary = KitHumanoidMotion.topology(graph)
					var elbow: Dictionary = anatomy.roles[side + "_elbow"]
					print("kit_elbow side=%s anchor=%s contacts=%s" % [side, hardware.part_global_transform(elbow.motor) * elbow.port.local_position, hand.get_colliding_bodies()])
					for index: int in graph.parts.size():
						if hardware.bodies[index] == hand and graph.parts[index].part_def.id == &"kit_rubber_pad":
							print("kit_pad side=%s part=%d bounds=%s" % [side, index, hardware.part_global_transform(index) * graph.parts[index].part_def.mesh.get_aabb()])
					for role: String in ["hip", "knee", "ankle", "shoulder", "elbow"]:
						var drive: ServoDrive = motion._drives[side + "_" + role]
						print("kit_angle %s_%s target=%.2f measured=%.2f" % [side, role, drive.target_deg, drive.measured_deg])
		if held_frames >= 60 or motion.fallen:
			break
	_check(_contact_before_grasp and not _invalid_contact, "both assembled contact-pad bodies physically touched before grasp constraints")
	_check(held_frames >= 60 and maximum_lift >= PickupTrial.REQUIRED_LIFT, "kit physically lifts the box 25 cm and holds for one second")
	_check(not motion.fallen and minimum_upright >= 0.8, "kit stays upright through the independently measured pickup")
	var release_height: float = box.global_position.y
	motion.release_box()
	_check(not motion.grasped and motion._grips.is_empty(), "release immediately removes transient constraints")
	for frame: int in range(180):
		await physics_frame
	if held_frames >= 60:
		_check(release_height - box.global_position.y > 0.20, "released box actually drops under gravity")
	_check(MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)) == fingerprint, "pickup and release never mutate the editable assembly")
	motion.set_enabled(false)
	hardware.teardown()
	await process_frame
	await process_frame
	hardware.build(graph)
	_check(motion.configure(hardware, graph), "reset rebuilds generic kit from the unchanged authored graph")
	_check(motion._grips.is_empty() and not motion.grasped and motion.pickup_state == "idle", "reset carries no saved runtime grip")
	for index: int in graph.parts.size():
		_check(hardware.part_global_transform(index).is_equal_approx(graph.parts[index].transform), "reset restores every individual beam and connector pose")
	var distant: ConnectionGraph = MotionSnapshot.decode(initial_snapshot)
	for index: int in distant.parts.size():
		if distant.parts[index].part_def.id == &"cargo_box":
			distant.parts[index].transform.origin.z = 3.0
	hardware.build(distant)
	_check(motion.configure(hardware, distant), "distant cargo does not change articulated kit identity")
	motion.set_enabled(true)
	_check(not motion.request_pickup() and motion._grips.is_empty(), "unreachable box cannot be attached remotely")
	motion.set_enabled(false)
	motion.free()
	hardware.free()
	floor.free()
	await process_frame
	await process_frame
	await _check_parallel(graph, fingerprint)
	await _check_perturbed_pickups(graph)
	print("construction_kit_motion_metrics: lift=%.3f m hold=%.3f s min_upright=%.3f duration=%.3f s bilateral_contact=%s" % [maximum_lift, float(held_frames) / 60.0, minimum_upright, float(evaluated_frames) / 60.0, _contact_before_grasp])
	_finish()


func _check_topology(hardware: RunMode, motion: KitHumanoidMotion, graph: ConnectionGraph) -> void:
	var reverse: ConnectionGraph = MotionSnapshot.decode(MotionSnapshot.encode(graph))
	reverse.parts.reverse()
	for link: Dictionary in reverse.links:
		var old_a: int = link.a_part
		var old_a_port: StringName = link.a_port
		link.a_part = reverse.parts.size() - 1 - link.b_part
		link.b_part = reverse.parts.size() - 1 - old_a
		link.a_port = link.b_port
		link.b_port = old_a_port
	reverse.links.reverse()
	hardware.build(reverse)
	_check(motion.configure(hardware, reverse), "humanoid recognition follows graph topology, not part or link order")
	var wires: Array[Dictionary] = []
	for link: Dictionary in reverse.links:
		var a: Port = RunMode._port(reverse.parts[link.a_part].part_def, link.a_port)
		if a.kind == Port.Kind.ELEC:
			wires.append(link)
	if not wires.is_empty():
		reverse.links.erase(wires[0])
		hardware.build(reverse)
		_check(not motion.configure(hardware, reverse) and not motion.is_supported(), "missing motor wire rejects stale supported state")
	var with_loose_part: ConnectionGraph = MotionSnapshot.decode(MotionSnapshot.encode(graph))
	with_loose_part.parts.append({"part_def": load(ConstructionKitHumanoidPreset.CATALOG + "kit_beam_100.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(2.0, 0.5, 0.0))})
	hardware.build(with_loose_part)
	_check(motion.configure(hardware, with_loose_part), "a separate loose beam does not change the assembled humanoid's identity")
	_check(hardware.bodies[-1] not in motion._balance_bodies and motion._balance_bodies.size() == 11, "balance tracks only connected robot masses, excluding unrelated workshop objects")
	var bridge: ConnectionGraph = ConstructionKitHumanoidPreset.build_bridge()
	hardware.build(bridge)
	_check(not motion.configure(hardware, bridge), "same kit parts in a bridge do not masquerade as a humanoid")
	motion.set_enabled(false)
	hardware.teardown()


func _observe_contact(motion: KitHumanoidMotion, hardware: RunMode) -> void:
	var box: RigidBody3D = hardware.bodies[motion._box_part]
	var bilateral: bool = not motion.grasped and motion._grips.is_empty()
	for side: String in ["left", "right"]:
		var hand: RigidBody3D = hardware.bodies[motion.role_parts[side + "_elbow"]]
		bilateral = bilateral and box in hand.get_colliding_bodies()
	_contact_before_grasp = _contact_before_grasp or bilateral
	_invalid_contact = _invalid_contact or not bilateral


func _check_parallel(graph: ConnectionGraph, fingerprint: String) -> void:
	var trials: Array[PickupTrial] = []
	var worlds: Dictionary = {}
	var references: Array[WeakRef] = []
	for index: int in range(2):
		var trial: PickupTrial = PickupTrial.new()
		root.add_child(trial)
		var error: String = trial.start_trial(graph, _policy, false)
		_check(error.is_empty(), "pickup lab accepts elementary construction graph: " + error)
		if not error.is_empty():
			trial.free()
			continue
		trials.append(trial)
		worlds[trial.viewport.find_world_3d().space] = true
		references.append(weakref(trial.viewport))
		_check(trial._motion is KitHumanoidMotion, "parallel trial uses topology-derived kit controller")
	_check(worlds.size() == 2, "parallel construction experiments have independent physics spaces")
	for frame: int in range(PickupTrial.MAX_FRAMES + 2):
		await physics_frame
		if not trials.any(func(trial: PickupTrial) -> bool: return trial.is_running):
			break
	for trial: PickupTrial in trials:
		print("construction_kit_parallel_metrics: " + JSON.stringify(trial.metrics))
		_check(not trial.is_running and PickupPolicy.valid_metrics(trial.metrics), "parallel episode finishes with validated measured evidence")
		_check(trial.metrics.success and trial.metrics.contact_before_grasp, "independent kit episode succeeds with actual bilateral contact")
		_check(trial.metrics.graph_fingerprint == fingerprint, "parallel kit episode retains exact authored assembly identity")
		_check(not PhysicsServer3D.space_is_active(trial.viewport.find_world_3d().space), "only completed episode physics is paused for inspection")
		trial.free()
	await process_frame
	await process_frame
	for reference: WeakRef in references:
		_check(reference.get_ref() == null, "isolated kit world is released after experiment teardown")


func _check_perturbed_pickups(graph: ConnectionGraph) -> void:
	var trials: Array[PickupTrial] = []
	for offset: Vector2 in [Vector2(-0.005, -0.01), Vector2(-0.005, 0.01), Vector2(0.005, -0.01), Vector2(0.005, 0.01)]:
		var shifted: ConnectionGraph = MotionSnapshot.decode(MotionSnapshot.encode(graph))
		for part: Dictionary in shifted.parts:
			if part.part_def.id == &"cargo_box":
				part.transform.origin += Vector3(offset.x, 0.0, offset.y)
		if trials.size() == 3:
			shifted.parts.reverse()
			for link: Dictionary in shifted.links:
				var old_a: int = link.a_part
				var old_port: StringName = link.a_port
				link.a_part = shifted.parts.size() - 1 - link.b_part
				link.b_part = shifted.parts.size() - 1 - old_a
				link.a_port = link.b_port
				link.b_port = old_port
			shifted.links.reverse()
		var trial: PickupTrial = PickupTrial.new()
		root.add_child(trial)
		var error: String = trial.start_trial(shifted, _policy, false)
		_check(error.is_empty(), "perturbed cargo and reordered graph start an independent physical trial")
		if not error.is_empty():
			trial.free()
			continue
		trials.append(trial)
	for frame: int in range(PickupTrial.MAX_FRAMES + 2):
		await physics_frame
		if not trials.any(func(trial: PickupTrial) -> bool: return trial.is_running):
			break
	for trial: PickupTrial in trials:
		print("construction_kit_perturbed_metrics: " + JSON.stringify(trial.metrics))
		_check(PickupPolicy.valid_metrics(trial.metrics) and trial.metrics.success, "pickup withstands 5 mm lateral and 10 mm depth cargo offsets")
		_check(trial.metrics.contact_before_grasp and trial.metrics.min_upright >= PickupTrial.REQUIRED_UPRIGHT, "perturbed pickup retains contact and uprightness requirements")
		for drive: ServoDrive in trial._hardware.servos.values():
			_check(drive.torque_limit_nm > 0.0 and drive.target_deg >= drive.relative_min_deg and drive.target_deg <= drive.relative_max_deg, "successful perturbations preserve finite motor torque and angle limits")
		trial.free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)


func _finish() -> void:
	print("construction_kit_motion_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)
