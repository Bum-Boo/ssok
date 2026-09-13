class_name ServoArmPreset
extends RefCounted

## First answer key (ADR 0005): base + servo + arm, servo wired to pin 9.
## Built in code until assembly mode (#3) and preset save/load (#8) produce it.

const FLOOR_TOP := 0.05

const ANSWER_CODE := """from servo import Servo

arm = Servo(9)
arm.write(90)
sleep(1)
arm.write(0)
sleep(1)
arm.write(180)
"""


static func build() -> ConnectionGraph:
	var base: PartDef = load("res://assets/parts/base.tres")
	var servo: PartDef = load("res://assets/parts/servo.tres")
	var arm: PartDef = load("res://assets/parts/arm_link.tres")
	var board: PartDef = load("res://assets/parts/board.tres")

	var base_pos := Vector3(0, FLOOR_TOP + 0.01, 0)
	var servo_pos := base_pos + Vector3(0, 0.01 + 0.015, 0)
	var shaft := servo_pos + Vector3(0.0115, 0.005, 0)
	# Arm points up, its -Z face on the shaft: X=(0,0,-1) Y=(0,1,0) Z=(1,0,0).
	var arm_basis := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT)
	var arm_pos := shaft - arm_basis * Vector3(0, -0.035, -0.005)

	var graph := ConnectionGraph.new()
	graph.parts = [
		{"part_def": base, "transform": Transform3D(Basis.IDENTITY, base_pos)},
		{"part_def": servo, "transform": Transform3D(Basis.IDENTITY, servo_pos)},
		{"part_def": arm, "transform": Transform3D(arm_basis, arm_pos)},
		{"part_def": board, "transform": Transform3D(Basis.IDENTITY, Vector3(0.12, FLOOR_TOP + 0.0025, 0))},
	]
	graph.links = [
		{"a_part": 0, "a_port": &"mount_top", "b_part": 1, "b_port": &"mount_bottom"},
		{"a_part": 1, "a_port": &"output_shaft", "b_part": 2, "b_port": &"mount_base"},
		{"a_part": 1, "a_port": &"signal_pin", "b_part": 3, "b_port": &"pin_9"},
	]
	return graph
