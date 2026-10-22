extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _errors: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_answer_pressed()
	var assembly: AssemblyMode = main.assembly
	var panel: WiringPanel = main.wiring_panel
	var before: Array[Dictionary] = assembly.graph.parts.duplicate(true)
	_check(panel.sources.size() == 1 and panel.pins.size() == 2, "wiring choices derive from the current graph")
	var disconnect: Button = panel.connections.get_child(0).get_child(1)
	disconnect.pressed.emit()
	_check(assembly.graph.links.size() == 2 and Wiring.pin_map(assembly.graph).is_empty(), "disconnect changes only electrical connectivity")
	panel.pin_choice.select(1)
	panel.pin_choice.item_selected.emit(1)
	panel.connect_button.pressed.emit()
	_check(Wiring.pin_map(assembly.graph).has(10) and not Wiring.pin_map(assembly.graph).has(9), "UI rewiring selects the actual board pin")
	_check(assembly.graph.parts == before, "wiring never moves or rotates any part")
	_check(not assembly.connect_wire(1, &"signal_pin", 3, &"pin_9"), "occupied signal cannot be silently reassigned")
	_check(not assembly.connect_wire(0, &"mount_top", 3, &"pin_9"), "mechanical ports cannot be wired")
	main.projects_button.grab_focus()
	await _history_key(false)
	_check(Wiring.pin_map(assembly.graph).is_empty(), "Ctrl+Z undoes wiring while a toolbar button has focus")
	await _history_key(true)
	_check(Wiring.pin_map(assembly.graph).has(10), "Ctrl+Shift+Z restores wiring while a button has focus")
	main.program_tabs.current_tab = 0
	await process_frame
	main.code_edit.grab_focus()
	await _history_key(false)
	_check(Wiring.pin_map(assembly.graph).has(10), "code-editor Undo cannot undo the assembly graph")
	root.gui_release_focus()
	await _history_key(false, true)
	_check(Wiring.pin_map(assembly.graph).is_empty(), "Command+Z supports browser users on macOS")
	await _history_key(true, true)
	_check(Wiring.pin_map(assembly.graph).has(10), "Command+Shift+Z restores wiring")
	assembly.select_part(assembly._part_nodes[3])
	_check(assembly.begin_transform(&"translate"), "board transform starts")
	assembly._constraint = &"X"
	assembly._numeric_input = "15"
	assembly._apply_transform()
	assembly.confirm_transform()
	_check(Wiring.pin_map(assembly.graph).has(10), "moving the board preserves the wire")
	_check(assembly.undo() and assembly.graph.parts == before, "transform undo restores placement and wiring together")
	assembly.select_part(assembly._part_nodes[1])
	assembly.begin_transform(&"translate")
	assembly._constraint = &"X"
	assembly._numeric_input = "12"
	assembly._apply_transform()
	_check(assembly.graph.links.size() == 1 and Wiring.pin_map(assembly.graph).has(10), "moving a servo detaches mechanical links but retains its wire")
	assembly.cancel_transform()
	_check(assembly.graph.links.size() == 3 and assembly.graph.parts == before, "cancel restores all mechanical links and transforms")
	assembly.select_part(assembly._part_nodes[3])
	assembly.begin_transform(&"translate")
	assembly._constraint = &"X"
	assembly._numeric_input = "200000"
	assembly._apply_transform()
	assembly.confirm_transform()
	_check(assembly.graph.parts == before, "out-of-range transforms cannot make a project unsavable")
	assembly.remove_part(assembly._part_nodes[3])
	_check(Wiring.pin_map(assembly.graph).is_empty() and assembly.graph.links.size() == 2, "deleting a board cleans its electrical links")
	_check(assembly.undo() and Wiring.pin_map(assembly.graph).has(10), "undo deletion restores wiring and board")
	var record: Dictionary = ProjectStore.document("Rewired arm", assembly.graph, "arm = Servo(10)\narm.write(35)")
	var imported: Dictionary = ProjectStore.parse(ProjectStore.serialize(record))
	_check(not imported.is_empty() and Wiring.pin_map(ProjectStore.graph_from(imported)).has(10), "JSON round-trip retains edited wiring")
	var directory: String = "user://core_authoring_%d" % OS.get_process_id()
	var saved: Dictionary = ProjectStore.save(record, directory)
	_check(saved.has("id") and ProjectStore.load_project(saved.id, directory) == imported, "saved snapshot retains graph and source")
	ProjectStore.remove(saved.id, directory)
	DirAccess.remove_absolute(directory)
	main._load_project(imported)
	_check(not main.mode_button.button_pressed and main.code_edit.text == record.source, "reopen restores learner code in edit mode")
	main.control_source.select(main.CONTROL_CODE)
	main.mode_button.button_pressed = true
	var drive: ServoDrive = main.run_mode.servo_on_pin(10)
	_check(drive != null and main.run_mode.servo_on_pin(9) == null, "rebuilt physics uses rewired graph addresses")
	main.runtime.failed.connect(func(line: int, message: String) -> void: _errors.append({"line": line, "message": message}))
	for invalid: String in ["arm = Servo(10)\narm.write(70)\ninvalid()", "arm = Servo(10)\narm.write(70)\nmissing.write(30)", "arm = Servo(10)\narm.write(70)\nother = Servo(9)", "arm = Servo(10)\narm.write(70)\nsleep(61)"]:
		var count: int = _errors.size()
		await main.runtime.run(invalid)
		_check(_errors.size() == count + 1 and _errors[-1].line == 3, "preflight identifies the failing line")
		_check(not drive.powered and drive.target_deg == 0.0 and not main.runtime.is_running(), "invalid programs send no partial motor command")
	_check(not main.runtime.validate("#".repeat(65537), false).is_empty(), "oversized source is rejected before execution")
	_check(not main.runtime.validate("\n".repeat(2048), false).is_empty(), "oversized line count is rejected before execution")
	await main.runtime.run(record.source)
	_check(drive.powered and drive.target_deg == 35.0, "valid code drives the newly selected pin")
	_check(not assembly.connect_wire(1, &"signal_pin", 3, &"pin_9"), "electrical editing is blocked during physics execution")
	_check(panel.source_choice.disabled and not panel.can_edit.call(), "wiring UI follows run-mode ownership")
	await _history_key(false)
	_check(Wiring.pin_map(assembly.graph).has(10), "history shortcuts cannot edit the graph during physics execution")
	main._ensure_assembly_mode()
	main.code_edit.text = "arm = Servo(10)\narm.write(35)"
	main.blocks.read_source(main.code_edit.text)
	main.blocks.instructions[1].args.angle = 45
	main.blocks.instructions[1].erase("raw")
	main.run_button.pressed.emit()
	_check(main.code_edit.text.ends_with("arm.write(45)"), "Run code applies the current block draft")
	_check(main.run_mode.servo_on_pin(10).target_deg == 45.0 and not main.blocks.has_draft(), "the visible block value reaches the actual motor")
	main._ensure_assembly_mode()
	main.code_edit.text = "arm = Servo(10)\narm.write(40)\ninvalid()"
	main.blocks.reset_source(main.code_edit.text)
	main.run_button.pressed.emit()
	_check(not main.mode_button.button_pressed, "invalid syntax leaves editing active without starting physics")
	main.blocks.read_source("arm = Servo(10)\narm.write(30)")
	main.blocks.instructions[1].args.angle = 20
	main.blocks.instructions[1].erase("raw")
	var code_before: String = main.code_edit.text
	main.run_button.pressed.emit()
	_check(main.code_edit.text == code_before and main.blocks.has_draft() and not main.mode_button.button_pressed, "code/block conflict preserves both drafts without running")
	main.blocks.reset_source(main.code_edit.text)
	main.program_tabs.current_tab = 3
	for locale: String in SsokLocale.LOCALES:
		SsokLocale.select_locale(locale, false)
		await process_frame
		_check(main.program_tabs.get_tab_title(3) == tr("Wiring"), "wiring tab translates in " + locale)
		_check(panel.sources.size() == 1 and panel.pins.size() == 2 and Wiring.pin_map(assembly.graph).has(10), "language switch retains wiring choices and graph")
		if "--screenshots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			for size: Vector2i in [Vector2i(1440, 900), Vector2i(960, 640)]:
				root.size = size
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var path: String = "user://core_authoring_previews/%s_%d.png" % [locale, size.x]
				DirAccess.make_dir_recursive_absolute(path.get_base_dir())
				root.get_texture().get_image().save_png(path)
	main.free()
	var capped := AssemblyMode.new()
	root.add_child(capped)
	var definition: PartDef = load("res://assets/parts/base.tres")
	_check(capped.spawn_part(definition, Transform3D(Basis.IDENTITY, Vector3(100.01, 0, 0))) == null and capped.graph.parts.is_empty(), "out-of-range spawn preserves the saveable workspace")
	var servo_def: PartDef = load("res://assets/parts/servo.tres")
	var boundary_base: PartNode = capped.spawn_part(definition, Transform3D(Basis.IDENTITY, Vector3(0, 100, 0)))
	var boundary_servo: PartNode = capped.spawn_part(servo_def, Transform3D(Basis.IDENTITY, Vector3(0, 99.98, 0)))
	_check(not capped.snap(boundary_servo, &"mount_bottom", boundary_base, &"mount_top") and capped.graph.links.is_empty(), "snap cannot move a part outside snapshot bounds")
	_check(not ProjectStore.document("Boundary workspace", capped.graph, "").is_empty(), "refused snap leaves both parts saveable")
	capped.remove_part(boundary_servo)
	capped.remove_part(boundary_base)
	for index: int in MotionSnapshot.MAX_PARTS:
		capped.spawn_part(definition, Transform3D(Basis.IDENTITY, Vector3(index * 0.01, 0, 0)))
	_check(capped.spawn_part(definition, Transform3D.IDENTITY) == null and capped.graph.parts.size() == 256, "adding beyond the project limit is refused")
	_check(not ProjectStore.document("Full workspace", capped.graph, "").is_empty(), "the full workspace remains saveable")
	capped.free()
	print("core_authoring_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)


func _history_key(redo: bool, command: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Z
	event.ctrl_pressed = not command
	event.meta_pressed = command
	event.shift_pressed = redo
	event.pressed = true
	root.push_input(event)
	await process_frame
	event.pressed = false
	root.push_input(event)
	await process_frame
