class_name BipedPreset
extends RefCounted

## Otto-DIY-style biped: body + 2 hip servos (pitch) + 2 legs + 2 ankle servos (roll) + 2 feet,
## an HC-SR04 as eyes, all four servos on Uno PWM pins. Standing pose is hinge angle 0, so the
## answer code only moves each joint into positive angles and back. Like Otto, a step is
## "roll onto one foot, swing the other leg, put it down".

const FLOOR_TOP := ServoArmPreset.FLOOR_TOP

const PIN_RIGHT_HIP := 3
const PIN_LEFT_HIP := 5
const PIN_RIGHT_FOOT := 6
const PIN_LEFT_FOOT := 9

const ANSWER_CODE := """from servo import Servo

left_hip = Servo(5)
right_hip = Servo(3)
left_foot = Servo(9)
right_foot = Servo(6)

left_hip.write(0)
right_hip.write(0)
left_foot.write(0)
right_foot.write(0)
sleep(0.5)

# lean onto the right foot, swing the left leg, put it down
right_foot.write(30)
sleep(0.4)
left_hip.write(20)
sleep(0.4)
left_hip.write(0)
sleep(0.3)
right_foot.write(0)
sleep(0.5)

# lean onto the left foot, swing the right leg, put it down
left_foot.write(30)
sleep(0.4)
right_hip.write(20)
sleep(0.4)
right_hip.write(0)
sleep(0.3)
left_foot.write(0)
sleep(0.5)
"""

# Servo placeholder geometry: shaft at local (+0.0115, +0.005, 0), mount at (0, -0.015, 0).
const SERVO_SHAFT := Vector3(0.0115, 0.005, 0)
const SERVO_MOUNT_UP := Vector3(0, 0.015, 0)
const LEG_HIP_MOUNT := Vector3(0.006, 0.014, 0)
const LEG_ANKLE_MOUNT := Vector3(0, -0.02, 0)
const FOOT_ANKLE_Y := 0.024
const FOOT_TAB_Z := 0.0115
const FOOT_SOLE := 0.005
const BODY_HIP_X := 0.02
const BODY_HIP_Y := -0.03
const BODY_FACE := Vector3(0, 0.01, 0.0225)


static func build() -> ConnectionGraph:
	var body_def: PartDef = load("res://assets/parts/biped_body.tres")
	var servo_def: PartDef = load("res://assets/parts/servo.tres")
	var leg_def: PartDef = load("res://assets/parts/leg_link.tres")
	var foot_def: PartDef = load("res://assets/parts/foot.tres")
	var sensor_def: PartDef = load("res://assets/parts/hc_sr04.tres")
	var uno_def: PartDef = load("res://assets/parts/arduino_uno.tres")

	var graph := ConnectionGraph.new()
	var body_position := Vector3(0, _body_height(), 0)
	graph.parts.append({"part_def": body_def, "transform": Transform3D(Basis.IDENTITY, body_position)})
	_add_leg(graph, servo_def, leg_def, foot_def, body_position, -1.0)
	_add_leg(graph, servo_def, leg_def, foot_def, body_position, 1.0)
	graph.parts.append({"part_def": sensor_def, "transform": Transform3D(Basis.IDENTITY, body_position + BODY_FACE + Vector3(0, 0, 0.0008))})
	graph.parts.append({"part_def": uno_def, "transform": Transform3D(Basis.IDENTITY, Vector3(0, FLOOR_TOP + 0.0008, -0.12))})

	var sensor := 9
	var uno := 10
	graph.links.append({"a_part": 0, "a_port": &"face", "b_part": sensor, "b_port": &"mount"})
	graph.links.append({"a_part": 1, "a_port": &"signal_pin", "b_part": uno, "b_port": StringName("pin_%d" % PIN_LEFT_HIP)})
	graph.links.append({"a_part": 3, "a_port": &"signal_pin", "b_part": uno, "b_port": StringName("pin_%d" % PIN_LEFT_FOOT)})
	graph.links.append({"a_part": 5, "a_port": &"signal_pin", "b_part": uno, "b_port": StringName("pin_%d" % PIN_RIGHT_HIP)})
	graph.links.append({"a_part": 7, "a_port": &"signal_pin", "b_part": uno, "b_port": StringName("pin_%d" % PIN_RIGHT_FOOT)})
	return graph


