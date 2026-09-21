class_name MotionPolicy
extends RefCounted

## The model may tune these values, never executable code or robot geometry.

const LIMITS: Dictionary = {
	"cycle_seconds": [0.8, 4.0],
	"stride_degrees": [0.0, 35.0],
	"lean_degrees": [0.0, 35.0],
	"posture_degrees": [-10.0, 10.0],
}


static func defaults() -> Dictionary:
	return {"cycle_seconds": 3.45, "stride_degrees": 10.5, "lean_degrees": 18.5, "posture_degrees": -9.8}


static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != LIMITS.size():
		return "Policy must contain exactly four motion parameters"
	for key: String in LIMITS:
		if not value.has(key):
			return "Missing motion parameter: " + key
		var number: Variant = value[key]
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)):
			return "Motion parameter must be a finite number: " + key
		var bounds: Array = LIMITS[key]
		if float(number) < float(bounds[0]) or float(number) > float(bounds[1]):
			return "%s must be between %s and %s" % [key, bounds[0], bounds[1]]
	return ""


static func apply(program: BipedMotion, policy: Dictionary) -> bool:
	if not is_instance_valid(program) or not validate(policy).is_empty():
		return false
	program.cycle_seconds = float(policy.cycle_seconds)
	program.stride_degrees = float(policy.stride_degrees)
	program.lean_degrees = float(policy.lean_degrees)
	program.posture_degrees = float(policy.posture_degrees)
	return true


static func read(program: BipedMotion) -> Dictionary:
	if not is_instance_valid(program):
		return {}
	return {
		"cycle_seconds": program.cycle_seconds,
		"stride_degrees": program.stride_degrees,
		"lean_degrees": program.lean_degrees,
		"posture_degrees": program.posture_degrees,
	}
