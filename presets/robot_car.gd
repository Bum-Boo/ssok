class_name RobotCarPreset
extends RefCounted

const ANSWER_CODE: String = """left = Motor(pin0)
right = Motor(pin12)
left.motor_on("forward", 55)
right.motor_on("forward", 55)
sleep(3000)
stop()
"""
const BRAKE_CODE: String = """left = Motor(pin0)
right = Motor(pin12)
sonar = Sonar(pin1, pin2)
while sonar.distance_cm() > 10:
    left.motor_on("forward", 35)
    right.motor_on("forward", 35)
    sleep(20)
stop()
"""


static func build(wall_x: float = -1.0) -> ConnectionGraph:
	var graph := ConnectionGraph.new()
	var definitions: Array[String] = ["car_chassis", "tt_motor", "tt_motor", "wheel_65", "wheel_65", "microbit", "motor_driver", "ball_caster", "hc_sr04"]
	for id: String in definitions:
		graph.parts.append({"part_def": load("res://assets/parts/%s.tres" % id), "transform": Transform3D.IDENTITY})
	graph.parts[0].transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.05 + 0.0175, 0))
	_place(graph, 0, &"motor_left", 1, &"mount")
	_place(graph, 0, &"motor_right", 2, &"mount")
	_place(graph, 1, &"shaft_left", 3, &"hub", Basis(Vector3.UP, PI))
	_place(graph, 2, &"shaft_right", 4, &"hub")
	_place(graph, 0, &"board_mount", 5, &"mount_bottom")
	_place(graph, 0, &"driver_mount", 6, &"mount_bottom")
	_place(graph, 0, &"caster_mount", 7, &"mount")
	_place(graph, 0, &"sensor_mount", 8, &"mount", Basis(Vector3.UP, PI / 2.0))
	for pin: int in [0, 8, 12, 16]:
		_link(graph, 5, StringName("pin_%d" % pin), 6, StringName("input_%d" % pin))
	_link(graph, 6, &"motor_1", 1, &"power")
	_link(graph, 6, &"motor_2", 2, &"power")
	_link(graph, 5, &"pin_1", 8, &"trig_pin")
	_link(graph, 5, &"pin_2", 8, &"echo_pin")
	if wall_x > 0:
		graph.parts.append({"part_def": load("res://assets/parts/stage_wall.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(wall_x, 0.15, 0))})
	return graph


static func _place(graph: ConnectionGraph, a: int, a_port: StringName, b: int, b_port: StringName, basis: Basis = Basis.IDENTITY) -> void:
	var pa: Port = RunMode._port(graph.parts[a].part_def, a_port)
	var pb: Port = RunMode._port(graph.parts[b].part_def, b_port)
	var anchor: Vector3 = graph.parts[a].transform * pa.local_position
	graph.parts[b].transform = Transform3D(basis, anchor - basis * pb.local_position)
	_link(graph, a, a_port, b, b_port)


static func _link(graph: ConnectionGraph, a: int, a_port: StringName, b: int, b_port: StringName) -> void:
	graph.links.append({"a_part": a, "a_port": a_port, "b_part": b, "b_port": b_port})
