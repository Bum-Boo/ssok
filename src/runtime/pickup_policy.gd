class_name PickupPolicy
extends RefCounted

## Only bounded pose-controller parameters cross the proposal boundary.

const LIMITS: Dictionary = {
	"crouch_height": [0.18, 0.26],
	"torso_lean_deg": [15.0, 32.0],
	"reach_seconds": [1.5, 3.5],
	"lift_seconds": [2.0, 4.0],
	"hand_height_offset": [0.04, 0.095],
	"hold_shoulder_deg": [-45.0, -25.0],
	"hold_elbow_deg": [-75.0, -45.0],
}
const PHASES: Array[String] = ["ready", "settling", "reaching", "lifting", "holding", "succeeded", "failed", "cancelled"]


static func defaults() -> Dictionary:
	return {
		"crouch_height": 0.20, "torso_lean_deg": 25.0,
		"reach_seconds": 2.0, "lift_seconds": 2.5,
		"hand_height_offset": 0.075, "hold_shoulder_deg": -35.0,
		"hold_elbow_deg": -60.0,
	}


static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != LIMITS.size():
		return "Pickup policy must contain exactly seven parameters"
	for key: String in LIMITS:
		if not value.has(key):
			return "Pickup policy is missing a required parameter"
		var number: Variant = value[key]
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)):
			return "Pickup parameters must be finite numbers"
		var bounds: Array = LIMITS[key]
		if float(number) < float(bounds[0]) or float(number) > float(bounds[1]):
			return "Pickup parameter is outside its safety bounds"
	return ""


static func apply(program: HumanoidMotion, policy: Dictionary) -> bool:
	if not is_instance_valid(program) or not validate(policy).is_empty():
		return false
	program.pickup_policy = policy.duplicate(true)
	return true


static func mock_candidates(count: int, round_index: int, history: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var center: Dictionary = defaults()
	var best_score: float = -INF
	for entry: Variant in history:
		if not entry is Dictionary or not validate(entry.get("policy")).is_empty():
			continue
		var observed: Variant = entry.get("metrics")
		if not valid_metrics(observed) or not observed.finite or observed.get("cancelled", false):
			continue
		if float(observed.score) > best_score:
			best_score = float(observed.score)
			center = entry.policy.duplicate(true)
	for index: int in range(clampi(count, 1, 4)):
		var candidate: Dictionary = center.duplicate(true)
		if index > 0 or round_index > 0:
			var offset: int = maxi(round_index, 0) * 4 + index - 1
			var key: String = LIMITS.keys()[posmod(offset, LIMITS.size())]
			var bounds: Array = LIMITS[key]
			var direction: float = 1.0 if posmod(offset / LIMITS.size(), 2) == 0 else -1.0
			candidate[key] = clampf(float(candidate[key]) + (float(bounds[1]) - float(bounds[0])) * 0.10 * direction, bounds[0], bounds[1])
		result.append({"policy": candidate, "reason": "Baseline pickup parameters" if index == 0 and round_index == 0 else "Bounded variation around the best measured pickup"})
	return result


static func valid_metrics(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key: String in ["finite", "fallen", "success"]:
		if not value.get(key) is bool:
			return false
	var ranges: Dictionary = {
		"lift_m": [-200.0, 200.0], "hold_seconds": [0.0, 15.0],
		"min_upright": [-1.0, 1.0], "score": [-10000.0, 10000.0],
		"simulation_seconds": [0.0, 15.0001],
	}
	for key: String in ranges:
		var number: Variant = value.get(key)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)):
			return false
		if float(number) < ranges[key][0] or float(number) > ranges[key][1]:
			return false
	var fingerprint: Variant = value.get("graph_fingerprint")
	if not fingerprint is String or fingerprint.length() != 64:
		return false
	for character: String in fingerprint:
		if not character in "0123456789abcdef":
			return false
	if not value.get("engine_version") is String or typeof(value.get("physics_hz")) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if value.engine_version != "4.7.2" or value.physics_hz != 60:
		return false
	if not value.get("phase") is String or value.phase not in PHASES:
		return false
	for key: String in ["contact_before_grasp", "grasped", "left_contact", "right_contact", "cancelled"]:
		if value.has(key) and not value[key] is bool:
			return false
	for key: String in ["upright", "max_lift_m"]:
		if value.has(key) and (typeof(value[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[key]))):
			return false
	if value.has("upright") and (float(value.upright) < -1.0 or float(value.upright) > 1.0):
		return false
	if value.has("max_lift_m") and (float(value.max_lift_m) < 0.0 or float(value.max_lift_m) > 200.0):
		return false
	if value.get("cancelled", false) and value.phase != "cancelled":
		return false
	if value.success:
		if not value.finite or value.fallen or float(value.lift_m) < 0.25 or float(value.hold_seconds) < 1.0:
			return false
		if not value.get("contact_before_grasp", false) or value.phase != "succeeded" or value.get("cancelled", false):
			return false
	return true
