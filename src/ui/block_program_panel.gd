class_name BlockProgramPanel
extends VBoxContainer

signal source_requested
var apply_source: Callable

var profile: BoardProfile = BoardProfile.new()
var instructions: Array = []
var rows: VBoxContainer
var operation_picker: OptionButton
var feedback: Label
var _source_at_load: String = ""
var _instructions_at_load: Array = []
var _read_confirmation: ConfirmationDialog
var scroll: ScrollContainer


func _ready() -> void:
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var caption := Label.new()
	caption.text = "Build a program with blocks"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(caption)
	var read_button: Button = SsokTheme.button("Read from code", "code-xml")
	read_button.pressed.connect(_request_read)
	content.add_child(read_button)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(rows)
	var add_row := HBoxContainer.new()
	content.add_child(add_row)
	operation_picker = OptionButton.new()
	operation_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for descriptor: Dictionary in profile.api:
		operation_picker.add_item(descriptor.label)
	add_row.add_child(operation_picker)
	var add_button: Button = SsokTheme.button("+", "")
	add_button.tooltip_text = "Add block"
	add_button.pressed.connect(_add_block)
	add_row.add_child(add_button)
	var apply_button: Button = SsokTheme.button("Apply blocks to code", "code-xml")
	apply_button.pressed.connect(_apply)
	content.add_child(apply_button)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 12)
	feedback.max_lines_visible = 2
	feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(feedback)
	_read_confirmation = ConfirmationDialog.new()
	_read_confirmation.title = "Keep your changes?"
	_read_confirmation.dialog_text = "Replace unapplied blocks with the current code?"
	_read_confirmation.confirmed.connect(func() -> void: source_requested.emit())
	add_child(_read_confirmation)


func has_draft() -> bool:
	return instructions != _instructions_at_load


func _request_read() -> void:
	if has_draft():
		_read_confirmation.popup_centered()
	else:
		source_requested.emit()


func read_source(source: String) -> bool:
	var result: Dictionary = ServoProgram.parse(source, profile)
	if result.has("error"):
		SsokLocale.bind(feedback, result.error)
		return false
	_source_at_load = source
	instructions = result.instructions
	_instructions_at_load = instructions.duplicate(true)
	_rebuild()
	SsokLocale.bind(feedback, "Blocks are ready. Apply them to update the code; Run code starts the robot.")
	return true


func reset_source(source: String) -> void:
	instructions.clear()
	_instructions_at_load.clear()
	_source_at_load = ""
	_rebuild()
	read_source(source)


func _add_block() -> void:
	var item: Dictionary = profile.defaults(profile.api[operation_picker.selected].id)
	instructions.append(item)
	if item.op in ["if", "while"]:
		instructions.append({"op": "raw", "raw": "    pass", "indent": 4})
	_rebuild()


func _rebuild() -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for index: int in instructions.size():
		var item: Dictionary = instructions[index]
		if item.op == "raw":
			if not item.raw.strip_edges().is_empty() and not item.raw.strip_edges().begins_with("#") and not item.raw.begins_with("from "):
				var code := Label.new()
				code.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				code.text = tr("Code block") + "\n" + item.raw
				code.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				rows.add_child(code)
			continue
		var card := VBoxContainer.new()
		rows.add_child(card)
		var heading := HBoxContainer.new()
		card.add_child(heading)
		var label := Label.new()
		label.text = "    ".repeat(int(item.get("indent", 0)) / 4) + tr(profile.operation(item.op).label)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(label)
		var remove_button: Button = SsokTheme.button("", "trash")
		remove_button.tooltip_text = "Remove block"
		remove_button.pressed.connect(func() -> void:
			instructions.remove_at(index)
			_rebuild())
		heading.add_child(remove_button)
		for parameter: Dictionary in profile.operation(item.op).arguments:
			var row := HBoxContainer.new()
			card.add_child(row)
			var name_label := Label.new()
			name_label.text = parameter.name
			name_label.custom_minimum_size.x = 80
			row.add_child(name_label)
			if parameter.type == "choice":
				var picker := OptionButton.new()
				for option: String in parameter.choices:
					picker.add_item(option)
				picker.select(parameter.choices.find(item.args[parameter.name]))
				picker.item_selected.connect(func(selected: int) -> void:
					item.args[parameter.name] = parameter.choices[selected]
					item.erase("raw"))
				row.add_child(picker)
			elif parameter.type in ["identifier", "expression"]:
				var edit := LineEdit.new()
				edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				edit.text = item.args[parameter.name]
				edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				edit.text_changed.connect(func(value: String) -> void:
					item.args[parameter.name] = value
					item.erase("raw"))
				row.add_child(edit)
			elif parameter.type == "number":
				var edit := LineEdit.new()
				edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				edit.text = str(item.args[parameter.name])
				edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
				edit.text_changed.connect(func(value: String) -> void:
					item.args[parameter.name] = float(value) if value.is_valid_float() else value
					item.erase("raw"))
				row.add_child(edit)
			else:
				var edit := SpinBox.new()
				edit.min_value = parameter.min
				edit.max_value = parameter.max
				edit.step = 1
				edit.value = item.args[parameter.name]
				edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				edit.value_changed.connect(func(value: float) -> void:
					item.args[parameter.name] = value
					item.erase("raw"))
				row.add_child(edit)


func _apply() -> bool:
	var result: Dictionary = ServoProgram.generate(instructions, profile)
	if result.has("error"):
		SsokLocale.bind(feedback, result.error)
		return false
	if apply_source.is_valid() and not apply_source.call(result.source):
		return false
	_source_at_load = result.source
	_instructions_at_load = instructions.duplicate(true)
	SsokLocale.bind(feedback, "Code updated. Run code to try your program.")
	return true


func set_profile(value: BoardProfile) -> void:
	profile = value
	operation_picker.clear()
	for descriptor: Dictionary in profile.api:
		operation_picker.add_item(tr(descriptor.label))
