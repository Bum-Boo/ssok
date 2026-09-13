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


func write(angle_deg: float) -> void:
	target_deg = clampf(angle_deg, min_deg, max_deg)
	if not powered:
		current_deg = target_deg
		powered = true
		_apply()


func _physics_process(delta: float) -> void:
	if not powered or joint == null:
		return
	var step := speed_deg_per_s * delta
	current_deg = move_toward(current_deg, target_deg, step)
	_apply()


func _apply() -> void:
	var rad := deg_to_rad(current_deg)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, rad)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, rad)
