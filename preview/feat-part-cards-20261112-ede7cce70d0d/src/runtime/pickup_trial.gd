class_name PickupTrial
extends Node

## One observable, bounded pickup episode in an isolated physics world.

signal progress_changed(metrics: Dictionary)
signal completed(result: Dictionary)

const PHYSICS_HZ: int = 60
const MAX_FRAMES: int = 900
const SETTLE_FRAMES: int = 180
const REQUIRED_LIFT: float = 0.25
const REQUIRED_HOLD: float = 1.0
const REQUIRED_UPRIGHT: float = 0.8

var viewport: SubViewport
var is_running: bool = false
var metrics: Dictionary = {}
var _hardware: RunMode
var _motion: HumanoidMotion
var _policy: Dictionary = {}
var _graph: ConnectionGraph
var _frames: int = 0
var _initial_box_height: float = 0.0
var _contact_confirmed: bool = false
var _requested: bool = false
var _hold_frames: int = 0


func start_trial(graph: ConnectionGraph, policy: Dictionary, visible: bool = true) -> String:
	if is_running:
		return "A pickup trial is already running"
	if not is_inside_tree():
		return "Pickup trial must be attached to the scene tree"
	var version_error: String = MotionTrial._engine_version_error(Engine.get_version_info())
	if not version_error.is_empty():
		return version_error
	if Engine.physics_ticks_per_second != PHYSICS_HZ or not is_equal_approx(Engine.time_scale, 1.0):
		return "Motion trials require 60 Hz physics and time_scale 1"
	var validation: String = PickupPolicy.validate(policy)
	if not validation.is_empty():
		return validation
	var snapshot: Dictionary = MotionSnapshot.encode(graph)
	var isolated_graph: ConnectionGraph = MotionSnapshot.decode(snapshot)
	if isolated_graph == null:
		return "Assembly cannot be encoded as a safe catalog graph"
	var boxes: int = 0
	for entry: Dictionary in isolated_graph.parts:
		boxes += int(entry.part_def.id == &"cargo_box")
	if boxes != 1:
		return "Pickup trial needs a wired humanoid and one reachable box"
	_dispose_world()
	_graph = isolated_graph
	_policy = policy.duplicate(true)
	_frames = 0
	_hold_frames = 0
	_contact_confirmed = false
	_requested = false
	metrics = {
		"finite": true, "fallen": false, "success": false,
		"lift_m": 0.0, "max_lift_m": 0.0, "hold_seconds": 0.0,
		"min_upright": 1.0, "upright": 1.0, "score": 0.0,
		"simulation_seconds": 0.0,
		"graph_fingerprint": MotionSnapshot.fingerprint(snapshot),
		"engine_version": MotionTrial.ENGINE_VERSION, "physics_hz": PHYSICS_HZ,
		"phase": "settling", "contact_before_grasp": false,
		"grasped": false, "left_contact": false, "right_contact": false,
		"cancelled": false,
	}
	viewport = SubViewport.new()
	viewport.name = "IsolatedPickupWorld"
	viewport.own_world_3d = true
	viewport.size = Vector2i(480, 360) if visible else Vector2i(2, 2)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	add_child(viewport)
	_add_floor(visible)
	if visible:
		_add_view()
	_hardware = RunMode.new()
	viewport.add_child(_hardware)
	_hardware.build(_graph)
	PhysicsServer3D.space_set_active(viewport.find_world_3d().space, true)
	_motion = KitHumanoidMotion.new() if KitHumanoidMotion.recognizes(_graph) else HumanoidMotion.new()
	viewport.add_child(_motion)
	if not _motion.configure(_hardware, _graph) or _motion._box_part < 0:
		_dispose_world()
		return "Pickup trial needs a wired humanoid and one reachable box"
	_initial_box_height = _hardware.bodies[_motion._box_part].global_position.y
	_motion.pickup_contact_confirmed.connect(_on_contact_confirmed)
	PickupPolicy.apply(_motion, _policy)
	_motion.set_enabled(true)
	is_running = true
	set_physics_process(true)
	progress_changed.emit(metrics.duplicate(true))
	return ""


func cancel() -> void:
	var notify_completion: bool = is_running
	is_running = false
	set_physics_process(false)
	if not metrics.is_empty():
		metrics.phase = "cancelled"
		metrics.cancelled = true
		metrics.success = false
	_dispose_world()
	if notify_completion:
		progress_changed.emit(metrics.duplicate(true))
		completed.emit({"policy": _policy.duplicate(true), "metrics": metrics.duplicate(true)})