## Body centre height that puts the soles exactly on the floor.
static func _body_height() -> float:
	var foot_y := FLOOR_TOP + FOOT_SOLE
	var ankle_shaft_y := foot_y + FOOT_ANKLE_Y
	var ankle_servo_y := ankle_shaft_y + SERVO_SHAFT.y
	var leg_y := ankle_servo_y + SERVO_MOUNT_UP.y - LEG_ANKLE_MOUNT.y
	var hip_shaft_y := leg_y + LEG_HIP_MOUNT.y
	var hip_servo_y := hip_shaft_y + SERVO_SHAFT.y
	return hip_servo_y + SERVO_MOUNT_UP.y - BODY_HIP_Y


## side = -1 (left) or +1 (right). Appends hip servo, leg, ankle servo, foot in that order and
## links them; the body is part 0.
static func _add_leg(graph: ConnectionGraph, servo_def: PartDef, leg_def: PartDef, foot_def: PartDef, body_position: Vector3, side: float) -> void:
	# Hip servo hangs upside-down with its shaft pointing outward (pitch axis): 180 deg about Z
	# on the left, about X on the right. The leg's horn port is on +X, so the right leg turns around.
	var hip_basis := Basis(Vector3(0, 0, 1), PI) if side < 0.0 else Basis(Vector3(1, 0, 0), PI)
	var leg_basis := Basis.IDENTITY if side < 0.0 else Basis(Vector3(0, 1, 0), PI)
	# Ankle servo hangs upside-down with its shaft along Z (roll axis): +Z on the left, -Z on
	# the right, so the two feet roll as mirror images and drive the foot's front or back tab.
	var ankle_basis := Basis(Vector3(0, 1, 0), -side * PI / 2.0) * Basis(Vector3(0, 0, 1), PI)
	var foot_port: StringName = &"ankle_front" if side < 0.0 else &"ankle_back"
	var foot_port_offset := Vector3(0, FOOT_ANKLE_Y, -side * FOOT_TAB_Z)

	var hip_servo_position := body_position + Vector3(side * BODY_HIP_X, BODY_HIP_Y, 0) - SERVO_MOUNT_UP
	var hip_shaft := hip_servo_position + hip_basis * SERVO_SHAFT
	var leg_position := hip_shaft - leg_basis * LEG_HIP_MOUNT
	var ankle_servo_position := leg_position + LEG_ANKLE_MOUNT - SERVO_MOUNT_UP
	var ankle_shaft := ankle_servo_position + ankle_basis * SERVO_SHAFT
	var foot_position := ankle_shaft - foot_port_offset

	var first := graph.parts.size()
	graph.parts.append({"part_def": servo_def, "transform": Transform3D(hip_basis, hip_servo_position)})
	graph.parts.append({"part_def": leg_def, "transform": Transform3D(leg_basis, leg_position)})
	graph.parts.append({"part_def": servo_def, "transform": Transform3D(ankle_basis, ankle_servo_position)})
	graph.parts.append({"part_def": foot_def, "transform": Transform3D(Basis.IDENTITY, foot_position)})

	var hip_port: StringName = &"hip_left" if side < 0.0 else &"hip_right"
	graph.links.append({"a_part": 0, "a_port": hip_port, "b_part": first, "b_port": &"mount_bottom"})
	graph.links.append({"a_part": first, "a_port": &"output_shaft", "b_part": first + 1, "b_port": &"hip_mount"})
	graph.links.append({"a_part": first + 1, "a_port": &"ankle_mount", "b_part": first + 2, "b_port": &"mount_bottom"})
	graph.links.append({"a_part": first + 2, "a_port": &"output_shaft", "b_part": first + 3, "b_port": foot_port})
