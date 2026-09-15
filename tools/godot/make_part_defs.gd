extends SceneTree

## Regenerates assets/parts/<id>.tres from the spec table below so the Part/Port
## numbers live in one reviewable place (docs/ARCHITECTURE.md mirrors it).
## Run tools/godot/make_materials.gd after importing the OBJ sources and before this script.
## Meshes bind the shared PBR materials through assets/meshes/<id>.res.

const OUT_DIR := "res://assets/parts"
const PartMaterials = preload("res://tools/godot/part_materials.gd")

const MECH := Port.Kind.MECH
const ELEC := Port.Kind.ELEC

## id -> { display_name, mass_kg, ports: [ { id, kind, position, normal, tag, accepts, rotates } ] }
var _parts: Dictionary = {
	&"base": {
		"display_name": "Base Plate",
		"mass_kg": 0.08,
		"ports": [
			{"id": &"mount_top", "kind": MECH, "position": Vector3(0, 0.01, 0), "normal": Vector3.UP,
				"tag": &"base_mount", "accepts": [&"servo_mount", &"motor_mount", &"sensor_mount"]},
		],
	},
	&"servo": {
		"display_name": "Servo Motor",
		"mass_kg": 0.02,
		"ports": [
			{"id": &"mount_bottom", "kind": MECH, "position": Vector3(0, -0.015, 0), "normal": Vector3.DOWN,
				"tag": &"servo_mount", "accepts": [&"base_mount"]},
			{"id": &"output_shaft", "kind": MECH, "position": Vector3(0.0115, 0.005, 0), "normal": Vector3.RIGHT,
				"tag": &"servo_output", "accepts": [&"arm_mount"], "rotates": true},
			{"id": &"signal_pin", "kind": ELEC, "position": Vector3(-0.0115, 0, 0), "normal": Vector3.LEFT,
				"tag": &"pwm_signal", "accepts": [&"board_digital_pwm"]},
		],
	},
	&"arm_link": {
		"display_name": "Arm Link",
		"mass_kg": 0.01,
		"ports": [
			{"id": &"mount_base", "kind": MECH, "position": Vector3(0, -0.035, -0.005), "normal": Vector3(0, 0, -1),
				"tag": &"arm_mount", "accepts": [&"servo_output"]},
		],
	},
	&"board": {
		"display_name": "Board (placeholder)",
		"mass_kg": 0.03,
		"ports": [
			{"id": &"pin_9", "kind": ELEC, "position": Vector3(-0.03, 0.0025, -0.02), "normal": Vector3.UP,
				"tag": &"board_digital_pwm", "accepts": [&"pwm_signal"]},
			{"id": &"pin_10", "kind": ELEC, "position": Vector3(-0.03, 0.0025, -0.01), "normal": Vector3.UP,
				"tag": &"board_digital_pwm", "accepts": [&"pwm_signal"]},
		],
	},
	# Arduino Uno R3 (A000066 datasheet): PCB 66.04 x 50.80 mm, digital header along +Z at 2.54 mm
	# pitch with the 0.16" gap between D7 and D8. PWM pins 3/5/6/9/10/11 take a servo signal.
	&"arduino_uno": {
		"display_name": "Arduino Uno R3",
		"mass_kg": 0.025,
		"ports": _uno_pins(),
	},
	# TT gear motor (70 x 22 x 18 mm, dual 5.4 mm D-shaft through the gearbox). No ELEC port yet:
	# a DC motor needs a driver module before the runtime can address it.
	&"tt_motor": {
		"display_name": "TT Gear Motor",
		"mass_kg": 0.03,
		"ports": [
			{"id": &"shaft_left", "kind": MECH, "position": Vector3(-0.024, 0, -0.009), "normal": Vector3(0, 0, -1),
				"tag": &"motor_shaft", "accepts": [&"wheel_hub"], "rotates": true},
			{"id": &"shaft_right", "kind": MECH, "position": Vector3(-0.024, 0, 0.009), "normal": Vector3(0, 0, 1),
				"tag": &"motor_shaft", "accepts": [&"wheel_hub"], "rotates": true},
			{"id": &"mount", "kind": MECH, "position": Vector3(-0.0165, -0.011, 0), "normal": Vector3.DOWN,
				"tag": &"motor_mount", "accepts": [&"base_mount"]},
		],
	},
	# 65 mm x 26 mm robot wheel with a 5.4 mm D-bore hub.
	&"wheel_65": {
		"display_name": "Wheel 65 mm",
		"mass_kg": 0.03,
		"ports": [
			{"id": &"hub", "kind": MECH, "position": Vector3(0, 0, -0.013), "normal": Vector3(0, 0, -1),
				"tag": &"wheel_hub", "accepts": [&"motor_shaft"]},
		],
	},
	# Otto-DIY-style biped shell (CC-BY-SA 4.0 reference): the body hangs two hip servos and wears
	# an HC-SR04 as eyes; each leg carries an ankle servo whose horn drives a foot.
	&"biped_body": {
		"display_name": "Biped Body",
		"mass_kg": 0.04,
		"ports": [
			{"id": &"hip_left", "kind": MECH, "position": Vector3(-0.02, -0.03, 0), "normal": Vector3.DOWN,
				"tag": &"base_mount", "accepts": [&"servo_mount"]},
			{"id": &"hip_right", "kind": MECH, "position": Vector3(0.02, -0.03, 0), "normal": Vector3.DOWN,
				"tag": &"base_mount", "accepts": [&"servo_mount"]},
			{"id": &"face", "kind": MECH, "position": Vector3(0, 0.01, 0.0225), "normal": Vector3(0, 0, 1),
				"tag": &"base_mount", "accepts": [&"sensor_mount"]},
		],
	},
	&"leg_link": {
		"display_name": "Leg Link",
		"mass_kg": 0.012,
		"ports": [
			{"id": &"hip_mount", "kind": MECH, "position": Vector3(0.006, 0.014, 0), "normal": Vector3.RIGHT,
				"tag": &"arm_mount", "accepts": [&"servo_output"]},
			{"id": &"ankle_mount", "kind": MECH, "position": Vector3(0, -0.02, 0), "normal": Vector3.DOWN,
				"tag": &"base_mount", "accepts": [&"servo_mount"]},
		],
	},
	&"foot": {
		"display_name": "Foot",
		"mass_kg": 0.02,
		"ports": [
			{"id": &"ankle_front", "kind": MECH, "position": Vector3(0, 0.024, 0.0115), "normal": Vector3(0, 0, -1),
				"tag": &"arm_mount", "accepts": [&"servo_output"]},
			{"id": &"ankle_back", "kind": MECH, "position": Vector3(0, 0.024, -0.0115), "normal": Vector3(0, 0, 1),
				"tag": &"arm_mount", "accepts": [&"servo_output"]},
		],
	},
	# HC-SR04 ultrasonic sensor: 45 x 20 mm PCB, VCC/TRIG/ECHO/GND header at 2.54 mm pitch.
	&"hc_sr04": {
		"display_name": "HC-SR04 Ultrasonic",
		"mass_kg": 0.009,
		"ports": [
			{"id": &"mount", "kind": MECH, "position": Vector3(0, 0, -0.0008), "normal": Vector3(0, 0, -1),
				"tag": &"sensor_mount", "accepts": [&"base_mount"]},
			{"id": &"trig_pin", "kind": ELEC, "position": Vector3(-0.00127, -0.0185, 0), "normal": Vector3.DOWN,
				"tag": &"digital_io", "accepts": [&"board_digital", &"board_digital_pwm"]},
			{"id": &"echo_pin", "kind": ELEC, "position": Vector3(0.00127, -0.0185, 0), "normal": Vector3.DOWN,
				"tag": &"digital_io", "accepts": [&"board_digital", &"board_digital_pwm"]},
		],
	},
	# Original ssok chassis: 120 x 4 x 80 mm, with solid pads between the lightening holes.
	&"chassis_plate": {
		"display_name": "Chassis Plate 120 mm",
		"mass_kg": 0.06,
		"ports": [
			{"id": &"mount_center", "kind": MECH, "position": Vector3(0, 0.002, 0), "normal": Vector3.UP,
				"tag": &"base_mount", "accepts": [&"servo_mount", &"motor_mount", &"sensor_mount"]},
			{"id": &"mount_left", "kind": MECH, "position": Vector3(-0.040, 0.002, 0), "normal": Vector3.UP,
				"tag": &"base_mount", "accepts": [&"servo_mount", &"motor_mount", &"sensor_mount"]},
			{"id": &"mount_right", "kind": MECH, "position": Vector3(0.040, 0.002, 0), "normal": Vector3.UP,
				"tag": &"base_mount", "accepts": [&"servo_mount", &"motor_mount", &"sensor_mount"]},
			{"id": &"mount_rear", "kind": MECH, "position": Vector3(0, 0.002, -0.025), "normal": Vector3.UP,
				"tag": &"base_mount", "accepts": [&"servo_mount", &"motor_mount", &"sensor_mount"]},
			{"id": &"mount_front", "kind": MECH, "position": Vector3(0, 0.002, 0.025), "normal": Vector3.UP,
				"tag": &"base_mount", "accepts": [&"servo_mount", &"motor_mount", &"sensor_mount"]},
		],
	},
	# Original right-angle adapter for the existing servo envelope; dimensions are design choices.
	&"servo_bracket": {
		"display_name": "Servo Angle Bracket",
		"mass_kg": 0.015,
		"ports": [
			{"id": &"mount_bottom", "kind": MECH, "position": Vector3(0, -0.002, 0), "normal": Vector3.DOWN,
				"tag": &"servo_mount", "accepts": [&"base_mount"]},
			{"id": &"mount_top", "kind": MECH, "position": Vector3(0, 0.002, 0), "normal": Vector3.UP,
				"tag": &"base_mount", "accepts": [&"servo_mount", &"motor_mount", &"sensor_mount"]},
			{"id": &"mount_rear", "kind": MECH, "position": Vector3(0, 0.016, -0.015), "normal": Vector3(0, 0, -1),
				"tag": &"base_mount", "accepts": [&"servo_mount", &"motor_mount", &"sensor_mount"]},
		],
	},
}

