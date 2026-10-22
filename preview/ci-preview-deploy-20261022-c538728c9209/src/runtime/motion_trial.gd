class_name MotionTrial
extends Node

## A bounded episode in its own physics space; the visible assembly never moves.

const ENGINE_VERSION: String = "4.7.2"
const PHYSICS_HZ: int = 60
const SETTLE_FRAMES: int = 180
const MOVE_FRAMES: int = 720
const REST_FRAMES: int = 90
const FALL_UPRIGHT: float = 0.5
const FALL_HEIGHT: float = 0.06

var _busy: bool = false
var _cancelled: bool = false
var _viewport: SubViewport
var _hardware: RunMode
var _motion: BipedMotion
var _minimum_upright: float = 1.0
var _minimum_height: float = INF
var _finite: bool = true
var _fallen: bool = false


func is_running() -> bool:
	return _busy


func cancel() -> void:
	_cancelled = true
	if is_instance_valid(_motion):
		_motion.set_enabled(false)


func run_trial(graph: ConnectionGraph, policy: Dictionary, command: Vector2 = Vector2(0, 1)) -> Dictionary:
	if _busy:
		return {"error": "A motion trial is already running"}
	if not is_inside_tree():
		return {"error": "Motion trial must be attached to the scene tree"}
	var engine_error: String = _engine_version_error(Engine.get_version_info())
	if not engine_error.is_empty():
		return {"error": engine_error}
	if Engine.physics_ticks_per_second != PHYSICS_HZ or not is_equal_approx(Engine.time_scale, 1.0):
		return {"error": "Motion trials require 60 Hz physics and time_scale 1"}
	var validation: String = MotionPolicy.validate(policy)
	if not validation.is_empty():
		return {"error": validation}
	if not command.is_finite() or command.length() > 1.000001:
		return {"error": "Movement command must be finite and within the unit circle"}
	var snapshot: Dictionary = MotionSnapshot.encode(graph)
	var trial_graph: ConnectionGraph = MotionSnapshot.decode(snapshot)
	if trial_graph == null:
		return {"error": "Assembly cannot be encoded as a safe catalog graph"}
	_busy = true
	_cancelled = false
	_minimum_upright = 1.0
	_minimum_height = INF
	_finite = true
	_fallen = false
	_viewport = SubViewport.new()
	_viewport.name = "IsolatedMotionWorld"
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(2, 2)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_add_floor()
	_hardware = RunMode.new()
	_viewport.add_child(_hardware)
	_hardware.build(trial_graph)
	_motion = BipedMotion.new()
	_viewport.add_child(_motion)
	if not _motion.configure(_hardware, trial_graph):
		var reason: String = _motion.get_status()
		_cleanup()
		return {"error": reason}
	_motion.apply_policy(policy)
	_motion.set_enabled(true)
	if not await _step_frames(SETTLE_FRAMES):
		return _interrupted_result(policy)
	var body: RigidBody3D = _hardware.bodies[_motion.body_part]
	var start: Vector3 = body.global_position
	var forward: Vector3 = _horizontal(body.global_basis.z)
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	_motion.set_move_input(command)
	if not await _step_frames(MOVE_FRAMES):
		return _interrupted_result(policy)
	_motion.set_move_input(Vector2.ZERO)
	if not await _step_frames(REST_FRAMES):
		return _interrupted_result(policy)
	var displacement: Vector3 = body.global_position - start
	var forward_m: float = displacement.dot(forward)
	var lateral_m: float = displacement.dot(right)
	var yaw_rad: float = forward.signed_angle_to(_horizontal(body.global_basis.z), Vector3.UP)
	if not is_finite(forward_m) or not is_finite(lateral_m) or not is_finite(yaw_rad):
		_finite = false
		return _interrupted_result(policy)
	var score: float = 100.0 * forward_m * command.y + 2.0 * yaw_rad * command.x
	score -= 30.0 * absf(lateral_m) + 2.0 * absf(yaw_rad) * (1.0 - absf(command.x))
	score -= 10.0 * (1.0 - clampf(_minimum_upright, 0.0, 1.0))
	if command.is_zero_approx():
		score -= 100.0 * Vector2(forward_m, lateral_m).length()
	if _fallen:
		score -= 100.0
	var result: Dictionary = {
		"policy": policy.duplicate(true), "command": [command.x, command.y],
		"forward_m": forward_m, "lateral_m": lateral_m, "yaw_rad": yaw_rad,
		"min_upright": _minimum_upright, "min_height_m": _minimum_height,
		"fallen": _fallen, "finite": _finite, "score": score,
		"simulation_seconds": 16.5, "physics_hz": PHYSICS_HZ, "engine_version": ENGINE_VERSION,
		"graph_fingerprint": MotionSnapshot.fingerprint(snapshot), "program_id": MotionPolicy.PROGRAM_ID,
	}
	_cleanup()
	return result


func _step_frames(count: int) -> bool:
	for frame: int in range(count):
		await get_tree().physics_frame
		if _cancelled:
			return false
		for part: RigidBody3D in _hardware.bodies:
			if not part.global_transform.is_finite() or not part.linear_velocity.is_finite() or not part.angular_velocity.is_finite():
				_finite = false
				_fallen = true
				return false
		var body: RigidBody3D = _hardware.bodies[_motion.body_part]
		var upright: float = body.global_basis.y.normalized().dot(Vector3.UP)
		var height: float = body.global_position.y - BipedPreset.FLOOR_TOP
		_minimum_upright = minf(_minimum_upright, upright)
		_minimum_height = minf(_minimum_height, height)
		_fallen = _fallen or upright < FALL_UPRIGHT or height < FALL_HEIGHT
	return true


func _interrupted_result(policy: Dictionary) -> Dictionary:
	var result: Dictionary
	if _cancelled:
		result = {"error": "Motion trial cancelled", "cancelled": true}
	else:
		result = {
			"error": "Non-finite physics state", "policy": policy.duplicate(true),
			"forward_m": 0.0, "lateral_m": 0.0, "yaw_rad": 0.0,
			"min_upright": _minimum_upright,
			"min_height_m": _minimum_height if is_finite(_minimum_height) else 0.0,
			"fallen": true, "finite": false, "score": -1000.0,
		}
	_cleanup()
	return result


func _add_floor() -> void:
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4.0, 0.1, 4.0)
	collision.shape = box
	floor.add_child(collision)
	floor.position.y = BipedPreset.FLOOR_TOP - box.size.y * 0.5
	_viewport.add_child(floor)


func _cleanup() -> void:
	if is_instance_valid(_motion):
		_motion.set_enabled(false)
	if is_instance_valid(_viewport):
		remove_child(_viewport)
		_viewport.queue_free()
	_viewport = null
	_hardware = null
	_motion = null
	_busy = false


func _exit_tree() -> void:
	cancel()


static func _horizontal(direction: Vector3) -> Vector3:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	return flat.normalized() if flat.length_squared() > 0.000001 else Vector3.BACK


static func _engine_version_error(version: Dictionary) -> String:
	if version.get("major", -1) != 4 or version.get("minor", -1) != 7 or version.get("patch", -1) != 2:
		return "Motion trials require Godot " + ENGINE_VERSION + "; this engine version is not supported"
	return ""
