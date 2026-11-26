class_name ContactButton
extends Node

var run_mode: RunMode
var part_index: int = -1
var pressed: bool = false
var held_seconds: float = 0.0
var _release_seconds: float = 0.05


func is_pressed() -> bool:
	return pressed


func _physics_process(delta: float) -> void:
	# Three physics frames of release debounce reject solver contact chatter.
	_release_seconds = 0.0 if _front_contact() else _release_seconds + delta
	pressed = _release_seconds < 0.05
	held_seconds = held_seconds + delta if pressed else 0.0


func _front_contact() -> bool:
	if not is_instance_valid(run_mode) or not run_mode.is_built():
		return false
	var body: RigidBody3D = run_mode.bodies[part_index]
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state == null:
		return false
	var front_shapes: Array[int] = []
	for owner: int in body.get_shape_owners():
		var shape: Node = body.shape_owner_get_owner(owner)
		if shape.get_meta("button_surface", -1) == part_index:
			front_shapes.append(body.shape_owner_get_shape_index(owner, 0))
	for index: int in state.get_contact_count():
		if state.get_contact_local_shape(index) in front_shapes:
			return true
	return false
