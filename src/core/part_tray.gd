class_name PartTray
extends RefCounted

## Ordered learner-facing inventory. The snapshot catalog remains independently loadable.
const TABS: Array[String] = ["All", "Structure", "Motion", "Electronics", "Sensors", "Environment"]
const STRUCTURE: Array[String] = ["kit_beam_60", "kit_beam_100", "kit_beam_140", "kit_beam_180", "kit_beam_240", "kit_beam_260", "kit_plate_60_40", "kit_plate_60_60", "kit_plate_80_60", "kit_plate_120_80", "kit_plate_160_60", "kit_plate_220_120", "kit_angle_bracket", "kit_u_bracket_large", "kit_u_bracket_small", "kit_spacer_20", "kit_coupler_8", "kit_rubber_pad", "kit_weight_100", "kit_weight_300"]
const MOTION: Array[String] = ["kit_motor_12", "kit_motor_35", "tt_motor", "servo", "kit_passive_hinge", "kit_gear_2", "kit_gear_3", "kit_axle_40", "kit_wheel_40", "kit_wheel_90", "wheel_65", "ball_caster"]
const ELECTRONICS: Array[String] = ["microbit", "arduino_uno", "motor_driver", "tb6612_driver", "kit_led"]
const SENSORS: Array[String] = ["hc_sr04", "kit_line_sensor", "kit_contact_button"]
const ENVIRONMENT: Array[String] = ["kit_env_ramp_10", "kit_env_ramp_20", "kit_env_ball", "kit_env_cup", "kit_env_line_straight", "kit_env_line_corner", "stage_wall", "flag"]


static func ids(category: int = 0) -> Array[String]:
	var groups: Array = [STRUCTURE, MOTION, ELECTRONICS, SENSORS, ENVIRONMENT]
	if category > 0 and category <= groups.size():
		return groups[category - 1].duplicate()
	var result: Array[String] = []
	for group: Array[String] in groups:
		result.append_array(group)
	return result


static func category_for(id: StringName) -> int:
	for category: int in range(1, TABS.size()):
		if String(id) in ids(category):
			return category
	return -1


static func definitions(catalog: Array[PartDef]) -> Array[PartDef]:
	var by_id: Dictionary = {}
	for definition: PartDef in catalog:
		by_id[String(definition.id)] = definition
	var result: Array[PartDef] = []
	for id: String in ids():
		if by_id.has(id):
			result.append(by_id[id])
	return result
