class_name WorkshopLook
extends RefCounted

## Miniature-workshop lighting for the bench (ADR 0045): a warm desk-lamp key with soft contact
## shadows, a cool fill, a faint rim for silhouettes, and a studio hemisphere shared with the part
## shader. Only GL Compatibility (WebGL2) features are used: directional lights and shadow maps,
## colour ambient and the tonemapper. No SDFGI, SSAO, SSIL, SSR, glow or volumetric fog.

const KEY: String = "DirectionalLight3D"
const FILL: String = "WorkshopFill"
const RIM: String = "WorkshopRim"

## Light colours in sRGB. Directions are fixed in the world: the default views look from +Z/+X,
## so the key comes from front-left and its shadows fall behind and to the right of the robot.
## Energies were balanced on actual Compatibility renders: there a directional light of energy 1
## lights a surface about pi times more than a colour ambient of energy 1, so lamp energies stay
## well below 1 while the ambient keeps shadowed faces readable.
const KEY_ROTATION: Vector3 = Vector3(-50.0, -38.0, 0.0)
const FILL_ROTATION: Vector3 = Vector3(-18.0, 62.0, 0.0)
const RIM_ROTATION: Vector3 = Vector3(-30.0, 168.0, 0.0)

const LIGHT: Dictionary = {
	"key_color": Color("fff1dc"), "key_energy": 0.5,
	"fill_color": Color("dce6f4"), "fill_energy": 0.1,
	"rim_color": Color("eef3ff"), "rim_energy": 0.16,
	"sky_top": Color("d9dee3"), "sky_horizon": Color("eceef0"),
	"ambient_color": Color("dfe4ea"), "ambient_energy": 0.5,
	"exposure": 1.0, "white": 6.0,
	"env_top": Color("dfe5ec"), "env_horizon": Color("b7bcc0"), "env_ground": Color("6b706c"),
	"env_diffuse": 0.48, "env_specular": 1.0, "lamp_strength": 0.55, "metal_gain": 1.55, "sheen": 0.22,
	"mat": Color("879b91"), "mat_band": Color("7a8d84"), "mat_side": Color("5e6f66"),
	"mat_minor": Color("b2c2b8"), "mat_major": Color("cdd6cf"), "mat_minor_strength": 0.42, "mat_major_strength": 0.58,
	"mat_edge": Color("4e5b54"), "desk": Color("c4c5c5"),
}
const DARK: Dictionary = {
	"key_color": Color("ffe8cc"), "key_energy": 0.42,
	"fill_color": Color("c9d8f0"), "fill_energy": 0.08,
	"rim_color": Color("dbe6ff"), "rim_energy": 0.22,
	"sky_top": Color("2a333c"), "sky_horizon": Color("1a2128"),
	"ambient_color": Color("9fb0c4"), "ambient_energy": 0.32,
	"exposure": 1.0, "white": 6.0,
	"env_top": Color("8d99a8"), "env_horizon": Color("4f5862"), "env_ground": Color("23282c"),
	"env_diffuse": 0.42, "env_specular": 1.0, "lamp_strength": 0.65, "metal_gain": 1.7, "sheen": 0.45,
	"mat": Color("2d3835"), "mat_band": Color("26302d"), "mat_side": Color("1c2422"),
	"mat_minor": Color("41504b"), "mat_major": Color("566862"), "mat_minor_strength": 0.45, "mat_major_strength": 0.62,
	"mat_edge": Color("141a19"), "desk": Color("22272b"),
}
const DARK_BACKGROUND: Color = Color("101923")


static func palette(dark: bool) -> Dictionary:
	return DARK if dark else LIGHT


## Configures the scene's key light and adds the fill and rim lights once.
static func install(main: Node3D) -> void:
	var key: DirectionalLight3D = main.get_node(KEY)
	key.rotation_degrees = KEY_ROTATION
	key.shadow_enabled = true
	key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	# Two splits keep a robot-sized first cascade sharp while the bench still gets shadows.
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_split_1 = 0.12
	key.directional_shadow_max_distance = 4.0
	key.directional_shadow_blend_splits = false
	# Chosen on close renders: lower biases striped the mat with acne, higher ones began to
	# detach wheels from their contact shadows.
	key.shadow_bias = 0.06
	key.shadow_normal_bias = 1.7
	key.shadow_blur = 1.4
	key.shadow_opacity = 0.82
	for entry: Array in [[FILL, FILL_ROTATION], [RIM, RIM_ROTATION]]:
		if main.has_node(entry[0]):
			continue
		var light := DirectionalLight3D.new()
		light.name = entry[0]
		light.rotation_degrees = entry[1]
		light.shadow_enabled = false
		# Fill and rim shape the parts; their mirror glints on the matte mat only wash it out.
		light.light_specular = 0.2
		light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		main.add_child(light)


## Applies the theme to lights, environment and converted part materials.
static func apply(main: Node3D, environment: Environment, dark: bool) -> void:
	var values: Dictionary = palette(dark)
	var key: DirectionalLight3D = main.get_node_or_null(KEY)
	if key != null:
		key.light_color = values.key_color
		key.light_energy = values.key_energy
		_set_light(main.get_node_or_null(FILL), values.fill_color, values.fill_energy)
		_set_light(main.get_node_or_null(RIM), values.rim_color, values.rim_energy)
	if environment != null:
		apply_environment(environment, dark)
	var lamp: Vector3 = Basis.from_euler(KEY_ROTATION * PI / 180.0).z
	WorkshopMaterials.set_environment({
		"env_top": values.env_top, "env_horizon": values.env_horizon, "env_ground": values.env_ground,
		"env_diffuse": values.env_diffuse, "env_specular": values.env_specular, "metal_gain": values.metal_gain,
		"lamp_direction": lamp, "lamp_color": values.key_color, "lamp_strength": values.lamp_strength, "sheen": values.sheen,
	})


static func apply_environment(env: Environment, dark: bool) -> void:
	var values: Dictionary = palette(dark)
	if env.sky == null:
		env.sky = Sky.new()
	if not env.sky.sky_material is ProceduralSkyMaterial:
		env.sky.sky_material = ProceduralSkyMaterial.new()
	var sky: ProceduralSkyMaterial = env.sky.sky_material
	# A soft studio gradient in the light theme; the dark theme draws a plain dark backdrop.
	env.background_mode = Environment.BG_COLOR if dark else Environment.BG_SKY
	env.background_color = DARK_BACKGROUND
	sky.sky_top_color = values.sky_top
	sky.sky_horizon_color = values.sky_horizon
	sky.ground_horizon_color = values.sky_horizon
	sky.ground_bottom_color = values.sky_horizon
	sky.sun_angle_max = 0.0
	sky.sky_curve = 0.18
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = values.ambient_color
	env.ambient_light_energy = values.ambient_energy
	env.ambient_light_sky_contribution = 0.0
	# Part surfaces bring their own studio reflection; the sky stays a backdrop only, which also
	# spares the Web build a radiance-map update on every theme change.
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Reinhard keeps the kit's midtones close to their authored colours and only rolls off the
	# highlights (metal glints, lit LEDs); Filmic and ACES crushed the aluminium and tyres.
	env.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
	env.tonemap_exposure = values.exposure
	env.tonemap_white = values.white
	env.fog_light_color = values.sky_horizon if not dark else Color("253341")


static func _set_light(node: Node, color: Color, energy: float) -> void:
	var light: DirectionalLight3D = node as DirectionalLight3D
	if light != null:
		light.light_color = color
		light.light_energy = energy
