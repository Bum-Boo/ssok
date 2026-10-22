class_name StageLevel
extends Node3D

## Root of a stage environment scene. The ground keeps the workshop floor height so graph
## presets stay valid; props and markers never become part of the learner's ConnectionGraph.

@export var play_area: AABB = AABB(Vector3(-0.25, 0.0, -0.2), Vector3(0.5, 0.3, 0.4))
@export var floor_top: float = 0.05
## Starting camera direction; yaw 0 looks from +Z toward -Z.
@export var view_yaw_degrees: float = 30.0
@export var view_pitch_degrees: float = 25.0


## Physical environment props stay outside the editable learner graph.
func install_wall(x: float) -> void:
	var wall := StaticBody3D.new()
	wall.name = "stage_wall"
	wall.collision_layer = 3
	var definition: PartDef = load("res://assets/parts/stage_wall.tres")
	var mesh := MeshInstance3D.new()
	mesh.mesh = definition.mesh
	wall.add_child(mesh)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = definition.mesh.get_aabb().size
	collision.shape = box
	collision.position = definition.mesh.get_aabb().get_center()
	wall.add_child(collision)
	add_child(wall)
	wall.position = Vector3(x, 0.15, 0)


func wall_bounds() -> Array[AABB]:
	var walls: Array[AABB] = []
	for child: Node in get_children():
		if child is StaticBody3D and child.name.begins_with("stage_wall"):
			var mesh: MeshInstance3D = child.get_child(0)
			walls.append(mesh.global_transform * mesh.mesh.get_aabb())
	return walls
