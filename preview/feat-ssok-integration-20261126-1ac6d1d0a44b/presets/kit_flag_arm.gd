class_name KitFlagArmPreset
extends RefCounted


static func build() -> ConnectionGraph:
	var graph := ConnectionGraph.new()
	var flat := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	var deck: int = KitCarPreset._add(graph, "kit_plate_120_80", Vector3(0, 0.052, 0), flat)
	KitCarPreset._attach(graph, deck, KitCarPreset._hole(graph, deck, Vector3(-0.03, -0.01, 0.002)), "kit_weight_300", "mount_0_back", flat)
	var bracket: int = KitCarPreset._attach(graph, deck, KitCarPreset._hole(graph, deck, Vector3(0.01, 0.01, 0.002)), "kit_angle_bracket", "base_2_back", Basis(Vector3.UP, PI / 2.0))
	var motor: int = KitCarPreset._attach(graph, bracket, "upright_3_front", "kit_motor_12", "mount_0_back")
	var horn: int = KitCarPreset._attach(graph, motor, "output", "kit_u_bracket_small", "axle_right_back")
	var arm_basis := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)
	var arm: int = KitCarPreset._attach(graph, horn, "cheek_7_front", "kit_beam_140", "h0_back", arm_basis)
	KitCarPreset._attach(graph, arm, "h6_front", "flag", "kit_h0_back", arm_basis)
	var board: int = KitCarPreset._attach(graph, deck, KitCarPreset._hole(graph, deck, Vector3(-0.03, 0.01, 0.002)), "microbit", "kit_h0_back")
	KitCarPreset._link(graph, board, "pin_0", motor, "signal")
	return graph
