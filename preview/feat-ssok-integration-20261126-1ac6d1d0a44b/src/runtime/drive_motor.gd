class_name DriveMotor
extends Node

## Brush and gearbox losses at the output shaft as a share of stall torque. The 1:48 TT motor
## draws about 150 mA without load against 1.5 A at stall (assets/part_specs.json), so its
## internal friction is about a tenth of the stall torque. The linear drive model already
## includes it through the measured no-load speed; an undriven shaft must still overcome it.
const FRICTION_SHARE: float = 0.1

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
## False while the electrical model finds no power at the driver; the shaft then meets only
## the gearbox friction.
var supply_ok: bool = true
var measured_rad_s: float = 0.0
var applied_torque_nm: float = 0.0


func motor_on(direction: Variant, speed: float) -> void:
	duty = clampf(speed, 0.0, 100.0) / 100.0 * (-1.0 if direction in ["reverse", -1] else 1.0)
	braking = false


func stop(mode: String = "brake") -> void:
	duty = 0.0
	braking = mode == "brake"


func forward(speed: float) -> void:
	motor_on("forward", speed)


func backward(speed: float) -> void:
	motor_on("reverse", speed)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(housing) or not is_instance_valid(wheel):
		return
	var axis: Vector3 = (housing.global_basis * axis_local).normalized()
	measured_rad_s = (wheel.angular_velocity - housing.angular_velocity).dot(axis)
	# Apply one equal/opposite angular impulse per step; hinge solver iterations cannot multiply it.
	var inverse_inertia: float = axis.dot(wheel.get_inverse_inertia_tensor() * axis)
	if not housing.freeze:
		inverse_inertia += axis.dot(housing.get_inverse_inertia_tensor() * axis)
	if inverse_inertia <= 0.0:
		return
	var impulse: float = 0.0
	var driven: bool = supply_ok and duty != 0.0
	if supply_ok and (driven or braking):
		var input: float = duty * maxf(0.0, supply_voltage - voltage_drop) / rated_voltage
		var torque: float = clampf(stall_torque_nm * (input - measured_rad_s / no_load_rad_s), -stall_torque_nm, stall_torque_nm)
		var needed: float = (input * no_load_rad_s - measured_rad_s) / inverse_inertia
		impulse = clampf(torque * delta, minf(0.0, needed), maxf(0.0, needed))
	if not driven:
		# Coasting, braking or unpowered: gearbox friction opposes back-driving but never reverses it.
		var remaining: float = -(measured_rad_s + impulse * inverse_inertia) / inverse_inertia
		var friction: float = stall_torque_nm * FRICTION_SHARE * delta
		impulse += clampf(remaining, -friction, friction)
	applied_torque_nm = impulse / delta
	wheel.apply_torque_impulse(axis * impulse)
	if not housing.freeze:
		housing.apply_torque_impulse(-axis * impulse)
