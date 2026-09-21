extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var profile := BoardProfile.new()
	var source: String = "# Preserve comments and spacing\nfrom servo import Servo\narm = Servo(pin=9)\narm.write(90)\nsleep(0.05)\narm.write_relative(-20)\n"
	var decoded: Dictionary = ServoProgram.parse(source, profile)
	_check(not decoded.has("error"), "all runtime instructions have block representation")
	_check(ServoProgram.generate(decoded.instructions, profile).source == source, "untouched round-trip is lossless")
	_check(ServoProgram.parse("import os", profile).has("error"), "unsupported code cannot silently disappear")
	_check(ServoProgram.parse("arm.write(999)", profile).has("error"), "out-of-range blocks rejected")
	var restricted := BoardProfile.new()
	restricted.api = [BoardProfile.GENERIC_API[0], BoardProfile.GENERIC_API[1]]
	_check(ServoProgram.parse("sleep(1)", restricted).has("error"), "profile API determines available operations")
	var blocks: Array = [profile.defaults("servo"), profile.defaults("write"), profile.defaults("sleep"), profile.defaults("write_relative")]
	blocks[2].args.seconds = 0.05
	blocks[3].args.angle = -20
	var generated: Dictionary = ServoProgram.generate(blocks, profile)
	_check(not generated.has("error"), "profile defaults generate runnable code")
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_answer_pressed()
	_check(main.blocks.operation_picker.item_count == profile.api.size(), "block palette generated from board descriptor")
	main.code_edit.text = generated.source
	main._on_run_pressed()
	await create_timer(0.2).timeout
	_check(not main.runtime.is_running(), "generated program completes")
	var drive: ServoDrive = main.run_mode.servo_on_pin(9)
	_check(drive != null, "generated binding resolves real wiring")
	_check(drive.powered and is_equal_approx(drive.target_deg, -20.0), "generated relative-angle block powers actual servo target")
	await create_timer(0.8).timeout
	_check(is_equal_approx(drive.current_deg, -20.0) and is_equal_approx(drive.joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER), deg_to_rad(-20.0)), "generated command advances physical hinge to target")
	_check(main.runtime._servos.has("arm"), "actual runtime receives declared servo")
	main._ensure_assembly_mode()
	main.blocks.read_source(source)
	main.code_edit.text = "# newer learner code"
	main.blocks._apply()
	_check(main.code_edit.text == "# newer learner code", "stale blocks cannot overwrite new code")
	_check(main.blocks._source_at_load == source, "conflict remains until explicitly reread")
	main.blocks.read_source(main.code_edit.text)
	main.blocks.instructions.append(profile.defaults("servo"))
	main.blocks._apply()
	_check(main.code_edit.text.contains("arm = Servo(9)"), "fresh blocks update editor without running")
	_check(not main.mode_button.button_pressed, "applying blocks does not start physics")
	main.free()
	print("block_program_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + description)
