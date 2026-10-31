extends SceneTree

## Review repro: does the stage map move Play buttons after earlier stages are cleared
## (the state native_ui.ps1 reaches before clicking the next game_stage_* anchor)?


func _initialize() -> void:
	_run.call_deferred()


func _centers(router: Node) -> Dictionary:
	var result: Dictionary = {}
	for id: String in router.current.play_buttons:
		var button: Button = router.current.play_buttons[id]
		var center: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
		result[id] = [center.x, center.y, button.is_visible_in_tree()]
	return result


func _settle() -> void:
	for i: int in 4:
		await process_frame


func _run() -> void:
	root.size = Vector2i(1400, 950)
	root.gui_embed_subwindows = true
	SsokLocale.select_locale("en", false)
	StageProgress.path = "user://review-map-progress.json"
	DirAccess.remove_absolute(StageProgress.path)
	var router: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(router)
	await _settle()
	router.show_stages()
	await _settle()
	print("REVIEW fresh ", _centers(router))
	StageProgress.mark_cleared("raise-flag", true)
	router.show_stages()
	await _settle()
	print("REVIEW raise-flag cleared with solution ", _centers(router))
	StageProgress.mark_cleared("finish-line", true)
	router.show_stages()
	await _settle()
	print("REVIEW two cleared with solution ", _centers(router))
	DirAccess.remove_absolute(StageProgress.path)
	router.free()
	await _settle()
	quit()
