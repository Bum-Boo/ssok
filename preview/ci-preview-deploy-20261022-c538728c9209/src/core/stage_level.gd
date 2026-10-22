class_name StageLevel
extends Node3D

## Root of a stage environment scene. The ground keeps the workshop floor height so graph
## presets stay valid; props and markers never become part of the learner's ConnectionGraph.

@export var play_area: AABB = AABB(Vector3(-0.25, 0.0, -0.2), Vector3(0.5, 0.3, 0.4))
@export var floor_top: float = 0.05
## Starting camera direction; yaw 0 looks from +Z toward -Z.
@export var view_yaw_degrees: float = 30.0
@export var view_pitch_degrees: float = 25.0
