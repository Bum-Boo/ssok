class_name ProjectPanel
extends Window

signal panel_closed
signal project_saved(record: Dictionary)
signal project_loaded(record: Dictionary)

var title_edit: LineEdit
var library: ItemList
var transfer_edit: TextEdit
var message: Label
var tabs: TabContainer
var save_button: Button
var open_button: Button
var delete_button: Button
var import_button: Button
var _read_document: Callable
var _prepare_document: Callable
var _records: Array[Dictionary] = []
var _confirmation: ConfirmationDialog
var _pending: Dictionary = {}
var _delete_id: String = ""
var _empty_library: Label
var _dialog_panel: StyleBoxFlat


func configure(read_document: Callable, prepare_document: Callable = Callable()) -> void:
	_read_document = read_document
	_prepare_document = prepare_document


func _ready() -> void:
	title = "Projects"
	visible = false
	exclusive = true
	transient = true
	unresizable = true
	min_size = Vector2i(640, 450)
	size = Vector2i(760, 520)
	close_requested.connect(close_panel)
	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	# Enlarged or translated text scrolls above a fixed footer so Close stays reachable.
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.follow_focus = true
	layout.add_child(body_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(body)
	var heading := Label.new()
	heading.text = "Keep building. Pick up where you left off."
	heading.label_settings = SsokTheme.title_settings()
	body.add_child(heading)
	var note := Label.new()
	note.text = "Saved on this device. Export a copy before clearing browser data or changing devices."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var block_note := Label.new()
	block_note.text = "Saving or exporting applies valid blocks to your code."
	block_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(block_note)
	title_edit = LineEdit.new()
	title_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_edit.placeholder_text = tr("Project name")
	title_edit.max_length = 80
	body.add_child(title_edit)
	var save_row: HFlowContainer = _action_row()
	body.add_child(save_row)
	save_button = _full_label(SsokTheme.button("Save a snapshot", "save"))
	save_button.pressed.connect(save_current)
	save_row.add_child(save_button)
	var export_button: Button = _full_label(SsokTheme.button("Export project", "download"))
	export_button.pressed.connect(export_current)
	save_row.add_child(export_button)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	var saved := VBoxContainer.new()
	saved.name = "Saved projects"
	tabs.add_child(saved)
	library = ItemList.new()
	library.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	library.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library.custom_minimum_size.y = 96
	library.item_selected.connect(func(_index: int) -> void: _refresh_actions())
	library.item_activated.connect(func(_index: int) -> void: request_open())
	saved.add_child(library)
	_empty_library = Label.new()
	_empty_library.text = "No saved projects yet. Save your first snapshot above."
	_empty_library.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	saved.add_child(_empty_library)
	var actions: HFlowContainer = _action_row()
	saved.add_child(actions)
	open_button = _full_label(SsokTheme.button("Open selected", "folder-open"))
	open_button.pressed.connect(request_open)
	actions.add_child(open_button)
	delete_button = _full_label(SsokTheme.button("Delete snapshot", "trash"))
	delete_button.pressed.connect(request_delete)
	actions.add_child(delete_button)
	var transfer := VBoxContainer.new()
	transfer.name = "Import / export"
	tabs.add_child(transfer)
	var instructions := Label.new()
	instructions.text = "Copy this project JSON to share it, or paste a project here to import. Imported code never runs automatically."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transfer.add_child(instructions)
	transfer_edit = TextEdit.new()
	transfer_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	transfer_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transfer_edit.custom_minimum_size.y = 96
	transfer.add_child(transfer_edit)
	var transfer_actions: HFlowContainer = _action_row()
	transfer.add_child(transfer_actions)
	var copy_button: Button = _full_label(SsokTheme.button("Copy JSON", "copy"))
	copy_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(transfer_edit.text)
		_status("Project JSON copied."))
	transfer_actions.add_child(copy_button)
	import_button = _full_label(SsokTheme.button("Import project", "upload"))
	import_button.pressed.connect(request_import)
	transfer_actions.add_child(import_button)
	var footer := HBoxContainer.new()
	layout.add_child(footer)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(message)
	var close_button: Button = _full_label(SsokTheme.button("Close"))
	close_button.pressed.connect(close_panel)
	footer.add_child(close_button)
	_confirmation = ConfirmationDialog.new()
	_confirmation.theme = theme
	_confirmation.title = "Confirm project action"
	_confirmation.dialog_autowrap = true
	# SsokTheme defines no AcceptDialog panel; use this window's surface so body text follows the palette.
	_dialog_panel = StyleBoxFlat.new()
	_dialog_panel.bg_color = SsokTheme.BG
	_dialog_panel.set_content_margin_all(12)
	_confirmation.add_theme_stylebox_override("panel", _dialog_panel)
	_confirmation.confirmed.connect(_confirm_action)
	add_child(_confirmation)
	_refresh_actions()


