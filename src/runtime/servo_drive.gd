class_name ServoDrive
extends Node

## Positional servo model: slews the hinge toward a commanded angle at a bounded speed.
## Unpowered (no command yet) the hinge swings freely, like a real servo with no signal.

@export var speed_deg_per_s: float = 180.0
@export var min_deg: float = 0.0
@export var max_deg: float = 180.0

var joint: HingeJoint3D
var target_deg: float = 0.0
var current_deg: float = 0.0
var powered: bool = false
var torque_limit_nm: float = 0.0
var relative_min_deg: float = -90.0
var relative_max_deg: float = 90.0
var measured_deg: float = 0.0
var velocity_gain: float = 12.0
var maximum_velocity: float = 4.0
var _body_a: RigidBody3D
var _body_b: RigidBody3D
var _axis_a: Vector3
var _reference_a: Vector3
var _reference_b: Vector3
var _motor_sign: float = -1.0


func configure_torque_actuator(a: RigidBody3D, b: RigidBody3D, definition: PartDef, owner_is_a: bool = false) -> void:
	torque_limit_nm = definition.actuator_torque_nm
	relative_min_deg = definition.actuator_min_deg
	relative_max_deg = definition.actuator_max_deg
	if definition.actuator_drives_connected_body:
		owner_is_a = not owner_is_a
	_body_a = b if owner_is_a else a
	_body_b = a if owner_is_a else b
	_motor_sign = 1.0 if owner_is_a else -1.0
	_axis_a = _body_a.global_basis.inverse() * joint.global_basis.z
	_reference_a = _body_a.global_basis.inverse() * joint.global_basis.x
	_reference_b = _body_b.global_basis.inverse() * joint.global_basis.x
	speed_deg_per_s = 240.0
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(relative_min_deg if owner_is_a else -relative_max_deg))
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(relative_max_deg if owner_is_a else -relative_min_deg))


func write(angle_deg: float) -> void:
	_set_target(clampf(angle_deg, min_deg, max_deg))


## Robot programs use signed angles around the assembly pose; learner write() stays 0..180.
func write_relative(angle_deg: float) -> void:
	_set_target(clampf(angle_deg, relative_min_deg, relative_max_deg))


func _set_target(angle_deg: float) -> void:
	if not is_finite(angle_deg):
		return
	target_deg = clampf(angle_deg, relative_min_deg, relative_max_deg) if torque_limit_nm > 0.0 else angle_deg
	if not powered:
		current_deg = target_deg
		powered = true
		if torque_limit_nm <= 0.0:
			_apply()


func _physics_process(delta: float) -> void:
	if not powered or joint == null:
		return
	var step := speed_deg_per_s * delta
	current_deg = move_toward(current_deg, target_deg, step)
	_apply()


func _apply() -> void:
	if torque_limit_nm > 0.0:
		var axis: Vector3 = (_body_a.global_basis * _axis_a).normalized()
		var reference_a: Vector3 = _body_a.global_basis * _reference_a
		var reference_b: Vector3 = _body_b.global_basis * _reference_b
		var angle: float = reference_a.signed_angle_to(reference_b, axis)
		measured_deg = rad_to_deg(angle)
		var error: float = wrapf(deg_to_rad(current_deg) - angle, -PI, PI)
		joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, _motor_sign * clampf(error * velocity_gain, -maximum_velocity, maximum_velocity))
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, torque_limit_nm / Engine.physics_ticks_per_second)
		return
	var rad := deg_to_rad(current_deg)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, rad)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, rad)
