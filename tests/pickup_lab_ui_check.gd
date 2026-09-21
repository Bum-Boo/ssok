extends SceneTree

var _main: Node3D
var _checks: int = 0
var _failures: int = 0
var _saved_path: String = ""
var _saved_id: String = ""
var _saved_name: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1400, 950)
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	await process_frame
	_main.modular_button.pressed.emit()
	var fingerprint: String = MotionSnapshot.fingerprint(_main._motion_snapshot())
	var code: String = _main.code_edit.text
	_main.motion_lab_button.pressed.emit()
	var panel: PickupLabPanel = _main.pickup_lab
	_check(panel.visible and not _main.motion_lab.visible, "humanoid opens pickup lab instead of biped lab")
	_check(_main.assembly.graph.parts.size() > 38 and _main.motion_program is KitHumanoidMotion, "observable trials use elementary construction-kit assembly")
	_check(not _main.navigation.navigation_enabled, "lab blocks background navigation")
	_main.tutorial_button.pressed.emit()
	_check(not _main.tutorial.visible, "no modal stacking")
	panel.parallel_count.value = 1
	panel.rounds.value = 1
	panel.start_search()
	_check(panel._active and not panel.allow_paid.button_pressed, "local search starts without paid consent")
	_main._on_run_pressed()
	_check(not _main.runtime.is_running(), "learner program cannot start behind lab")
	var max_running: int = 0
	for frame: int in range(2600):
		await physics_frame
		if panel._completed_count >= 1:
			panel.parallel_count.value = 4
		max_running = maxi(max_running, panel._running_count())
		if frame % 90 == 0 and panel._running_count() > 1:
			await _capture("parallel")
		if not panel._active:
			break
	_check(not panel._active and panel._entries.size() == 5, "one baseline plus four completed candidates")
	_check(max_running == 4, "user can increase live parallelism to four worlds")
	_check(panel._server.is_empty() and panel.client._endpoint.is_empty(), "local search made no API connection")
	_check(MotionSnapshot.fingerprint(_main._motion_snapshot()) == fingerprint and _main.code_edit.text == code, "parallel trials preserve workshop assembly and learner code")
	var success_index: int = -1
	for index: int in range(panel._entries.size()):
		if panel._entries[index].result.metrics.success:
			success_index = index
	_check(success_index >= 0, "at least one real successful pickup is selectable")
	if success_index >= 0:
		panel._select_result(success_index)
		_check(panel._can_apply(), "fresh success eligible for exact graph")
		panel.name_edit.text = "ssok-ui-test-" + str(OS.get_process_id())
		_check(panel.save_selected(), "selected scenario is saved")
		var saved_path: String = panel.status_label.get_meta("localized_arguments", [""])[0]
		var saved_id: String = saved_path.get_file().get_basename()
		_saved_path = saved_path
		_saved_id = saved_id
		_saved_name = panel.name_edit.text
		var saved_index: int = -1
		for index: int in range(panel._saved.size()):
			if panel._saved[index].id == saved_id:
				saved_index = index
		_check(saved_index >= 0, "saved scenario appears in library")
		if saved_index >= 0:
			panel.saved_list.select(saved_index)
			_check(panel.load_selected() and not panel._can_apply(), "load never certifies saved metrics")
			panel.replay_selected()
			for frame: int in range(1000):
				await physics_frame
				if not panel._active:
					break
			_check(panel._selection.fresh and panel._selection.provider == "replay", "replay produces a fresh physics evaluation")
			_main.control_source.select(_main.CONTROL_CODE)
			_check(panel.apply_selected(), "verified replay policy applies explicitly")
			_check(_main.control_source.selected == _main.CONTROL_MANUAL and not _main.manual_controller.is_enabled(), "apply selects manual routine without auto-driving behind lab")
	for locale: String in ["ko", "zh_CN", "ja"]:
		SsokLocale.select_locale(locale, false)
		await process_frame
		await process_frame
		for tab: int in range(3):
			panel.tabs.current_tab = tab
			await process_frame
			await _capture(locale + "-tab-" + str(tab))
		panel.size = Vector2i(880, 600)
		panel.tabs.current_tab = 0
		await process_frame
		await process_frame
		var scroll: ScrollContainer = panel.tabs.get_child(0) as ScrollContainer
		_check(scroll.get_child(0).size.x <= scroll.size.x, locale + " compact controls do not overflow horizontally")
		await _capture(locale + "-compact")
		panel._reveal_results()
		await process_frame
		await process_frame
		_check(scroll.get_global_rect().encloses(panel.apply_button.get_global_rect()), locale + " compact result actions reachable without clipping")
		await _capture(locale + "-compact-results")
		panel.size = Vector2i(1240, 840)
	panel.tabs.current_tab = 0
	panel.parallel_count.value = 4
	panel.start_search()
	await process_frame
	panel.cancel_search()
	_check(not panel._active and panel._running_count() == 0, "cancellation stops all lanes")
	panel._close_panel()
	_check(not panel.visible and _main.navigation.navigation_enabled and not _main.manual_controller.is_enabled(), "closing restores navigation without auto-driving")
	if _saved_path.begins_with(PickupScenarioStore.DIRECTORY) and PickupScenarioStore.load_scenario(_saved_id).get("name") == _saved_name:
		_check(DirAccess.remove_absolute(_saved_path) == OK, "remove only this test's saved scenario")
	_main.free()
	await process_frame
	print("pickup_lab_ui_check: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _capture(name: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://pickup_lab_previews")
	_check(_main.pickup_lab.get_texture().get_image().save_png("user://pickup_lab_previews/" + name + ".png") == OK, "capture " + name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + message)
