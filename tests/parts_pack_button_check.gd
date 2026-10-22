extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.02, 4)
	collider.shape = box
	floor.add_child(collider)
	root.add_child(floor)
	floor.position.y = -0.01
	var graph: ConnectionGraph = RobotCarPreset.build(0.35)
	graph.links = graph.links.filter(func(link: Dictionary) -> bool: return link.a_part != 8 and link.b_part != 8)
	graph.parts[8].part_def = load("res://assets/construction_kit/parts/kit_contact_button.tres")
	RobotCarPreset._place(graph, 0, &"sensor_mount", 8, &"mount", Basis(Vector3.UP, PI / 2))
	RobotCarPreset._link(graph, 5, &"pin_1", 8, &"signal_pin")
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var runtime := MiniRuntime.new()
	root.add_child(runtime)
	runtime.hardware = hardware
	var button: ContactButton = hardware.device("Button", [1])
	_check(button != null and hardware.device("LineSensor", [1]) == null and hardware.device("Button", [2]) == null, "typed graph wiring")
	for tick: int in 60:
		await physics_frame
	_check(not button.is_pressed() and hardware.bodies[0] == hardware.bodies[8], "merged chassis ground contacts do not press button")
	runtime.run("left = Motor(pin0, pin8)\nright = Motor(pin12, pin16)\nbutton = Button(pin1)\nwhile not button.is_pressed():\n    left.forward(25)\n    right.forward(25)\n    sleep(20)\nstop()")
	for tick: int in 300:
		await physics_frame
		if not runtime.is_running():
			break
	_check(runtime.state == "finished" and button.is_pressed(), "physical wall contact changes VM condition and stops motors")
	# Maintain gentle forward force while the actual switch remains against the wall.
	hardware.motor_on_pin(0).forward(20)
	hardware.motor_on_pin(12).forward(20)
	for tick: int in 120:
		await physics_frame
	print("BUTTON contact=%s held_seconds=%.4f x=%.4f" % [button.is_pressed(), button.held_seconds, hardware.part_global_transform(0).origin.x])
	_check(button.is_pressed() and button.held_seconds > 1.0, "contact duration accumulates during continuous press")
	await runtime.run("left = Motor(pin0, pin8)\nright = Motor(pin12, pin16)\nleft.backward(25)\nright.backward(25)\nsleep(1500)\nstop()")
	await physics_frame
	_check(not button.is_pressed() and button.held_seconds == 0, "separating from wall releases and resets duration")
	for id: String in ["generic-servo", "uno", "microbit"]:
		var profile: BoardProfile = BoardProfile.for_id(id)
		var source: String = "button = Button(%s)\npressed = button.is_pressed()" % profile.format_pin(1)
		var blocks: Dictionary = ServoProgram.parse(source, profile)
		_check(not blocks.has("error") and blocks.instructions[0].op == "button" and blocks.instructions[1].op == "button_pressed", "editable button cards " + id)
		for item: Dictionary in blocks.instructions:
			item.erase("raw")
		_check(ServoProgram.generate(blocks.instructions, profile).get("source") == source, "button card generation " + id)
	runtime.free()
	hardware.free()
	floor.free()
	await process_frame
	print("parts_pack_button_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
