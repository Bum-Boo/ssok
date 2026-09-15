class_name BipedMotion
extends RobotMotionProgram

## A support-transfer gait example; only the graph's wired servo channels are actuated.

const ROLES: Array[StringName] = [&"left_hip", &"right_hip", &"left_ankle", &"right_ankle"]

@export var cycle_seconds: float = 2.4
@export var stride_degrees: float = 16.0
@export var lean_degrees: float = 20.0
@export var posture_degrees: float = 4.0

var role_pins: Dictionary = {}
var body_part: int = -1
var _elapsed: float = 0.0


func get_policy() -> Dictionary:
	return MotionPolicy.read(self)


func apply_policy(policy: Dictionary) -> bool:
	return MotionPolicy.apply(self, policy)


func configure(hardware: RunMode, graph: ConnectionGraph) -> bool:
	super.configure(hardware, graph)
	role_pins.clear()
	body_part = -1
	_elapsed = 0.0
	if hardware == null or not hardware.is_built() or graph == null:
		_set_status("Build a wired biped before using the movement program")
		return false
	for index: int in range(graph.parts.size()):
		var definition: PartDef = graph.parts[index].part_def
		if _has_port(definition, &"hip_left") and _has_port(definition, &"hip_right"):
			if body_part >= 0:
				_set_status("Movement program needs one unambiguous biped body")
				return false
			body_part = index
	if body_part < 0:
		_set_status("No biped motion program: connect a two-leg body with four servos")
		return false
	var role_parts: Dictionary = {}
	for side: String in ["left", "right"]:
		var hip: int = _neighbor(body_part, StringName("hip_" + side), &"mount_bottom")
		var leg: int = _neighbor(hip, &"output_shaft", &"hip_mount")
		var ankle: int = _neighbor(leg, &"ankle_mount", &"mount_bottom")
		var foot: int = _neighbor(ankle, &"output_shaft")
		if hip < 0 or leg < 0 or ankle < 0 or foot < 0:
			_set_status("Incomplete %s leg: connect hip, leg, ankle servo and foot" % side)
			return false
		role_parts[StringName(side + "_hip")] = hip
		role_parts[StringName(side + "_ankle")] = ankle
	var unique_parts: Dictionary = {}
	for part: int in role_parts.values():
		unique_parts[part] = true
	if unique_parts.size() != ROLES.size():
		_set_status("Each hip and ankle needs its own servo")
		return false
	var channels: Array[Dictionary] = hardware.wired_servo_channels()
	for role: StringName in ROLES:
		var pins: Array[int] = []
		for channel: Dictionary in channels:
			if channel.part == role_parts[role]:
				pins.append(channel.pin)
		if pins.size() != 1:
			_set_status("Wire %s to one unambiguous board PWM pin" % String(role).replace("_", " "))
			role_pins.clear()
			return false
		role_pins[role] = pins[0]
	_supported = true
	_set_status("Experimental biped joint program: forward/back and turn")
	return true


func set_enabled(enabled: bool) -> void:
	super.set_enabled(enabled)
	_elapsed = 0.0
	if _enabled:
		_write_pose(Vector4.ZERO)


func _physics_process(delta: float) -> void:
	if not _enabled or _hardware == null or not _hardware.is_built():
		return
	if _move_input.length() < 0.05:
		_elapsed = 0.0
		_write_pose(Vector4.ZERO)
		return
	_elapsed += delta * maxf(_move_input.length(), 0.25)
	var phase: float = TAU * _elapsed / maxf(cycle_seconds, 0.5)
	var strength: float = clampf(_elapsed / 0.6, 0.0, 1.0)
	var left_stride: float = clampf(_move_input.y - _move_input.x, -1.0, 1.0)
	var right_stride: float = clampf(_move_input.y + _move_input.x, -1.0, 1.0)
	var posture: float = posture_degrees * _move_input.y * strength
	var left_hip: float = stride_degrees * sin(phase) * left_stride * strength - posture
	var right_hip: float = stride_degrees * sin(phase) * right_stride * strength + posture
	var lean: float = lean_degrees * cos(phase) * strength
	_write_pose(Vector4(left_hip, right_hip, lean, -lean))


func _write_pose(pose: Vector4) -> void:
	for index: int in range(ROLES.size()):
		var role: StringName = ROLES[index]
		if not role_pins.has(role):
			continue
		var servo: ServoDrive = _hardware.servo_on_pin(role_pins[role])
		if servo != null:
			servo.write_relative(pose[index])


func _neighbor(part: int, port: StringName, expected_port: StringName = &"") -> int:
	if part < 0:
		return -1
	var found: int = -1
	for link: Dictionary in _graph.links:
		for side: String in ["a", "b"]:
			if link[side + "_part"] != part or link[side + "_port"] != port:
				continue
			var other: String = "b" if side == "a" else "a"
			if expected_port != &"" and link[other + "_port"] != expected_port:
				return -1
			if found >= 0:
				return -1
			found = link[other + "_part"]
	return found


func _has_port(definition: PartDef, id: StringName) -> bool:
	for port: Port in definition.ports:
		if port.id == id and port.kind == Port.Kind.MECH:
			return true
	return false
