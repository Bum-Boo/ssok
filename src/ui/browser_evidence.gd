class_name BrowserEvidence
extends Node

## Opt-in observations of actual application physics; this node never drives the robot.
const WALK_FRAMES: int = 720
const STOP_FRAMES: int = 90

var snapshot: Dictionary = {"schema": 1, "ready": false}
var _app: Node
var _body_id: int = 0
var _settle_frames: int = 0
var _walking: bool = false
var _walk_frames: int = 0
var _stop_frames: int = -1
var _start: Vector3
var _initial: Basis
var _minimum_up: float = 1.0
var _minimum_height: float = INF
var _finite: bool = true
var _graph_before: String
var _runtime_before: String
var _publish_frame: int = 0
var _feet: Array[int] = []
var _foot_air_frames: Array[int] = []
var _foot_clearance: Array[float] = []
var _policy_version: int = 1
var _learner: AppController


func _ready() -> void:
	_app = get_parent()
	process_physics_priority = 100
	set_physics_process(OS.has_feature("web") and bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('ssok_verify') === '1'", true)))


func _physics_process(_delta: float) -> void:
	_observe()
	_publish_frame += 1
	if OS.has_feature("web") and _publish_frame % 6 == 0:
		JavaScriptBridge.eval("window.__ssokPhysics = " + JSON.stringify(snapshot) + ";", true)
		if _learner == null:
			_learner = AppController.new()
			_learner.app = _app
		var observation: Dictionary = {"result": _learner.invoke("get_result").data, "scene": _learner.invoke("get_scene").data}
		JavaScriptBridge.eval("window.__ssokLearning = " + JSON.stringify(observation) + ";", true)
		var preferences: Dictionary = {
			"values": Preferences.values, "locale": TranslationServer.get_locale(), "dark": SsokTheme.dark,
			"settings_open": _app.settings.visible, "source_hash": _app.code_edit.text.sha256_text(),
			"graph_hash": MotionSnapshot.fingerprint(_app._motion_snapshot()),
			"draft_hash": JSON.stringify(_app.blocks.instructions).sha256_text(),
			"code_font_size": _app.code_edit.get_theme_font_size("font_size"),
			"ui_font_size": _app._ui_root.theme.default_font_size,
			"program_panel_right": _app._side_panel.get_global_rect().end.x,
			"viewport_width": _app.get_viewport().get_visible_rect().size.x,
			"run_mode": _app.mode_button.button_pressed, "code_running": _app.runtime.is_running(),
		}
		JavaScriptBridge.eval("window.__ssokInterface = " + JSON.stringify(preferences) + ";", true)


func _observe() -> void:
	var hardware: RunMode = _app.get("run_mode") as RunMode
	var motion: LearnedBipedMotion = _app.get("motion_program") as LearnedBipedMotion
	var manual: ManualController = _app.get("manual_controller") as ManualController
	if hardware == null or not hardware.is_built() or motion == null or not motion.is_supported():
		snapshot["ready"] = false
		return
	var body: RigidBody3D = hardware.bodies[motion.body_part]
	var graph: ConnectionGraph = _app.get("assembly").graph
	if body.get_instance_id() != _body_id:
		_reset(body, hardware, motion, graph)
	var command: Vector2 = manual.get_move_input()
	var forward: bool = command.y > 0.9 and absf(command.x) < 0.01 and manual._held_keys.has(KEY_W)
	snapshot["ready"] = true
	snapshot["command"] = [command.x, command.y]
	snapshot["settle_frames"] = _settle_frames
	if not _walking and not snapshot.has("walk"):
		if forward:
			_walking = true
			_start = body.global_position
			_initial = body.global_basis.orthonormalized()
			_sample(body, hardware, graph, false)
			snapshot["started_at_physics_frame"] = Engine.get_physics_frames()
		else:
			_settle_frames += 1
	elif _walking:
		if not forward:
			_finish_walk(body, hardware, graph, "command_released_before_horizon")
		else:
			_walk_frames += 1
			_sample(body, hardware, graph, true)
			if _walk_frames == WALK_FRAMES:
				_finish_walk(body, hardware, graph, "")
	elif snapshot.has("walk") and not snapshot.has("stop"):
		if command.is_zero_approx():
			if _stop_frames < 0:
				_stop_frames = 0
			else:
				_stop_frames += 1
			if _stop_frames == STOP_FRAMES:
				snapshot["stop"] = {
					"frames": _stop_frames,
					"upright": body.global_basis.y.dot(Vector3.UP),
					"command": [command.x, command.y],
					"finite": body.global_transform.is_finite(),
					"graph_fingerprint": MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)),
					"runtime_fingerprint": LearnedBipedMotion.runtime_fingerprint(hardware, graph, _policy_version),
				}
		elif _stop_frames >= 0:
			_stop_frames = -1
	snapshot["walk_frames"] = _walk_frames


