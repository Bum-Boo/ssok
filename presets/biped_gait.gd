class_name BipedGait
extends RefCounted

# Calibration only. Its training provenance and failed 0.30m research gate remain distinct
# from the new four-parameter family's freshly measured manual-control behavior.
const REFERENCE_HZ: float = 0.6039625933948914
const REFERENCE_CYCLE: float = 1.655731680962178
const REFERENCE_STRIDE: float = 32.39478715279682
const REFERENCE_LEAN: float = 25.736307930089378

static func pose_for_tick(tick: int, cycle: float, stride: float, lean: float, posture: float, forward: float = 1.0) -> Vector4:
	var frequency: float = REFERENCE_HZ * (REFERENCE_CYCLE / cycle)
	var phase: float = TAU * frequency * float(tick) / 60.0
	var sn: float = sin(phase)
	var cs: float = cos(phase)
	var pose := Vector4(
		40.0 * tanh(0.5342501548218581 + 0.5868715408738633 * sn + 0.08074402755852503 * cs) * forward,
		40.0 * tanh(-0.5342501548218581 + 0.5868715408738633 * sn + 0.08074402755852503 * cs) * forward,
		40.0 * tanh(-0.24988381357116327 - 0.3856616063625936 * sn + 0.33992161715486213 * cs),
		40.0 * tanh(-0.24988381357116327 + 0.3856616063625936 * sn - 0.33992161715486213 * cs))
	pose.x = pose.x * (stride / REFERENCE_STRIDE) - posture * forward
	pose.y = pose.y * (stride / REFERENCE_STRIDE) + posture * forward
	pose.z *= lean / REFERENCE_LEAN
	pose.w *= lean / REFERENCE_LEAN
	return pose