const UNO_PWM_PINS := [3, 5, 6, 9, 10, 11]
const UNO_DIGITAL_PINS := [2, 4, 7, 8, 12, 13]
const UNO_PIN_TOP := 0.0093
const UNO_HEADER_Z := 0.0229


static func _uno_pin_x(pin: int) -> float:
	if pin <= 7:
		return 0.0292 - pin * 0.00254
	return 0.0292 - 7 * 0.00254 - 0.00406 - (pin - 8) * 0.00254


static func _uno_pins() -> Array:
	var pins := []
	for pin: int in UNO_PWM_PINS:
		pins.append({"id": StringName("pin_%d" % pin), "kind": ELEC,
			"position": Vector3(_uno_pin_x(pin), UNO_PIN_TOP, UNO_HEADER_Z), "normal": Vector3.UP,
			"tag": &"board_digital_pwm", "accepts": [&"pwm_signal", &"digital_io"]})
	for pin: int in UNO_DIGITAL_PINS:
		pins.append({"id": StringName("pin_%d" % pin), "kind": ELEC,
			"position": Vector3(_uno_pin_x(pin), UNO_PIN_TOP, UNO_HEADER_Z), "normal": Vector3.UP,
			"tag": &"board_digital", "accepts": [&"digital_io"]})
	return pins


func _init() -> void:
	var failed := false
	for id: StringName in _parts:
		var spec: Dictionary = _parts[id]
		var def := PartDef.new()
		def.id = id
		def.display_name = spec["display_name"]
		def.mass_kg = spec["mass_kg"]
		for port_spec: Dictionary in spec["ports"]:
			var port := Port.new()
			port.id = port_spec["id"]
			port.resource_scene_unique_id = "Port_%s" % port.id
			port.kind = port_spec["kind"]
			port.local_position = port_spec["position"]
			port.local_normal = port_spec["normal"]
			port.tag = port_spec["tag"]
			port.accepts.assign(port_spec["accepts"])
			port.rotates = port_spec.get("rotates", false)
			def.ports.append(port)
		def.mesh = PartMaterials.load_mesh(id)
		if def.mesh == null:
			failed = true
			continue
		var path := "%s/%s.tres" % [OUT_DIR, id]
		var err := ResourceSaver.save(def, path)
		print("%s: save=%d ports=%d mesh=%s" % [id, err, def.ports.size(), def.mesh != null])
		failed = failed or err != OK
	quit(1 if failed else 0)
