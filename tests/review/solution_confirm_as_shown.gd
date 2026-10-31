extends SceneTree

## Review repro: where does the real app show the stage "Show solution" confirmation OK button,
## without the layout tool's resize/re-centering? Compare against game_confirm_* anchors.


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _run() -> void:
	root.size = Vector2i(1400, 950)
	root.gui_embed_subwindows = true
	SsokLocale.select_locale("en", false)
	StageProgress.path = "user://review-confirm-progress.json"
	DirAccess.remove_absolute(StageProgress.path)
	var router: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(router)
	await _frames(5)
	router.start_stage("raise-flag")
	for i: int in 200:
		await process_frame
		if router.current is Node3D and router.current.session.get("mode") == "stage":
			break
	await _frames(5)
	var workshop: Node3D = router.current
	workshop.stage_hud.solution_requested.emit()
	var dialog: ConfirmationDialog = workshop._stage_replace_dialog
	for checkpoint: int in [1, 3, 10, 60]:
		await _frames(checkpoint)
		var ok: Button = dialog.get_ok_button()
		var center: Vector2 = ok.get_global_transform_with_canvas() * (ok.size * 0.5) + Vector2(dialog.position)
		print("REVIEW +%d frames dialog pos=%s size=%s ok_center=%s ok_size=%s" % [checkpoint, dialog.position, dialog.size, center, ok.size])
	DirAccess.remove_absolute(StageProgress.path)
	router.free()
	await _frames(3)
	quit()
