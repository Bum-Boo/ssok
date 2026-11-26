extends SceneTree

## 3D wiring view: power and signal cables differ, the frame turns see-through on the
## Wiring tab, and pointed-at or unpowered ports light up. All of it derives from the graph.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + label)


## Surfaces of a part visual that carry the workshop part shader as a per-surface override.
func _studio_surfaces(part: PartNode) -> int:
	var visual: MeshInstance3D = part._mesh_instance
	var count: int = 0
	for surface: int in visual.get_surface_override_material_count():
		var override: Material = visual.get_surface_override_material(surface)
		if override is ShaderMaterial and (override as ShaderMaterial).shader == WorkshopMaterials.SHADER:
			count += 1
	return count


func _index(graph: ConnectionGraph, id: StringName) -> int:
	for part: int in graph.parts.size():
		if graph.parts[part].part_def.id == id:
			return part
	return -1


func _run() -> void:
	_check_unit()
	await _check_app()
	print("wire_visuals_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_unit() -> void:
	var graph: ConnectionGraph = KitCarPreset.build()
	var holder: PartDef = load("res://assets/power/parts/battery_holder_4aa.tres")
	graph.parts.append({"part_def": holder, "transform": graph.parts[0].transform.translated(Vector3(0, 0.06, 0))})
	var battery: int = graph.parts.size() - 1
	var driver: int = _index(graph, &"motor_driver")
	var board: int = _index(graph, &"microbit")
	graph.links.append({"a_part": battery, "a_port": &"power_out", "b_part": driver, "b_port": &"power_in"})
	var signals: int = Wiring.pin_map(graph).size()
	var before: Array = graph.links.duplicate(true)
	var visuals := WireVisuals.new()
	root.add_child(visuals)
	visuals.refresh(graph)
	_check(visuals.power_wire_count() == 1, "the battery cable is drawn as a power wire")
	_check(visuals.wire_count() - visuals.power_wire_count() >= signals, "every board pin wire is drawn as a signal wire")
	_check(visuals.cables.mesh != null and visuals.cables.mesh.get_surface_count() == 1, "cables form one renderable mesh")
	for dark: bool in [true, false]:
		SsokTheme.configure(dark, 1.0, 1.0)
		var power: Color = WireVisuals.wire_color(true)
		var signal_color: Color = WireVisuals.wire_color(false)
		_check(absf(power.h - signal_color.h) > 0.25, "power and signal hues differ (dark=%s)" % dark)
		_check(absf(power.get_luminance() - SsokTheme.BG.get_luminance()) > 0.25 and absf(signal_color.get_luminance() - SsokTheme.BG.get_luminance()) > 0.2, "wire colours contrast with the background (dark=%s)" % dark)
		_check(not power.is_equal_approx(SsokTheme.ERROR), "power wires never look like errors (dark=%s)" % dark)
	SsokTheme.configure(true, 1.0, 1.0)
	_check(visuals.marker_count() == 0, "nothing is highlighted until asked")
	visuals.focus = [{"part": battery, "port": &"power_out"}]
	visuals.refresh(graph)
	_check(visuals.marker_count() == 1 and visuals.highlighted_wire_count() == 1, "a focused port lights up with its wire")
	visuals.problems = [{"part": board, "port": PowerNet.POWER_IN}]
	visuals.refresh(graph)
	_check(visuals.marker_count() == 2, "an unpowered port gets its own problem marker")
	_check(graph.links == before, "visuals never edit the graph")
	visuals.queue_free()


func _check_app() -> void:
	root.size = Vector2i(1440, 900)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_modular_pressed()
	await process_frame
	var assembly: AssemblyMode = main.assembly
	var panel: WiringPanel = main.wiring_panel
	var visuals: WireVisuals = main.wire_visuals
	_check(visuals.wire_count() > 0, "the kit humanoid's wires are drawn in 3D")
	_check(assembly.xray_part_count() == 0, "the frame is solid outside the Wiring tab")
	# The workshop part shader lives in per-surface overrides; X-ray uses material_override above it.
	var frame: Array[PartNode] = []
	for part: PartNode in assembly.find_children("*", "PartNode", true, false):
		if part.is_structural() and _studio_surfaces(part) > 0:
			frame.append(part)
	var studio_before: Array[int] = []
	for part: PartNode in frame:
		studio_before.append(_studio_surfaces(part))
	_check(not frame.is_empty() and frame.all(func(part: PartNode) -> bool: return part._mesh_instance.material_override == null), "the solid frame shows the workshop part shader")
	main.program_tabs.current_tab = panel.get_index()
	await process_frame
	_check(main.wiring_view_open(), "the Wiring tab is open")
	_check(assembly.xray_part_count() > 0, "beams and plates turn see-through on the Wiring tab")
	_check(frame.all(func(part: PartNode) -> bool:
		var cover: Material = part._mesh_instance.material_override
		return part.xray and cover is StandardMaterial3D and (cover as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and (cover as StandardMaterial3D).albedo_color.a < 0.5), "X-ray covers the workshop shader with a see-through material")
	var kept: bool = true
	for index: int in frame.size():
		kept = kept and _studio_surfaces(frame[index]) == studio_before[index]
	_check(kept, "X-ray keeps the workshop surface overrides underneath")
	var electronics_clear: bool = true
	for part: PartNode in assembly.find_children("*", "PartNode", true, false):
		if not part.is_structural() and part.xray:
			electronics_clear = false
	_check(electronics_clear, "electronic parts stay solid")
	panel.xray_toggle.button_pressed = false
	await process_frame
	_check(assembly.xray_part_count() == 0, "the see-through toggle turns X-ray off")
	var restored: bool = true
	for index: int in frame.size():
		restored = restored and frame[index]._mesh_instance.material_override == null and _studio_surfaces(frame[index]) == studio_before[index]
	_check(restored, "turning X-ray off restores the workshop part shader")
	panel.xray_toggle.button_pressed = true
	# Hovering a wire row focuses both ends of that wire.
	var row: Control = panel.connections.get_child(0)
	row.mouse_entered.emit()
	await process_frame
	_check(panel.focus.size() == 2 and visuals.highlighted_wire_count() == 1, "hovering a wire highlights it in 3D")
	row.mouse_exited.emit()
	main.program_tabs.current_tab = 2
	await process_frame
	_check(assembly.xray_part_count() == 0 and visuals.marker_count() == 0, "leaving the tab restores the frame and clears highlights")
	main.free()
