class_name WiringPanel
extends ScrollContainer

## Wiring as a to-do list: the first menu holds only the ports that still need a wire, the
## second the places each can go, and below them every wire reads as one line that can be
## disconnected. Ports are named for learners ("Power", "Pin 0"), not by their ids.

## Emitted when the learner flips the battery switch.
signal power_toggled(on: bool)

## Ports that feed other ports. Every wire runs from a port that needs something to one of these.
const PROVIDER_TAGS: Array[StringName] = [&"power_source", &"driver_output"]
const POWER_TAGS: Array[StringName] = [&"power_source", &"power_sink"]

var assembly: AssemblyMode
var can_edit: Callable
## Returns the electrical tier of the session; power ports are offered only from tier 1.
var power_tier: Callable
var source_choice: OptionButton
var pin_choice: OptionButton
var connect_button: Button
var power_switch: CheckButton
var needs_power: Label
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
	caption.text = "Connect what still needs a wire"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.label_settings = SsokTheme.title_settings()
	content.add_child(caption)
	var hint := Label.new()
	hint.text = "Pick a port, then where it connects. Wiring keeps your parts in place."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	source_choice = OptionButton.new()
	source_choice.fit_to_longest_item = false
	source_choice.clip_text = true
	source_choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	source_choice.tooltip_text = "Port to connect"
	source_choice.item_selected.connect(func(_index: int) -> void: _refresh_pins())
	content.add_child(source_choice)
	pin_choice = OptionButton.new()
	pin_choice.fit_to_longest_item = false
	pin_choice.clip_text = true
	pin_choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pin_choice.tooltip_text = "Connects to"
	pin_choice.item_selected.connect(func(_index: int) -> void: refresh_actions())
	content.add_child(pin_choice)
	connect_button = SsokTheme.button("Connect wire", "cpu")
	connect_button.pressed.connect(_connect_wire)
	content.add_child(connect_button)
	content.add_child(HSeparator.new())
	power_switch = CheckButton.new()
	power_switch.text = "Battery switch on"
	power_switch.button_pressed = true
	power_switch.toggled.connect(func(on: bool) -> void:
		power_toggled.emit(on)
		_refresh_power())
	content.add_child(power_switch)
	needs_power = Label.new()
	needs_power.name = "NeedsPower"
	needs_power.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	needs_power.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	needs_power.add_theme_color_override("font_color", SsokTheme.ERROR)
	content.add_child(needs_power)
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


static func is_power_port(port: Port) -> bool:
	return port.tag in POWER_TAGS


## Wiring choices that carry a signal, without the power cables.
func signal_sources() -> Array[Dictionary]:
	return sources.filter(func(endpoint: Dictionary) -> bool:
		return not is_power_port(_port_of(endpoint)))


func refresh() -> void:
	if not is_node_ready():
		return
	var selected: Dictionary = sources[source_choice.selected] if source_choice.selected >= 0 and source_choice.selected < sources.size() else {}
	sources.clear()
	source_choice.clear()
	var powered: bool = _uses_power()
	# Signal ports first, then power, and only the ones that still need a wire.
	for power: bool in [false, true]:
		if power and not powered:
			continue
		for index: int in assembly.graph.parts.size():
			for port: Port in assembly.graph.parts[index].part_def.ports:
				if port.kind != Port.Kind.ELEC or is_power_port(port) != power or _is_provider(port):
					continue
				if assembly._is_port_linked(index, port.id):
					continue
				var endpoint: Dictionary = {"part": index, "port": port.id}
				sources.append(endpoint)
				source_choice.add_item(_endpoint_label(endpoint))
				if endpoint == selected:
					source_choice.select(sources.size() - 1)
	if sources.is_empty():
		# The menu stays in place when nothing is left to wire, and says so.
		source_choice.add_item(tr("Everything is connected"))
		source_choice.set_item_disabled(0, true)
	_refresh_pins()
	for child: Node in connections.get_children():
		connections.remove_child(child)
		child.queue_free()
	var wires: int = 0
	for power: bool in [false, true]:
		for link: Dictionary in assembly.graph.links:
			var port: Port = Wiring._find_port(assembly.graph.parts[link.a_part].part_def, link.a_port)
			if port == null or port.kind != Port.Kind.ELEC or is_power_port(port) != power:
				continue
			wires += 1
			var row := HBoxContainer.new()
			connections.add_child(row)
			var label := Label.new()
			label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			label.text = _endpoint_label({"part": link.a_part, "port": link.a_port}) + " → " + _endpoint_label({"part": link.b_part, "port": link.b_port})
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var button: Button = SsokTheme.button("", "trash")
			button.tooltip_text = "Disconnect wire"
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.pressed.connect(func() -> void:
				if _can_edit():
					assembly.disconnect_wire(link))
			row.add_child(button)
	_empty.visible = sources.is_empty() and wires == 0
	_refresh_power()
	refresh_actions()


