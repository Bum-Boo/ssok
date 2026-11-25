extends SceneTree

## ADR 0043 workshop look: part surface pipeline, theme sync, light rig, cutting mat and the
## run-mode LED/sonar/snap feedback. Headless-safe; the rendered look is compared with
## tools/lookdev/capture_look.gd.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + message)


func _settle(frames: int = 8) -> void:
	for index: int in frames:
		await process_frame


func _run() -> void:
	_check_materials()
	await _check_scene()
	await _check_led_glow()
	await _check_sonar_beam()
	_check_snap_feedback()
	print("workshop_look_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_materials() -> void:
	var definition: PartDef = load("res://assets/construction_kit/parts/kit_plate_220_120.tres")
	var source: StandardMaterial3D = definition.mesh.surface_get_material(0)
	var converted: ShaderMaterial = WorkshopMaterials.variant(source)
	_check(converted != null and converted.shader == WorkshopMaterials.SHADER, "metal kit plate converts to the shared part shader")
	_check(is_equal_approx(converted.get_shader_parameter("metallic"), source.metallic) and converted.get_shader_parameter("albedo") == source.albedo_color, "conversion keeps metallic and albedo")
	_check(converted.get_shader_parameter("texture_normal") == source.normal_texture and converted.get_shader_parameter("uv1_scale") == source.uv1_scale, "conversion keeps the triplanar brushed normal map")
	_check(WorkshopMaterials.variant(source) == converted, "one converted material per source material")
	var glass: StandardMaterial3D = source.duplicate()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_check(WorkshopMaterials.variant(glass) == null, "transparent materials stay on StandardMaterial3D")
	var textured: StandardMaterial3D = source.duplicate()
	textured.uv1_triplanar = false
	_check(WorkshopMaterials.variant(textured) == null, "UV normal maps are not silently reprojected")

	var visual := MeshInstance3D.new()
	visual.mesh = definition.mesh
	WorkshopMaterials.dress(visual)
	_check(visual.get_surface_override_material(0) == converted, "dress assigns per-instance overrides")
	_check(definition.mesh.surface_get_material(0) == source, "catalog mesh keeps its StandardMaterial3D")
	visual.free()

	var holder := Node3D.new()
	for dark: bool in [true, false]:
		WorkshopLook.apply(holder, null, dark)
		var values: Dictionary = WorkshopLook.palette(dark)
		_check(converted.get_shader_parameter("env_top") == values.env_top and converted.get_shader_parameter("metal_gain") == values.metal_gain, "theme updates existing converted materials dark=%s" % dark)
		# Metal must keep a lit studio to reflect whatever background the theme draws.
		_check(values.env_top.get_luminance() > 0.3, "studio reflection stays lit dark=%s" % dark)
	holder.free()


func _check_scene() -> void:
	var prefs: InterfacePreferences = root.get_node("Preferences")
	var level: Dictionary = StageLevels.find("finish-line")
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.session = {"mode": "stage", "level": level}
	root.add_child(main)
	await _settle()
	var key: DirectionalLight3D = main.get_node(WorkshopLook.KEY)
	var fill: DirectionalLight3D = main.get_node_or_null(WorkshopLook.FILL)
	var rim: DirectionalLight3D = main.get_node_or_null(WorkshopLook.RIM)
	_check(key.shadow_enabled and key.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and key.shadow_normal_bias > 1.0, "key lamp casts biased two-split shadows")
	_check(fill != null and rim != null and not fill.shadow_enabled and not rim.shadow_enabled, "fill and rim lights add no shadow maps")
	_check(key.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY and rim.light_specular < 0.5, "lights draw no sun discs and the rim cannot glare on the mat")
	var env: Environment = main._workbench_environment
	_check(env.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED and env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "no radiance map: parts carry their own studio reflection")
	_check(env.tonemap_mode == Environment.TONE_MAPPER_REINHARDT, "midtone-preserving tonemapper")
	_check(not env.sdfgi_enabled and not env.ssao_enabled and not env.ssil_enabled and not env.ssr_enabled and not env.glow_enabled and not env.volumetric_fog_enabled, "no Forward+-only or post-process effects")

	var mat: MeshInstance3D = main._level.get_node("Ground/WorkbenchMat")
	var desk: MeshInstance3D = main._level.get_node("Ground/WorkbenchDesk")
	var surface: ShaderMaterial = mat.material_override
	_check(surface.shader == WorkbenchSurface.MAT_SHADER, "cutting mat uses the procedural shader")
	_check(surface.get_shader_parameter("mat_half_size") == Vector2(mat.mesh.size.x, mat.mesh.size.z) * 0.5 and surface.get_shader_parameter("mat_center") == Vector2(mat.position.x, mat.position.z), "mat shader bounds match the mat mesh")
	_check(desk.position.y + 0.0001 < mat.position.y - mat.mesh.size.y * 0.5 and desk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "desk sits below the mat and casts nothing")
	_check(desk.material_override.render_priority == Material.RENDER_PRIORITY_MIN, "desk blends before other transparent effects")
	for appearance: String in ["dark", "light"]:
		prefs.values.appearance = appearance
		prefs.changed.emit()
		var values: Dictionary = WorkshopLook.palette(appearance == "dark")
		_check(surface.get_shader_parameter("mat_color") == values.mat and desk.material_override.get_shader_parameter("desk_color") == values.desk, "mat and desk follow the %s theme" % appearance)
		_check(is_equal_approx(key.light_energy, values.key_energy) and WorkshopMaterials.converted_count() > 0, "lamp follows the %s theme" % appearance)
	main.free()
	await _settle(2)


func _check_led_glow() -> void:
	var graph := ConnectionGraph.new()
	graph.parts.append({"part_def": load("res://assets/parts/microbit.tres"), "transform": Transform3D.IDENTITY})
	graph.parts.append({"part_def": load("res://assets/construction_kit/parts/kit_led.tres"), "transform": Transform3D(Basis.IDENTITY, Vector3(0.1, 0.1, 0))})
	graph.links.append({"a_part": 0, "a_port": &"pin_1", "b_part": 1, "b_port": &"signal_pin"})
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(graph)
	var led: LEDDevice = hardware.leds[1]
	_check(is_instance_valid(led.glow) and not led.glow.visible, "LED halo exists and starts dark")
	_check(led.glow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and (led.glow.material_override as ShaderMaterial).shader == LEDDevice.GLOW_SHADER, "halo is an additive billboard without shadows")
	led.set_brightness(0.5)
	_check(led.glow.visible and is_equal_approx(led.glow.material_override.get_shader_parameter("intensity"), 0.8), "halo intensity follows brightness")
	hardware.stop_motors()
	_check(not led.glow.visible, "Stop darkens the halo with the LED")
	hardware.teardown()
	await _settle(2)
	_check(not is_instance_valid(led.glow), "teardown frees the halo")
	hardware.free()


func _check_sonar_beam() -> void:
	var hardware := RunMode.new()
	root.add_child(hardware)
	hardware.build(KitCarPreset.build(0.4))
	for tick: int in 4:
		await physics_frame
	var sensor: SonarSensor = hardware.sonar_on_pins(1, 2)
	_check(sensor != null, "kit car sonar resolves")
	sensor.measure_cm()
	_check(hardware.sonar_beams.is_empty(), "evaluator readings draw no beam")
	var reading: float = sensor.distance_cm()
	var beam: SonarBeam = hardware.sonar_beams.get(sensor.part_index)
	_check(beam != null and beam.visible and beam.layers == SonarBeam.LAYER, "program reading shows the beam on the overlay layer")
	_check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and beam.get_children().is_empty(), "beam has no shadow or collision")
	if sensor.last_valid:
		_check(is_equal_approx(beam.global_basis.get_scale().z, reading / 100.0), "beam length matches the echo distance")
	var origin: Vector3 = hardware.part_global_transform(sensor.part_index) * Vector3(0, 0, 0.012)
	_check(beam.global_position.is_equal_approx(origin), "beam starts at the sensor's ray origin")
	beam._process(SonarBeam.HOLD_SECONDS + SonarBeam.FADE_SECONDS + 0.01)
	_check(not beam.visible, "beam fades once the program stops reading")
	_check(SonarBeam.LAYER == 1 << 19 and FileAccess.get_file_as_string("res://src/runtime/agent_camera_loop.gd").contains("cull_mask &= ~SonarBeam.LAYER"), "the robot camera masks out the overlay layer")
	hardware.teardown()
	await _settle(2)
	_check(hardware.sonar_beams.is_empty() and not is_instance_valid(beam), "teardown frees beams")
	hardware.free()


