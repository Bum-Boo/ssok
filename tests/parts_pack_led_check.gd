extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph := ConnectionGraph.new()
	graph.parts.append({"part_def": load("res://assets/parts/microbit.tres"), "transform": Transform3D.IDENTITY})
	for index: int in 2:
		graph.parts.append({"part_def": load("res://assets/construction_kit/parts/kit_led.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(index * 0.1, 0.1, 0))})
		graph.links.append({"a_part": 0, "a_port": StringName("pin_%d" % (index + 1)), "b_part": index + 1, "b_port": &"signal_pin"})
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var runtime := MiniRuntime.new()
	root.add_child(runtime)
	runtime.hardware = hardware
	var led: LEDDevice = hardware.device("LED", [1])
	var other: LEDDevice = hardware.device("LED", [2])
	_check(led != null and other != null and hardware.device("Button", [1]) == null, "LED resolves typed graph signal")
	_check(not led.material.emission_enabled and led.brightness == 0, "LED starts dark")
	await runtime.run("led = LED(pin1)\nled.on()")
	_check(runtime.state == "finished" and led.brightness == 1 and led.material.emission_enabled and led.material.emission.r > 0.9, "on changes actual emission material")
	_check(other.brightness == 0 and not other.material.emission_enabled and other.material != led.material, "instances do not mutate shared stock or each other")
	await runtime.run("led = LED(pin1)\nled.set(0.35)")
	_check(is_equal_approx(led.brightness, 0.35) and is_equal_approx(led.material.emission_energy_multiplier, 0.7), "normalized brightness changes emission energy")
	await runtime.run("led = LED(pin1)\nled.off()")
	_check(led.brightness == 0 and not led.material.emission_enabled, "off disables emission")
	for value: String in ["-0.1", "1.1", "True", "'bright'"]:
		await runtime.run("led = LED(pin1)\nled.set(%s)" % value)
		_check(runtime.state == "failed" and led.brightness == 0, "invalid brightness rejected: " + value)
	runtime.run("led = LED(pin1)\nled.on()\nsleep(1000)\nled.on()")
	runtime.stop()
	_check(led.brightness == 0 and not led.material.emission_enabled, "Stop turns LED off immediately")
	for tick: int in 70:
		await physics_frame
	_check(led.brightness == 0, "cancelled work cannot turn LED back on")
	await runtime.run("led = LED(pin1)\nled.on()\nstop()")
	_check(led.brightness == 0, "learner stop turns LED off")
	for profile_id: String in ["generic-servo", "microbit", "uno"]:
		var profile: BoardProfile = BoardProfile.for_id(profile_id)
		var source: String = "led = LED(%s)\nled.on()\nled.set(0.35)\nled.off()" % profile.format_pin(1)
		var parsed: Dictionary = ServoProgram.parse(source, profile)
		_check(not parsed.has("error") and parsed.instructions[0].op == "led" and parsed.instructions[2].op == "led_set", "LED editable cards " + profile_id)
		for item: Dictionary in parsed.instructions:
			item.erase("raw")
		_check(ServoProgram.generate(parsed.instructions, profile).get("source", "") == source, "LED edited code generation " + profile_id)
	print("LED brightness=%.1f emission_enabled=%s instance_isolation=true" % [led.brightness, led.material.emission_enabled])
	runtime.free()
	hardware.free()
	await process_frame
	print("parts_pack_led_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL " + label)
