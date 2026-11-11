class_name LookDev
extends RefCounted

## Proposed workshop look, applied on top of the built scene so that it can be
## compared with the current one before any of it moves into the app.

const BENCH: Color = Color("bcc1c8")
const BENCH_EDGE: Color = Color("9fa4ab")
const BENCH_GRID: Color = Color("a4aab2")
const BACKDROP_TOP: Color = Color("eceef0")
const BACKDROP_HORIZON: Color = Color("f6f7f8")

## Surface treatment by the material name baked into the part meshes.
const SURFACES: Dictionary = {
	"Rubber": {"albedo": "2b2d31", "roughness": 0.92, "metallic": 0.0},
	"Black": {"albedo": "34373c", "roughness": 0.55, "metallic": 0.0},
	"ChassisMetal": {"albedo": "8a94a0", "roughness": 0.62, "metallic": 0.0},
	"BracketMetal": {"albedo": "8a94a0", "roughness": 0.62, "metallic": 0.0},
	"Silver": {"albedo": "c2c6cc", "roughness": 0.4, "metallic": 0.0},
	"DetailSteel": {"albedo": "8f959e", "roughness": 0.4, "metallic": 0.0},
}

static var seen: Dictionary = {}


static func apply(main: Node3D) -> void:
	_environment(main)
	_lights(main)
	_bench(main)
	_surfaces(main)


static func _environment(main: Node3D) -> void:
	var env: Environment = main._workbench_environment
	var sky: ProceduralSkyMaterial = env.sky.sky_material
	sky.sky_top_color = BACKDROP_TOP
	sky.sky_horizon_color = BACKDROP_HORIZON
	sky.ground_horizon_color = BACKDROP_HORIZON
	sky.ground_bottom_color = BACKDROP_TOP
	sky.sun_angle_max = 0.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f1f4f8")
	env.ambient_light_energy = 0.34
	# With a sky background the sky otherwise supplies all ambient light and flattens the scene.
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR


static func _lights(main: Node3D) -> void:
	var key: DirectionalLight3D = main.get_node("DirectionalLight3D")
	key.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	key.light_color = Color("fff6ea")
	key.light_energy = 0.86
	key.shadow_enabled = true
	key.shadow_blur = 1.6
	key.shadow_opacity = 0.7
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 1.6
	key.shadow_bias = 0.02
	key.shadow_normal_bias = 0.6
	var fill := DirectionalLight3D.new()
	fill.name = "LookFill"
	fill.rotation_degrees = Vector3(-25.0, -140.0, 0.0)
	fill.light_color = Color("e6eefc")
	fill.light_energy = 0.14
	fill.shadow_enabled = false
	main.add_child(fill)


static func _bench(main: Node3D) -> void:
	for visual: MeshInstance3D in main.find_children("*", "MeshInstance3D", true, false):
		if visual.name == "WorkbenchMat":
			visual.material_override.albedo_color = BENCH
			visual.material_override.roughness = 0.95
		elif visual.name == "WorkbenchEdge":
			visual.material_override.albedo_color = BENCH_EDGE
		elif visual.name == "MatGrid":
			visual.material_override.albedo_color = BENCH_GRID
		elif visual.material_override is StandardMaterial3D and visual.mesh is BoxMesh and visual.mesh.size.x > 1.0 and visual.material_override.albedo_color.get_luminance() > 0.85:
			# The level's own white floor becomes the neutral bench surface.
			var surface: StandardMaterial3D = visual.material_override.duplicate()
			surface.albedo_color = BENCH
			visual.material_override = surface
			print("lookdev floor: ", visual.get_path())
		elif visual.material_override is StandardMaterial3D and visual.material_override.disable_receive_shadows:
			# Paint and road surfaces take the robot's shadow so it sits on them.
			var grounded: StandardMaterial3D = visual.material_override.duplicate()
			grounded.disable_receive_shadows = false
			visual.material_override = grounded


static func _surfaces(main: Node3D) -> void:
	# Part meshes share their materials, so the treatment is applied to the source.
	for visual: MeshInstance3D in main.assembly.find_children("*", "MeshInstance3D", true, false):
		if visual.mesh == null:
			continue
		for index: int in visual.mesh.get_surface_count():
			var source: Material = visual.mesh.surface_get_material(index)
			if source == null or not source is StandardMaterial3D:
				continue
			var name: String = source.resource_name
			seen[name] = int(seen.get(name, 0)) + 1
			if SURFACES.has(name):
				source.albedo_color = Color(SURFACES[name].albedo)
				source.roughness = SURFACES[name].roughness
				source.metallic = SURFACES[name].metallic