func _reset(body: RigidBody3D, hardware: RunMode, motion: LearnedBipedMotion, graph: ConnectionGraph) -> void:
	_body_id = body.get_instance_id()
	_policy_version = int(motion.policy.get("version", 1))
	_settle_frames = 0
	_walking = false
	_walk_frames = 0
	_stop_frames = -1
	_minimum_up = 1.0
	_minimum_height = INF
	_finite = true
	_feet.clear()
	_foot_air_frames.clear()
	_foot_clearance.clear()
	for index: int in graph.parts.size():
		var definition: PartDef = graph.parts[index].part_def
		for port: Port in definition.ports:
			if port.id == &"ankle_front":
				_feet.append(index)
				_foot_air_frames.append(0)
				_foot_clearance.append(0.0)
	_graph_before = MotionSnapshot.fingerprint(MotionSnapshot.encode(graph))
	_runtime_before = LearnedBipedMotion.runtime_fingerprint(hardware, graph, _policy_version)
	snapshot = {
		"schema": 1, "ready": true,
		"engine": Engine.get_version_info().string,
		"physics_hz": Engine.physics_ticks_per_second,
		"bundled_policy": motion is BundledBipedMotion,
		"graph_fingerprint": _graph_before,
		"runtime_fingerprint": _runtime_before,
		"policy_graph_fingerprint": motion.policy.get("graph_fingerprint", ""),
		"policy_runtime_fingerprint": motion.policy.get("runtime_fingerprint", ""),
		"policy_fingerprint": JSON.stringify(motion.policy, "", true, true).sha256_text(),
		"foot_part_indices": _feet.duplicate(),
	}


func _sample(body: RigidBody3D, hardware: RunMode, graph: ConnectionGraph, count_air: bool) -> void:
	_finite = _finite and body.global_transform.is_finite()
	for part: RigidBody3D in hardware.bodies:
		_finite = _finite and part.global_transform.is_finite() and part.linear_velocity.is_finite() and part.angular_velocity.is_finite()
	if not body.global_transform.is_finite():
		return
	_minimum_up = minf(_minimum_up, body.global_basis.y.dot(Vector3.UP))
	_minimum_height = minf(_minimum_height, body.global_position.y - BipedPreset.FLOOR_TOP)
	if not count_air:
		return
	for index: int in _feet.size():
		var definition: PartDef = graph.parts[_feet[index]].part_def
		var bounds: Array[AABB] = definition.collision_boxes.duplicate()
		if bounds.is_empty():
			bounds.append(definition.mesh.get_aabb())
		var transform: Transform3D = hardware.part_global_transform(_feet[index])
		var minimum_y: float = INF
		for box: AABB in bounds:
			for corner: int in 8:
				minimum_y = minf(minimum_y, (transform * box.get_endpoint(corner)).y)
		var clearance: float = minimum_y - BipedPreset.FLOOR_TOP
		_foot_clearance[index] = maxf(_foot_clearance[index], clearance)
		if clearance > 0.0005:
			_foot_air_frames[index] += 1


func _finish_walk(body: RigidBody3D, hardware: RunMode, graph: ConnectionGraph, failure: String) -> void:
	_walking = false
	var displacement: Vector3 = _initial.inverse() * (body.global_position - _start)
	var yaw: float = rad_to_deg(_initial.z.signed_angle_to(body.global_basis.z, Vector3.UP))
	snapshot["walk"] = {
		"frames": _walk_frames, "seconds": float(_walk_frames) / Engine.physics_ticks_per_second,
		"finite": _finite, "failure": failure,
		"forward": displacement.z if is_finite(displacement.z) else 0.0,
		"lateral": displacement.x if is_finite(displacement.x) else 0.0,
		"yaw_degrees": yaw if is_finite(yaw) else 0.0,
		"minimum_upright": _minimum_up,
		"minimum_height": _minimum_height if is_finite(_minimum_height) else 0.0,
		"foot_air_frames": _foot_air_frames.duplicate(),
		"maximum_foot_clearance_m": _foot_clearance.duplicate(),
		"graph_fingerprint": MotionSnapshot.fingerprint(MotionSnapshot.encode(graph)),
		"runtime_fingerprint": LearnedBipedMotion.runtime_fingerprint(hardware, graph, _policy_version),
	}


func _exit_tree() -> void:
	if OS.has_feature("web") and is_physics_processing():
		JavaScriptBridge.eval("delete window.__ssokPhysics;", true)
		JavaScriptBridge.eval("delete window.__ssokLearning;", true)
