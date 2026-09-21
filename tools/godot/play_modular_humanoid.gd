extends SceneTree

## Opens the normal application in edit mode with its modular starter selected.


func _initialize() -> void:
	_open.call_deferred()


func _open() -> void:
	root.size = Vector2i(1400, 950)
	root.title = "ssok"
	var main: Node3D = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	main.modular_button.pressed.emit()