func open_panel() -> void:
	var record: Dictionary = _read_document.call()
	title_edit.text = record.get("title", "")
	refresh_library()
	_status("Save creates a new snapshot; earlier versions are kept.")
	var available: Vector2i = _available_size()
	popup_centered(Vector2i(mini(roundi(760 * SsokTheme.ui_scale), available.x), mini(roundi(520 * SsokTheme.ui_scale), available.y)))
	title_edit.grab_focus()


func close_panel() -> void:
	hide()
	panel_closed.emit()


func _input(event: InputEvent) -> void:
	if visible and not _confirmation.visible and event.is_action_pressed("ui_cancel"):
		set_input_as_handled()
		close_panel()


func save_current() -> void:
	var record: Dictionary = _current()
	if record.has("error"):
		_status(record.error, true)
		return
	var result: Dictionary = ProjectStore.save(record)
	if result.has("error"):
		_status(result.error, true)
		return
	refresh_library()
	project_saved.emit(record)
	_status("Project saved. Your previous snapshots are still available.")


func export_current() -> void:
	var record: Dictionary = _current()
	if record.has("error"):
		_status(record.error, true)
		return
	var text: String = ProjectStore.serialize(record)
	if text.is_empty():
		_status("Project data is invalid or too large.", true)
		return
	transfer_edit.text = text
	tabs.current_tab = 1
	transfer_edit.select_all()
	transfer_edit.grab_focus()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), "ssok-project.json", "application/json")
	_status("Project JSON is ready. Keep a copy outside this device.")


func request_open() -> void:
	var selected: PackedInt32Array = library.get_selected_items()
	if selected.is_empty():
		return
	_pending = ProjectStore.load_project(_records[selected[0]].id)
	_request_replace()


func request_import() -> void:
	_pending = ProjectStore.parse(transfer_edit.text)
	_request_replace()


func _request_replace() -> void:
	if _pending.is_empty():
		_status("This is not a valid ssok project. Your current work is unchanged.", true)
		return
	_delete_id = ""
	_confirmation.dialog_text = "Replace the current assembly and code? Save a snapshot first if you want to keep them."
	_popup_confirmation()


func request_delete() -> void:
	var selected: PackedInt32Array = library.get_selected_items()
	if selected.is_empty():
		return
	_delete_id = _records[selected[0]].id
	_pending = {}
	_confirmation.dialog_text = "Delete this saved snapshot? Other snapshots and your open project are kept."
	_popup_confirmation()


func _confirm_action() -> void:
	if not _delete_id.is_empty():
		var error: Error = ProjectStore.remove(_delete_id)
		_delete_id = ""
		refresh_library()
		_status("Snapshot deleted." if error == OK else "Could not delete this snapshot.", error != OK)
	elif not _pending.is_empty():
		var record: Dictionary = _pending
		_pending = {}
		project_loaded.emit(record)
		close_panel()


func refresh_library() -> void:
	_records = ProjectStore.list_projects()
	library.clear()
	_empty_library.visible = _records.is_empty()
	for item: Dictionary in _records:
		library.add_item("%s  ·  %s UTC" % [item.record.title, item.record.saved_utc.replace("T", " ")])
	_refresh_actions()


func _refresh_actions() -> void:
	if open_button != null:
		open_button.disabled = library.get_selected_items().is_empty()
		delete_button.disabled = open_button.disabled


func _current() -> Dictionary:
	var record: Dictionary = _prepare_document.call() if _prepare_document.is_valid() else _read_document.call()
	if record.has("error"):
		return record
	record["title"] = title_edit.text.strip_edges()
	return record


func _status(source: String, error: bool = false) -> void:
	SsokLocale.bind(message, source)
	message.modulate = Color("ff9292") if error else Color.WHITE


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		title_edit.placeholder_text = tr("Project name")
		tabs.set_tab_title(0, tr("Saved projects"))
		tabs.set_tab_title(1, tr("Import / export"))
	elif what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_sync_dialog_panel()


func _action_row() -> HFlowContainer:
	# Actions wrap to another line instead of compressing labels at large text sizes.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	return row


func _full_label(button: Button) -> Button:
	# SsokTheme.button lets labels shrink to an ellipsis; these actions must keep their whole label.
	button.clip_text = false
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return button


func _available_size() -> Vector2i:
	# Embedded titles sit above the centered content rect, so reserve one title height on each side.
	var area := Vector2i(get_tree().root.get_visible_rect().size)
	return area - Vector2i(32, 2 * SsokTheme.font_size(36) + 16)


func _popup_confirmation() -> void:
	_sync_dialog_panel()
	# A fixed width lets the wrapped body grow downward within the screen.
	_confirmation.popup_centered(Vector2i(mini(SsokTheme.font_size(420), _available_size().x), 0))


func _sync_dialog_panel() -> void:
	# The shared remember/adapt pass is not known to reach this Window override, so read the live palette here.
	# Skipping equal colors avoids a redundant stylebox change notification.
	if _dialog_panel.bg_color != SsokTheme.BG:
		_dialog_panel.bg_color = SsokTheme.BG
