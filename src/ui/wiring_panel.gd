class_name WiringPanel
extends ScrollContainer

var assembly: AssemblyMode
var can_edit: Callable
var source_choice: OptionButton
var pin_choice: OptionButton
var connect_button: Button
var connections: VBoxContainer
var sources: Array[Dictionary] = []
var pins: Array[Dictionary] = []
var _empty: Label
var _editable: bool = false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)
	var caption := Label.new()
	caption.text = "Connect a motor to a board pin"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.theme_type_variation = &"SectionLabel"
	content.add_child(caption)
	var hint := Label.new()
	hint.text = "Choose the motor signal and a compatible pin. Wiring keeps your parts in place."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	source_choice = OptionButton.new()
	source_choice.fit_to_longest_item = false
	source_choice.clip_text = true
	source_choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	source_choice.tooltip_text = "Motor signal"
	source_choice.item_selected.connect(func(_index: int) -> void: _refresh_pins())
	content.add_child(source_choice)
	pin_choice = OptionButton.new()
	pin_choice.fit_to_longest_item = false
	pin_choice.clip_text = true
	pin_choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pin_choice.tooltip_text = "Board pin"
	pin_choice.item_selected.connect(func(_index: int) -> void: refresh_actions())
	content.add_child(pin_choice)
	connect_button = SsokTheme.button("Connect wire", "cpu")
	connect_button.pressed.connect(_connect_wire)
	content.add_child(connect_button)
	content.add_child(HSeparator.new())
	connections = VBoxContainer.new()
	content.add_child(connections)
	_empty = Label.new()
	_empty.text = "Add a motor and a board to wire your robot."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_empty)
	assembly.graph_changed.connect(refresh)
	assembly.transform_active_changed.connect(func(_active: bool) -> void: refresh_actions())
	refresh()


func _process(_delta: float) -> void:
	if _editable != _can_edit():
		refresh_actions()


func refresh() -> void:
	if not is_node_ready():
		return
	var selected: Dictionary = sources[source_choice.selected] if source_choice.selected >= 0 and source_choice.selected < sources.size() else {}
	sources.clear()
	source_choice.clear()
	for index: int in assembly.graph.parts.size():
		var definition: PartDef = assembly.graph.parts[index].part_def
		for port: Port in definition.ports:
			if port.kind == Port.Kind.ELEC and Wiring.pin_number(port) < 0:
				var endpoint: Dictionary = {"part": index, "port": port.id}
				sources.append(endpoint)
				source_choice.add_item(_endpoint_label(endpoint))
				if endpoint == selected:
					source_choice.select(sources.size() - 1)
	_refresh_pins()
	for child: Node in connections.get_children():
		connections.remove_child(child)
		child.queue_free()
	for link: Dictionary in assembly.graph.links:
		var port: Port = Wiring._find_port(assembly.graph.parts[link.a_part].part_def, link.a_port)
		if port == null or port.kind != Port.Kind.ELEC:
			continue
		var row := VBoxContainer.new()
		connections.add_child(row)
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = _endpoint_label({"part": link.a_part, "port": link.a_port}) + " → " + _endpoint_label({"part": link.b_part, "port": link.b_port})
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var button: Button = SsokTheme.button("Disconnect wire", "square")
		button.pressed.connect(func() -> void:
			if _can_edit():
				assembly.disconnect_wire(link))
		row.add_child(button)
	_empty.visible = sources.is_empty() or pins.is_empty()
	refresh_actions()


func _refresh_pins() -> void:
	var selected: Dictionary = pins[pin_choice.selected] if pin_choice.selected >= 0 and pin_choice.selected < pins.size() else {}
	pins.clear()
	pin_choice.clear()
	_empty.visible = true
	if source_choice.selected < 0 or source_choice.selected >= sources.size():
		refresh_actions()
		return
	var endpoint: Dictionary = sources[source_choice.selected]
	var source_port: Port = Wiring._find_port(assembly.graph.parts[endpoint.part].part_def, endpoint.port)
	for index: int in assembly.graph.parts.size():
		if index == endpoint.part:
			continue
		for port: Port in assembly.graph.parts[index].part_def.ports:
			if port.kind != Port.Kind.ELEC or not assembly._ports_accept(source_port, port):
				continue
			var pin: Dictionary = {"part": index, "port": port.id}
			pins.append(pin)
			pin_choice.add_item(_endpoint_label(pin))
			pin_choice.set_item_disabled(pins.size() - 1, assembly._is_port_linked(index, port.id))
			if pin == selected:
				pin_choice.select(pins.size() - 1)
	if pin_choice.selected >= 0 and pin_choice.is_item_disabled(pin_choice.selected):
		for index: int in pins.size():
			if not pin_choice.is_item_disabled(index):
				pin_choice.select(index)
				break
	_empty.visible = pins.is_empty()
	refresh_actions()


func refresh_actions() -> void:
	if connect_button == null:
		return
	_editable = _can_edit()
	source_choice.disabled = not _editable or sources.is_empty()
	pin_choice.disabled = not _editable or pins.is_empty()
	var available: bool = source_choice.selected >= 0 and source_choice.selected < sources.size() and pin_choice.selected >= 0 and pin_choice.selected < pins.size()
	if available:
		var source: Dictionary = sources[source_choice.selected]
		var pin: Dictionary = pins[pin_choice.selected]
		available = not assembly._is_port_linked(source.part, source.port) and not assembly._is_port_linked(pin.part, pin.port)
	connect_button.disabled = not _editable or not available
	for row: Node in connections.get_children():
		for child: Node in row.get_children():
			if child is Button:
				child.disabled = not _editable


func _connect_wire() -> void:
	refresh_actions()
	if connect_button.disabled:
		return
	var source: Dictionary = sources[source_choice.selected]
	var pin: Dictionary = pins[pin_choice.selected]
	assembly.connect_wire(source.part, source.port, pin.part, pin.port)


func _can_edit() -> bool:
	return can_edit.is_valid() and can_edit.call() and not assembly.transform_active


func _endpoint_label(endpoint: Dictionary) -> String:
	var definition: PartDef = assembly.graph.parts[endpoint.part].part_def
	return "#%d %s / %s" % [endpoint.part + 1, tr(definition.display_name), endpoint.port]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		source_choice.tooltip_text = tr("Motor signal")
		pin_choice.tooltip_text = tr("Board pin")
		refresh()
