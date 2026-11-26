extends SceneTree

const HardwareBaker = preload("res://tools/godot/make_hardware_meshes.gd")


func _initialize() -> void:
	quit(0 if HardwareBaker.bake("flag") == OK else 1)