func _physics_process(_delta: float) -> void:
	if not is_running:
		return
	_frames += 1
	metrics.simulation_seconds = float(_frames) / PHYSICS_HZ
	_observe()
	if not metrics.finite or metrics.fallen:
		_finish(false)
		return
	if _frames >= SETTLE_FRAMES and not _requested:
		_requested = true
		_initial_box_height = _hardware.bodies[_motion._box_part].global_position.y
		if not _motion.request_pickup():
			_finish(false)
			return
	if _requested:
		metrics.phase = _motion.pickup_state
		if _motion.pickup_state == "idle":
			_finish(false)
			return
		var stable_hold: bool = _motion.pickup_state == "holding" and _motion.grasped and _contact_confirmed and float(metrics.lift_m) >= REQUIRED_LIFT and float(metrics.upright) >= REQUIRED_UPRIGHT
		_hold_frames = _hold_frames + 1 if stable_hold else 0
		metrics.hold_seconds = float(_hold_frames) / PHYSICS_HZ
		if _hold_frames >= PHYSICS_HZ:
			_finish(true)
			return
	if _frames >= MAX_FRAMES:
		_finish(false)
		return
	if _frames % 12 == 0:
		_update_score()
		progress_changed.emit(metrics.duplicate(true))


func _observe() -> void:
	for body: RigidBody3D in _hardware.bodies:
		if not body.global_transform.is_finite() or not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite():
			metrics.finite = false
			metrics.fallen = true
			return
	var torso: RigidBody3D = _hardware.bodies[_motion.body_part]
	var box: RigidBody3D = _hardware.bodies[_motion._box_part]
	var upright: float = clampf(torso.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)
	metrics.upright = upright
	metrics.min_upright = minf(float(metrics.min_upright), upright)
	metrics.fallen = _motion.fallen or upright < 0.45 or torso.global_position.y < HumanoidPreset.FLOOR_TOP + 0.30
	metrics.lift_m = clampf(box.global_position.y - _initial_box_height, -200.0, 200.0)
	metrics.max_lift_m = maxf(float(metrics.max_lift_m), float(metrics.lift_m))
	metrics.grasped = _motion.grasped
	for side: String in ["left", "right"]:
		var hand: RigidBody3D = _hardware.bodies[_motion.role_parts[side + "_elbow"]]
		metrics[side + "_contact"] = box in hand.get_colliding_bodies()


func _on_contact_confirmed() -> void:
	if not is_running or not is_instance_valid(_motion) or _motion.grasped:
		return
	var box: RigidBody3D = _hardware.bodies[_motion._box_part]
	for side: String in ["left", "right"]:
		var hand: RigidBody3D = _hardware.bodies[_motion.role_parts[side + "_elbow"]]
		if box not in hand.get_colliding_bodies():
			return
	_contact_confirmed = true
	metrics.contact_before_grasp = true


func _finish(success: bool) -> void:
	is_running = false
	set_physics_process(false)
	metrics.success = success
	metrics.phase = "succeeded" if success else "failed"
	_update_score()
	_pause_episode()
	progress_changed.emit(metrics.duplicate(true))
	completed.emit({"policy": _policy.duplicate(true), "metrics": metrics.duplicate(true)})


func _pause_episode() -> void:
	# End the evaluated episode, preserving its last physical state rather than changing bodies.
	PhysicsServer3D.space_set_active(viewport.find_world_3d().space, false)
	_motion.set_physics_process(false)
	for drive: ServoDrive in _hardware.servos.values():
		drive.set_physics_process(false)
	if viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _update_score() -> void:
	var score: float = 100.0 * clampf(float(metrics.lift_m), 0.0, 0.6)
	score += 10.0 * float(metrics.hold_seconds)
	score += 20.0 if metrics.contact_before_grasp else 0.0
	score += 100.0 if metrics.success else 0.0
	# A purposeful crouch is not a balance failure.
	score -= 50.0 * maxf(0.0, REQUIRED_UPRIGHT - float(metrics.min_upright))
	score -= 100.0 if metrics.fallen else 0.0
	metrics.score = score if metrics.finite else -1000.0


func _add_floor(visible: bool) -> void:
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4.0, 0.1, 4.0)
	collision.shape = shape
	floor.add_child(collision)
	floor.position.y = HumanoidPreset.FLOOR_TOP - shape.size.y * 0.5
	if visible:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = shape.size
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color("263548")
		material.roughness = 0.85
		box.material = material
		mesh.mesh = box
		floor.add_child(mesh)
	viewport.add_child(floor)


func _add_view() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("131d2d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cbd8ef")
	environment.ambient_light_energy = 0.6
	world.environment = environment
	viewport.add_child(world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	viewport.add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(1.35, 1.05, 1.65)
	camera.fov = 45.0
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.47, 0.08))
	camera.current = true


func _dispose_world() -> void:
	if is_instance_valid(_motion):
		_motion.set_enabled(false)
	if is_instance_valid(_hardware):
		_hardware.teardown()
	if is_instance_valid(viewport):
		if viewport.get_parent() == self:
			remove_child(viewport)
		viewport.queue_free()
	viewport = null
	_hardware = null
	_motion = null
	_graph = null


func _exit_tree() -> void:
	is_running = false
	if is_instance_valid(_motion):
		_motion.set_enabled(false)
