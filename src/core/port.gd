class_name Port
extends Resource

enum Kind { MECH, ELEC }

@export var id: StringName
@export var kind: Kind = Kind.MECH
@export var local_position: Vector3 = Vector3.ZERO
@export var local_normal: Vector3 = Vector3.UP
@export var tag: StringName
@export var accepts: Array[StringName] = []
