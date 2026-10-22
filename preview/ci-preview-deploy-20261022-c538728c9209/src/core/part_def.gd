class_name PartDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var mesh: Mesh
@export var ports: Array[Port] = []
@export var mass_kg: float = 0.05
## Zero preserves the original ideal positional servo model.
@export var actuator_torque_nm: float = 0.0
@export var actuator_min_deg: float = -90.0
@export var actuator_max_deg: float = 90.0
## Separate motor housings drive the connected output link, not their own housing.
@export var actuator_drives_connected_body: bool = false
## Bolted modular components may share one solver body while remaining separate graph parts.
@export var merge_fixed_connections: bool = false
@export var physics_frame_priority: int = 0
## Hollow frames need several local boxes instead of one solid bounding box.
@export var collision_boxes: Array[AABB] = []

@export var board_profile_id: String = ""
@export var dc_motor: bool = false
@export var motor_stall_torque_nm: float = 0.078
@export var motor_no_load_rpm: float = 250.0
@export var driver_supply_voltage: float = 6.0
@export var driver_voltage_drop: float = 0.3
@export var wheel_radius: float = 0.0
@export var wheel_width: float = 0.0
@export var rolling_friction: float = 0.8

@export var caster_radius: float = 0.0
