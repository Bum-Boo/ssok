extends SceneTree

## Headless check for #4/#7: arm falls under gravity unpowered, then follows Servo(9).write().

var _run_mode: RunMode
var _failures: Array[String] = []


func _init() -> void:
	_run_mode = RunMode.new()
	root.add_child.call_deferred(_run_mode)
	_run_after(2, _setup)


func _setup() -> void:
	var graph := ServoArmPreset.build()
	_run_mode.build(graph)
	_check(_run_mode.bodies.size() == 4, "4 bodies, got %d" % _run_mode.bodies.size())
	_check(_run_mode.servos.size() == 1, "1 servo drive, got %d" % _run_mode.servos.size())
	_check(_run_mode.servo_on_pin(9) != null, "pin 9 resolves to the servo")
	_check(_run_mode.servo_on_pin(10) == null, "pin 10 is empty")
	_check(_run_mode.get_child_count() == 4 + 2 + 1, "bodies + joints + drive, got %d" % _run_mode.get_child_count())
	# The assembled pose is exactly upright (unstable equilibrium); nudge it so gravity has a side to pick.
	_run_mode.bodies[2].apply_impulse(Vector3(0, 0, 1e-5), Vector3(0, 0.04, 0))
	_run_after(60, _after_gravity)


func _after_gravity() -> void:
	var arm := _run_mode.bodies[2]
	var tip: Vector3 = arm.global_transform * Vector3(0, 0.04, 0)
	_check(tip.y < 0.13, "unpowered arm swung down under gravity (tip y=%.3f)" % tip.y)
	var drive := _run_mode.servo_on_pin(9)
	drive.speed_deg_per_s = 100000.0
	drive.write(90)
	_run_after(60, _after_write)


func _after_write() -> void:
	var arm := _run_mode.bodies[2]
	var servo := _run_mode.bodies[1]
	var arm_dir: Vector3 = arm.global_transform.basis.y
	var angle := rad_to_deg(Vector3.UP.angle_to(arm_dir))
	_check(absf(angle - 90.0) < 15.0, "arm at ~90 deg from up after write(90), got %.1f" % angle)
	_check(absf(servo.global_position.y - 0.085) < 0.005, "servo stayed mounted (y=%.3f)" % servo.global_position.y)
	_run_mode.teardown()
	_run_mode.build(ServoArmPreset.build())
	_run_mode.teardown()
	_check(_run_mode.get_child_count() == 0, "teardown leaves no nodes")
	_finish()


var _frames_left := 0
var _next: Callable


func _run_after(frames: int, callback: Callable) -> void:
	_frames_left = frames
	_next = callback
	if not physics_frame.is_connected(_on_physics_frame):
		physics_frame.connect(_on_physics_frame)


func _on_physics_frame() -> void:
	_frames_left -= 1
	if _frames_left <= 0 and _next.is_valid():
		var callback := _next
		_next = Callable()
		callback.call()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures.append(what)


func _finish() -> void:
	print("run_mode_check: %d failure(s)" % _failures.size())
	quit(1 if _failures.size() > 0 else 0)