func _refresh_pins() -> void:
	var selected: Dictionary = pins[pin_choice.selected] if pin_choice.selected >= 0 and pin_choice.selected < pins.size() else {}
	pins.clear()
	pin_choice.clear()
	if source_choice.selected < 0 or source_choice.selected >= sources.size():
		refresh_actions()
		return
	var endpoint: Dictionary = sources[source_choice.selected]
	var source_port: Port = _port_of(endpoint)
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


## The battery switch and the list of parts that still have no power, from tier 1 only.
func _refresh_power() -> void:
	var has_battery: bool = false
	for part: Dictionary in assembly.graph.parts:
		if part.part_def.power_source_voltage > 0.0:
			has_battery = true
	power_switch.visible = has_battery
	needs_power.visible = false
	if not _uses_power():
		return
	var report: Dictionary = PowerNet.evaluate(assembly.graph, power_switch.button_pressed)
	var names: PackedStringArray = []
	for problem: Dictionary in report.problems:
		if problem.part >= 0:
			names.append("#%d %s" % [problem.part + 1, tr(assembly.graph.parts[problem.part].part_def.display_name)])
	if not report.problems.is_empty() and report.problems[0].code == PowerNet.NO_SOURCE:
		needs_power.text = tr("There is no battery. Add a battery holder and connect it to the board.")
	elif not report.problems.is_empty() and report.problems[0].code == PowerNet.SWITCH_OFF:
		needs_power.text = tr("The battery switch is off. Turn it on in the Wiring tab.")
	elif not names.is_empty():
		needs_power.text = tr("No power yet: %s") % ", ".join(names)
	else:
		return
	needs_power.visible = true


func _uses_power() -> bool:
	return power_tier.is_valid() and int(power_tier.call()) >= 1


func _connect_wire() -> void:
	refresh_actions()
	if connect_button.disabled:
		return
	var source: Dictionary = sources[source_choice.selected]
	var pin: Dictionary = pins[pin_choice.selected]
	assembly.connect_wire(source.part, source.port, pin.part, pin.port)


func _can_edit() -> bool:
	return can_edit.is_valid() and can_edit.call() and not assembly.transform_active


func _is_provider(port: Port) -> bool:
	return port.tag in PROVIDER_TAGS or Wiring.pin_number(port) >= 0


func _port_of(endpoint: Dictionary) -> Port:
	return Wiring._find_port(assembly.graph.parts[endpoint.part].part_def, endpoint.port)


func _endpoint_label(endpoint: Dictionary) -> String:
	var definition: PartDef = assembly.graph.parts[endpoint.part].part_def
	return "#%d %s / %s" % [endpoint.part + 1, tr(definition.display_name), port_name(endpoint.port)]


## A learner-facing name for a port id such as `pin_0`, `power_out_2` or `trig_pin`.
func port_name(id: StringName) -> String:
	var text: String = String(id)
	var number: String = text.get_slice("_", text.get_slice_count("_") - 1)
	var numbered: bool = number.is_valid_int()
	if text == "power_in":
		return tr("Power")
	if text == "power":
		return tr("Motor power")
	if text.begins_with("power_out"):
		return tr("Power out %s") % number if numbered else tr("Power out")
	if text in ["signal", "signal_pin"]:
		return tr("Signal")
	if text == "trig_pin":
		return tr("Trigger")
	if text == "echo_pin":
		return tr("Echo")
	if numbered and text.begins_with("pin_"):
		return tr("Pin %s") % number
	if numbered and text.begins_with("input_"):
		return tr("Input %s") % number
	if numbered and text.begins_with("motor_"):
		return tr("Motor output %s") % number
	return text


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		source_choice.tooltip_text = tr("Port to connect")
		pin_choice.tooltip_text = tr("Connects to")
		refresh()
