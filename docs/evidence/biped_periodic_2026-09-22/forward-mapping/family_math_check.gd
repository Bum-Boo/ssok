extends SceneTree
const FAMILY = preload("res://probe/forward_family.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	var max_error: float = 0.0
	for input: float in [0.1, 0.5, 1.0]:
		for tick: int in range(0,7200,2):
			var value: Vector4 = FAMILY.pose_for_tick(tick,FAMILY.REFERENCE_CYCLE,FAMILY.REFERENCE_STRIDE,FAMILY.REFERENCE_LEAN,0.0,input)
			var expected: Vector4 = reference(tick,input)
			for joint: int in 4:
				max_error = maxf(max_error,absf(value[joint]-expected[joint]))
			check(value == expected,"default must exactly equal the calibrated forward commands")
	for tick: int in range(0,240,2):
		var original: Vector4 = FAMILY.pose_for_tick(tick,FAMILY.REFERENCE_CYCLE,FAMILY.REFERENCE_STRIDE,FAMILY.REFERENCE_LEAN,0.0)
		var hips: Vector4 = FAMILY.pose_for_tick(tick,FAMILY.REFERENCE_CYCLE,0.0,FAMILY.REFERENCE_LEAN,0.0)
		var ankles: Vector4 = FAMILY.pose_for_tick(tick,FAMILY.REFERENCE_CYCLE,FAMILY.REFERENCE_STRIDE,0.0,0.0)
		var posture: Vector4 = FAMILY.pose_for_tick(tick,FAMILY.REFERENCE_CYCLE,FAMILY.REFERENCE_STRIDE,FAMILY.REFERENCE_LEAN,5.0)
		var slow: Vector4 = FAMILY.pose_for_tick(tick*2,FAMILY.REFERENCE_CYCLE*2,FAMILY.REFERENCE_STRIDE,FAMILY.REFERENCE_LEAN,0.0)
		check(hips.x==0 and hips.y==0 and hips.z==original.z and hips.w==original.w,"stride zero removes only hip carrier")
		check(ankles.z==0 and ankles.w==0 and ankles.x==original.x and ankles.y==original.y,"lean zero removes only ankle carrier")
		check(posture.is_equal_approx(original + Vector4(-5,5,0,0)),"posture retains opposite physical hip offsets")
		check(slow.is_equal_approx(original),"cycle doubles the complete period")
	for cycle: float in [0.8,4.0]:
		for stride: float in [0.0,35.0]:
			for lean: float in [0.0,35.0]:
				for posture: float in [-10.0,10.0]:
					for tick: int in range(0,240,2):
						var pose: Vector4 = FAMILY.pose_for_tick(tick,cycle,stride,lean,posture)
						check(pose.is_finite() and absf(pose.x)<=45.00001 and absf(pose.y)<=45.00001 and absf(pose.z)<=35.00001 and absf(pose.w)<=35.00001,"bounded family remains inside existing servo angle range")
	print(JSON.stringify({"checks":checks,"failures":failures,"default_samples":10800,"default_max_error_degrees":max_error,"defaults":{"cycle_seconds":FAMILY.REFERENCE_CYCLE,"stride_degrees":FAMILY.REFERENCE_STRIDE,"lean_degrees":FAMILY.REFERENCE_LEAN,"posture_degrees":0.0}}))
	quit(1 if failures else 0)
func reference(tick: int, forward: float) -> Vector4:
	var phase: float = TAU * 0.6039625933948914 * float(tick) / 60.0
	var sn: float = sin(phase)
	var cs: float = cos(phase)
	return Vector4(
		40.0 * tanh(0.5342501548218581 + 0.5868715408738633 * sn + 0.08074402755852503 * cs) * forward,
		40.0 * tanh(-0.5342501548218581 + 0.5868715408738633 * sn + 0.08074402755852503 * cs) * forward,
		40.0 * tanh(-0.24988381357116327 - 0.3856616063625936 * sn + 0.33992161715486213 * cs),
		40.0 * tanh(-0.24988381357116327 + 0.3856616063625936 * sn - 0.33992161715486213 * cs))
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
