class_name GearConstraint
extends Node

## Ideal external gears: wi + ratio * wo = (1 + ratio) * wh.
## A single Jacobian impulse conserves work and includes the housing reaction.
var housing: RigidBody3D
var input: RigidBody3D
var output: RigidBody3D
var ratio: float = 2.0
var axis_local: Vector3 = Vector3.BACK
var input_torque_nm: float = 0.0
var output_torque_nm: float = 0.0
var housing_torque_nm: float = 0.0


func _physics_process(delta: float) -> void:
	var axis: Vector3 = (housing.global_basis * axis_local).normalized()
	var reaction: float = 1.0 + ratio
	var inverse: float = _inverse(input, axis) + ratio * ratio * _inverse(output, axis) + reaction * reaction * _inverse(housing, axis)
	if inverse <= 0.0:
		return
	var error: float = (_velocity(input) + ratio * _velocity(output) - reaction * _velocity(housing)).dot(axis)
	var impulse: float = -error / inverse
	input_torque_nm = impulse / delta
	output_torque_nm = ratio * input_torque_nm
	housing_torque_nm = -reaction * input_torque_nm
	input.apply_torque_impulse(axis * impulse)
	output.apply_torque_impulse(axis * impulse * ratio)
	if not housing.freeze:
		housing.apply_torque_impulse(-axis * impulse * reaction)


static func _inverse(body: RigidBody3D, axis: Vector3) -> float:
	return 0.0 if body.freeze else axis.dot(body.get_inverse_inertia_tensor() * axis)


static func _velocity(body: RigidBody3D) -> Vector3:
	return PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
