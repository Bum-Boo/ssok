class_name TransformGizmo
extends Node3D

## Click-and-drag handles for precise part manipulation in assembly mode:
## an arrow per world axis to translate along it, a ring per world axis to
## rotate around it. Colors follow the X=red / Y=green / Z=blue convention.
## Handles carry `gizmo_axis` (Vector3) and `gizmo_kind` (&"translate" /
## &"rotate") metadata so AssemblyMode can read them off a raycast hit.

const AXES: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
const AXIS_COLORS: Array[Color] = [Color(0.85, 0.2, 0.2), Color(0.2, 0.75, 0.2), Color(0.2, 0.45, 0.9)]

const ARROW_LENGTH := 0.045
const ARROW_RADIUS := 0.0025
const ARROW_HEAD_RADIUS := 0.006
const ARROW_HEAD_LENGTH := 0.012
const RING_RADIUS := 0.032
const RING_THICKNESS := 0.0015
const PICK_RADIUS := 0.01

var _handles: Array[StaticBody3D] = []


func _ready() -> void:
	for i in range(AXES.size()):
		_handles.append(_build_translate_handle(AXES[i], AXIS_COLORS[i]))
		_handles.append(_build_rotate_handle(AXES[i], AXIS_COLORS[i]))
	for handle in _handles:
		add_child(handle)
	set_enabled(false)


## Hides the gizmo and disables its colliders so a hidden gizmo sitting at a
## stale position never steals a raycast meant for a part or the floor.
func set_enabled(enabled: bool) -> void:
	visible = enabled
	for handle in _handles:
		handle.collision_layer = 1 if enabled else 0


func _axis_basis(axis: Vector3) -> Basis:
	return Basis(Quaternion(Vector3.UP, axis))


func _unshaded_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _build_translate_handle(axis: Vector3, color: Color) -> StaticBody3D:
	var handle := StaticBody3D.new()
	handle.set_meta(&"gizmo_axis", axis)
	handle.set_meta(&"gizmo_kind", &"translate")

	var basis := _axis_basis(axis)
	var material := _unshaded_material(color)

	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = ARROW_RADIUS
	shaft_mesh.bottom_radius = ARROW_RADIUS
	shaft_mesh.height = ARROW_LENGTH
	shaft.mesh = shaft_mesh
	shaft.material_override = material
	shaft.transform = Transform3D(basis, axis * ARROW_LENGTH * 0.5)
	handle.add_child(shaft)

	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = ARROW_HEAD_RADIUS
	head_mesh.height = ARROW_HEAD_LENGTH
	head.mesh = head_mesh
	head.material_override = material
	head.transform = Transform3D(basis, axis * (ARROW_LENGTH + ARROW_HEAD_LENGTH * 0.5))
	handle.add_child(head)

	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = PICK_RADIUS
	shape.height = ARROW_LENGTH + ARROW_HEAD_LENGTH
	collider.shape = shape
	collider.transform = Transform3D(basis, axis * (ARROW_LENGTH + ARROW_HEAD_LENGTH) * 0.5)
	handle.add_child(collider)

	return handle


func _build_rotate_handle(axis: Vector3, color: Color) -> StaticBody3D:
	var handle := StaticBody3D.new()
	handle.set_meta(&"gizmo_axis", axis)
	handle.set_meta(&"gizmo_kind", &"rotate")

	var basis := _axis_basis(axis)
	var material := _unshaded_material(color)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - RING_THICKNESS
	torus.outer_radius = RING_RADIUS + RING_THICKNESS
	ring.mesh = torus
	ring.material_override = material
	ring.transform = Transform3D(basis, Vector3.ZERO)
	handle.add_child(ring)

	## A thin disk over the ring's footprint; precise enough to grab without
	## modelling the exact annulus.
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = RING_RADIUS + PICK_RADIUS
	shape.height = PICK_RADIUS
	collider.shape = shape
	collider.transform = Transform3D(basis, Vector3.ZERO)
	handle.add_child(collider)

	return handle
