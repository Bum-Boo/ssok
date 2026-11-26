class_name YawBipedPreset
extends RefCounted

## Four motors: vertical hip yaw and fore-aft ankle roll, matching a small shuffling biped.
## The older pitch-hip graph remains available as BipedPreset.

const CATALOG: String = "res://assets/learning_biped/parts/"
const FLOOR_TOP: float = BipedPreset.FLOOR_TOP


static func build() -> ConnectionGraph:
	var body: PartDef = load(CATALOG + "yaw_biped_body.tres")
	var servo: PartDef = load(CATALOG + "torque_micro_servo.tres")
	var leg: PartDef = load(CATALOG + "yaw_leg_link.tres")
	var foot: PartDef = load("res://assets/parts/foot.tres")
	var sensor: PartDef = load(CATALOG + "learning_hc_sr04.tres")
	var board: PartDef = load("res://assets/parts/arduino_uno.tres")
	var graph := ConnectionGraph.new()
	var torso := Vector3(0, FLOOR_TOP + 0.1305, 0)
	graph.parts.append({"part_def": body, "transform": Transform3D(Basis.IDENTITY, torso)})
	for side: float in [-1.0, 1.0]:
		var first: int = graph.parts.size()
		var hip_basis := Basis(Vector3.DOWN, Vector3(side, 0, 0), Vector3(0, 0, side))
		var hip_anchor := torso + Vector3(side * 0.0315, -0.0415, 0)
		var hip_origin: Vector3 = hip_anchor - hip_basis * BipedPreset.SERVO_SHAFT
		var leg_basis: Basis = Basis.IDENTITY if side < 0 else Basis(Vector3.UP, PI)
		var leg_origin: Vector3 = hip_anchor - leg_basis * Vector3(0.006, 0.02, 0)
		var ankle_basis: Basis = Basis(Vector3.UP, -side * PI / 2.0) * Basis(Vector3.BACK, PI)
		var ankle_origin: Vector3 = leg_origin + BipedPreset.LEG_ANKLE_MOUNT - BipedPreset.SERVO_MOUNT_UP
		var foot_origin: Vector3 = ankle_origin + ankle_basis * BipedPreset.SERVO_SHAFT - Vector3(0, 0.024, -side * 0.0115)
		graph.parts.append({"part_def": servo, "transform": Transform3D(hip_basis, hip_origin)})
		graph.parts.append({"part_def": leg, "transform": Transform3D(leg_basis, leg_origin)})
		graph.parts.append({"part_def": servo, "transform": Transform3D(ankle_basis, ankle_origin)})
		graph.parts.append({"part_def": foot, "transform": Transform3D(Basis.IDENTITY, foot_origin)})
		graph.links.append({"a_part": 0, "a_port": &"hip_left" if side < 0 else &"hip_right", "b_part": first, "b_port": &"mount_bottom"})
		graph.links.append({"a_part": first, "a_port": &"output_shaft", "b_part": first + 1, "b_port": &"hip_mount"})
		graph.links.append({"a_part": first + 1, "a_port": &"ankle_mount", "b_part": first + 2, "b_port": &"mount_bottom"})
		graph.links.append({"a_part": first + 2, "a_port": &"output_shaft", "b_part": first + 3, "b_port": &"ankle_front" if side < 0 else &"ankle_back"})
	graph.parts.append({"part_def": sensor, "transform": Transform3D(Basis.IDENTITY, torso + BipedPreset.BODY_FACE + Vector3(0, 0, 0.0008))})
	graph.parts.append({"part_def": board, "transform": Transform3D(Basis.IDENTITY, Vector3(0, FLOOR_TOP + 0.0008, -0.12))})
	graph.links.append({"a_part": 0, "a_port": &"face", "b_part": 9, "b_port": &"mount"})
	for wiring: Array in [[1, BipedPreset.PIN_LEFT_HIP], [5, BipedPreset.PIN_RIGHT_HIP], [3, BipedPreset.PIN_LEFT_FOOT], [7, BipedPreset.PIN_RIGHT_FOOT]]:
		graph.links.append({"a_part": wiring[0], "a_port": &"signal_pin", "b_part": 10, "b_port": StringName("pin_%d" % wiring[1])})
	return graph
