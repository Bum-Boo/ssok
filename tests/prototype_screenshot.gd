extends SceneTree

## Drives the prototype end to end with a window and saves screenshots to user://.
## Run without --headless:  godot --path . -s tests/prototype_screenshot.gd

var _main: Node
var _step := 0
var _frames := 0


func _init() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child.call_deferred(_main)
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	match _step:
		0:
			if _frames > 10:
				_shot("assembly")
				_main.mode_button.button_pressed = true
				_step = 1
				_frames = 0
		1:
			if _frames > 90:
				_shot("run_unpowered")
				_main.code_edit.text = "from servo import Servo\narm = Servo(9)\narm.write(90)\n"
				_main.run_button.pressed.emit()
				_step = 2
				_frames = 0
		2:
			if _frames > 90:
				_shot("run_write_90")
				_main.code_edit.text = "arm = Servo(10)\narm.write(90)\n"
				_main.run_button.pressed.emit()
				_step = 3
				_frames = 0
		3:
			if _frames > 10:
				print("status after wrong pin: ", _main.status.text)
				_shot("wrong_pin")
				quit(0)


func _shot(name: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "user://shot_%s.png" % name
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), " status=", _main.status.text)
