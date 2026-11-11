extends "res://src/runtime/drive_motor.gd"
## DEBUG-r17: observe the actual DriveMotor call; delegate unchanged to production.
var debug_action: int = -1
var debug_rows: Array[Dictionary] = []
func _physics_process(delta: float) -> void:
	var actual_duty: float = duty
	var housing_axis_rate: float = housing.angular_velocity.dot((housing.global_basis * axis_local).normalized())
	super._physics_process(delta)
	if debug_action >= 0:
		debug_rows.append({"command_index": debug_action, "tick": Engine.get_physics_frames(),
			"applied_duty": actual_duty, "torque_nm": applied_torque_nm,
			"speed_rad_s": measured_rad_s, "housing_axis_rate_before": housing_axis_rate})