func _check_snap_feedback() -> void:
	var indicators := PortIndicators.new()
	var ring_material: ShaderMaterial = indicators.rings.material_override
	_check(ring_material.shader == PortIndicators.RING_SHADER, "rings use the halo ring shader")
	var core_inner: float = ring_material.get_shader_parameter("core_inner")
	var core_outer: float = ring_material.get_shader_parameter("core_outer")
	_check(core_inner > 0.0 and core_outer < 1.0 and core_inner < core_outer, "ring core sits inside its halo band")
	var arrays: Array = indicators.rings.multimesh.mesh.surface_get_arrays(0)
	_check(arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size(), "ring mesh carries radial UVs")
	_check(indicators.bolts.material_override is ShaderMaterial, "bolt heads use the studio metal surface")
	indicators.free()
	var node := PartNode.new()
	node.setup(load("res://assets/construction_kit/parts/kit_beam_60.tres"), 0)
	node.set_placement_preview(false)
	var ghost: ShaderMaterial = node._mesh_instance.material_override
	_check(ghost.shader == PartNode.GHOST_SHADER and ghost.get_shader_parameter("tint") == SsokTheme.ACCENT, "valid placement ghost uses the accent Fresnel shader")
	node.set_placement_preview(true)
	_check(ghost.get_shader_parameter("tint") == SsokTheme.ERROR, "blocked placement ghost switches to the error tint")
	node.clear_placement_preview()
	_check(node._mesh_instance.material_override == null and node._mesh_instance.get_surface_override_material(0) is ShaderMaterial, "clearing the ghost restores the converted part surface")
	node.free()
