class_name DriveMotor
extends Node

var housing: RigidBody3D
var wheel: RigidBody3D
var axis_local: Vector3 = Vector3.FORWARD
var stall_torque_nm: float = 0.078
var no_load_rad_s: float = 250.0 * TAU / 60.0
var supply_voltage: float = 6.0
var voltage_drop: float = 0.3
var rated_voltage: float = 6.0
var duty: float = 0.0
var braking: bool = false
var measured_rad_s: float = 0.0
var applied_torque_nm: float = 0.0


func motor_on(direction: Variant, speed: float) -> void:
	duty = clampf(speed, 0.0, 100.0) / 100.0 * (-1.0 if direction in ["reverse", -1] else 1.0)
	braking = false


func stop(mode: String = "brake") -> void:
	duty = 0.0
	braking = mode == "brake"


func _physics_process(delta: float) -> void:
	if not is_instance_valid(housing) or not is_instance_valid(wheel):
		return
	var axis: Vector3 = (housing.global_basis * axis_local).normalized()
	measured_rad_s = (wheel.angular_velocity - housing.angular_velocity).dot(axis)
	var input: float = duty * maxf(0.0, supply_voltage - voltage_drop) / rated_voltage
	var torque: float = stall_torque_nm * (input - measured_rad_s / no_load_rad_s) if duty != 0.0 or braking else 0.0
	torque = clampf(torque, -stall_torque_nm, stall_torque_nm)
	# Apply one equal/opposite angular impulse per step; hinge solver iterations cannot multiply it.
	var inverse_inertia: float = axis.dot(wheel.get_inverse_inertia_tensor() * axis)
	if not housing.freeze:
		inverse_inertia += axis.dot(housing.get_inverse_inertia_tensor() * axis)
	if inverse_inertia > 0.0:
		var target: float = input * no_load_rad_s
		var needed: float = (target - measured_rad_s) / inverse_inertia
		var impulse: float = clampf(torque * delta, minf(0.0, needed), maxf(0.0, needed))
		applied_torque_nm = impulse / delta
		wheel.apply_torque_impulse(axis * impulse)
		if not housing.freeze:
			housing.apply_torque_impulse(-axis * impulse)
