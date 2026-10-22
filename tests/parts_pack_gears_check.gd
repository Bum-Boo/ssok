extends SceneTree

var checks: int = 0
var failures: int = 0
const ROOT: String = "res://assets/construction_kit/parts/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for ratio: int in [2, 3]:
		var assembly := AssemblyMode.new()
		root.add_child(assembly)
		var motor: PartNode = assembly.spawn_part(load("res://assets/parts/tt_motor.tres"), Transform3D.IDENTITY)
		var axle: PartNode = assembly.spawn_part(load(ROOT + "kit_axle_40.tres"), Transform3D.IDENTITY)
		_check(assembly.snap(axle, &"motor_hub", motor, &"shaft_left"), "motor to axle")
		var gear: PartNode = assembly.spawn_part(load(ROOT + "kit_gear_%d.tres" % ratio), Transform3D.IDENTITY)
		_check(assembly.snap(gear, &"input", axle, &"front"), "axle to reducer")
		var spacer: PartNode = assembly.spawn_part(load(ROOT + "kit_axle_40.tres"), Transform3D.IDENTITY)
		_check(assembly.snap(spacer, &"back", gear, &"output"), "output axle clearance")
		var wheel: PartNode = assembly.spawn_part(load(ROOT + "kit_wheel_90.tres"), Transform3D.IDENTITY)
		_check(assembly.snap(wheel, &"kit_hub", spacer, &"front"), "reducer to wheel")
		for collider: StaticBody3D in assembly.find_children("*", "StaticBody3D", true, false):
			collider.collision_layer = 0
		var hardware := RunMode.new()
		root.add_child(hardware)
		hardware.build(assembly.graph)
		var fingerprint: String = MotionSnapshot.fingerprint(MotionSnapshot.encode(assembly.graph))
		_check(hardware.gears.size() == 1 and hardware.servos.is_empty(), "passive graph-derived gearbox")
		var transmission: GearConstraint = hardware.gears[2]
		for body: RigidBody3D in hardware.bodies:
			body.gravity_scale = 0
		hardware.bodies[0].freeze = true
		hardware.bodies[2].freeze = true
		transmission.input.gravity_scale = 0
		transmission.output.gravity_scale = 0
		await physics_frame
		await physics_frame
		var drive: DriveMotor = hardware.motors[0]
		drive.forward(30)
		for tick: int in 180:
			await physics_frame
		var axis: Vector3 = hardware.bodies[2].global_basis.z
		var wi: float = transmission.input.angular_velocity.dot(axis)
		var wo: float = hardware.bodies[4].angular_velocity.dot(axis)
		print("GEAR ratio=%d input=%.5f output=%.5f ratio_observed=%.5f motor_torque=%.6f" % [ratio, wi, wo, -wi / wo, drive.applied_torque_nm])
		_check(absf(wi) > 1 and absf(-wi / wo - ratio) < 0.08, "measured chain speed and opposite rotation")
		_check(absf(drive.applied_torque_nm) <= 0.07801, "motor whole-step budget unchanged")
		_check(fingerprint == MotionSnapshot.fingerprint(MotionSnapshot.encode(assembly.graph)), "physics never writes editor graph")
		hardware.free()
		assembly.free()
		await process_frame

		# Unit-inertia rotors isolate actual transmitted impulses from bearing/chain solver lag.
		for direction: float in [-1.0, 1.0]:
			var rig := RunMode.new()
			root.add_child(rig)
			var graph := ConnectionGraph.new()
			graph.parts.append({"part_def": load(ROOT + "kit_gear_%d.tres" % ratio), "transform": Transform3D.IDENTITY})
			rig.build(graph)
			var constraint: GearConstraint = rig.gears[0]
			constraint.set_physics_process(false)
			for body: RigidBody3D in [constraint.input, constraint.output, constraint.housing]:
				body.gravity_scale = 0
				body.angular_damp = 0
				body.inertia = Vector3.ONE
			await physics_frame
			await physics_frame
			var dt: float = 1.0 / Engine.physics_ticks_per_second
			constraint.input.apply_torque_impulse(Vector3.BACK * direction * 0.03 * dt)
			constraint._physics_process(dt)
			var measured_in: float = (GearConstraint._velocity(constraint.input).z - GearConstraint._velocity(constraint.housing).z)
			var measured_out: float = (GearConstraint._velocity(constraint.output).z - GearConstraint._velocity(constraint.housing).z)
			print("GEAR_IMPULSE ratio=%d direction=%+.0f measured_output_torque=%.6f input_reaction=%.6f housing=%.6f" % [ratio, direction, GearConstraint._velocity(constraint.output).z / dt, constraint.input_torque_nm, GearConstraint._velocity(constraint.housing).z / dt])
			_check(absf(measured_in + ratio * measured_out) < 0.00001, "moving housing relative gear ratio")
			_check(absf(GearConstraint._velocity(constraint.output).z / dt - constraint.output_torque_nm) < 0.00001, "measured unit-inertia acceleration equals transmitted torque")
			_check(is_equal_approx(constraint.output_torque_nm, ratio * constraint.input_torque_nm), "torque multiplication")
			_check(constraint.output_torque_nm * direction < 0 and GearConstraint._velocity(constraint.housing).z * direction > 0, "output and housing reaction signs")
			_check(absf((GearConstraint._velocity(constraint.input).z + GearConstraint._velocity(constraint.output).z + GearConstraint._velocity(constraint.housing).z) / dt - direction * 0.03) < 0.00001, "angular momentum conserved")
			rig.free()
			await process_frame
	print("parts_pack_gears_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
