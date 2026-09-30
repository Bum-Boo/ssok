class_name StagePanel
extends VBoxContainer

signal stage_requested(stage: Dictionary)
signal lab_requested

var assembly: AssemblyMode
var run_mode: RunMode
var source: Callable
var pending_blocks: Callable
var evaluator: StageEvaluator = StageEvaluator.new()
var current: Dictionary = {}
var _catalog: Array[Dictionary] = []
var _picker: OptionButton
var _status: Label
var _transfer: TextEdit
var _title: LineEdit
var _target: OptionButton
var _metric: OptionButton
var _minimum: SpinBox
var _maximum: SpinBox
var _hold: SpinBox
var _authoring: bool = false
var _observing: bool = false
var _run_fingerprint: String = ""
var _proof_fingerprint: String = ""


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var heading := Label.new()
	heading.text = "Stages and free building"
	content.add_child(heading)
	_picker = OptionButton.new()
	_catalog = StageCatalog.builtins()
	for stage: Dictionary in _catalog:
		_picker.add_item(stage.title)
	content.add_child(_picker)
	var load_button: Button = SsokTheme.button("Load challenge", "play")
	load_button.pressed.connect(func() -> void: stage_requested.emit(_catalog[_picker.selected]))
	content.add_child(load_button)
	var answer_button: Button = SsokTheme.button("Try author solution", "code-xml")
	answer_button.pressed.connect(func() -> void:
		var stage: Dictionary = current if not current.is_empty() else _catalog[_picker.selected]
		var example: Dictionary = stage.duplicate(true)
		example.scene = example.author_solution.duplicate(true)
		stage_requested.emit(example))
	content.add_child(answer_button)
	var lab_button: Button = SsokTheme.button("Free building · Lab", "code-xml")
	lab_button.pressed.connect(func() -> void:
		clear_goal()
		lab_requested.emit())
	content.add_child(lab_button)
	_status = Label.new()
	_status.text = "Choose a challenge, or build freely in Lab."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	content.add_child(HSeparator.new())
	_title = LineEdit.new()
	_title.placeholder_text = "My challenge"
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	content.add_child(_title)
	_target = OptionButton.new()
	_target.fit_to_longest_item = false
	_target.clip_text = true
	content.add_child(_target)
	_metric = OptionButton.new()
	for label: String in ["Height (m)", "Position X (m)", "Distance (cm)", "Speed (m/s)", "Upright", "Wall contact (0 or 1)"]:
		_metric.add_item(label)
	content.add_child(_metric)
	_minimum = _number(content, "Minimum", 0, -100, 100)
	_maximum = _number(content, "Maximum", 1, -100, 100)
	_hold = _number(content, "Hold (seconds)", 1, 0, 60)
	var author: Button = SsokTheme.button("Turn my build into a challenge", "play")
	author.pressed.connect(_author)
	content.add_child(author)
	_transfer = TextEdit.new()
	_transfer.custom_minimum_size.y = 110
	_transfer.placeholder_text = "Paste a challenge file here"
	_transfer.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	content.add_child(_transfer)
	var export_button: Button = SsokTheme.button("Export verified challenge", "copy")
	export_button.pressed.connect(_export)
	content.add_child(export_button)
	var import_button: Button = SsokTheme.button("Import challenge", "copy")
	import_button.pressed.connect(func() -> void:
		var stage: Dictionary = StageDefinition.parse(_transfer.text)
		if stage.is_empty():
			SsokLocale.bind(_status, "Challenge data is invalid. Your build is unchanged.")
		else:
			stage_requested.emit(stage))
	content.add_child(import_button)
	assembly.graph_changed.connect(_refresh_targets)
	_refresh_targets()
	_title.placeholder_text = tr("My challenge")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
		_title.placeholder_text = tr("My challenge")


func _number(parent: VBoxContainer, label: String, value: float, minimum: float, maximum: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = 0.01
	field.value = value
	row.add_child(field)
	return field


func _refresh_targets() -> void:
	_target.clear()
	var ids: Array[String] = []
	for part: Dictionary in assembly.graph.parts:
		var id: String = part.part_def.id
		if id not in ids:
			ids.append(id)
			_target.add_item(part.part_def.display_name)
			_target.set_item_metadata(_target.item_count - 1, id)
	_proof_fingerprint = ""


func load_goal(stage: Dictionary) -> void:
	current = stage.duplicate(true)
	for index: int in _catalog.size():
		if _catalog[index].id == current.id:
			_picker.select(index)
			break
	evaluator.configure(current)
	_authoring = false
	_observing = false
	_proof_fingerprint = ""
	SsokLocale.bind(_status, "Build your own solution. Success uses measured results.")


func clear_goal() -> void:
	current.clear()
	evaluator.configure({})
	_observing = false
	_proof_fingerprint = ""
	SsokLocale.bind(_status, "Lab: build freely. You can turn your build into a challenge.")


func on_run() -> void:
	if current.is_empty():
		return
	evaluator.reset()
	_run_fingerprint = StageDefinition.fingerprint(current, assembly.graph, source.call())
	_proof_fingerprint = ""
	_observing = true
	SsokLocale.bind(_status, "Challenge running. Watching the real robot.")


func on_stop() -> void:
	_observing = false


func _physics_process(delta: float) -> void:
	if not _observing or not run_mode.is_built():
		return
	evaluator.observe(run_mode, assembly.graph, delta)
	if evaluator.success:
		_observing = false
		_proof_fingerprint = _run_fingerprint
		SsokLocale.bind(_status, "Challenge cleared. Change your build and try another solution.")
	elif evaluator.expired:
		_observing = false
		SsokLocale.bind(_status, "Time is up. Change your build or code and try again.")


func _author() -> void:
	if pending_blocks.is_valid() and pending_blocks.call():
		SsokLocale.bind(_status, "Blocks are ready. Apply them to update the code; Run code starts the robot.")
		return
	if run_mode.is_built() or _target.selected < 0:
		SsokLocale.bind(_status, "Return to edit mode and choose a target part first.")
		return
	var rule: Dictionary = StageDefinition.rule(StageDefinition.METRICS[_metric.selected], _target.get_item_metadata(_target.selected), _minimum.value, _maximum.value, _hold.value)
	var stage: Dictionary = StageDefinition.create("local-challenge", _title.text, assembly.graph, source.call(), [rule])
	if stage.is_empty():
		SsokLocale.bind(_status, "Challenge data is invalid. Your build is unchanged.")
		return
	load_goal(stage)
	_authoring = true
	SsokLocale.bind(_status, "Run and clear your challenge before exporting it.")


func _export() -> bool:
	if current.is_empty() or _proof_fingerprint.is_empty() or (pending_blocks.is_valid() and pending_blocks.call()) or _proof_fingerprint != StageDefinition.fingerprint(current, assembly.graph, source.call()):
		SsokLocale.bind(_status, "Run and clear this exact build and code before exporting.")
		return false
	var stage: Dictionary = current.duplicate(true)
	stage.author_solution = ProjectStore.document(stage.title, assembly.graph, source.call())
	_transfer.text = StageDefinition.serialize(stage)
	_transfer.select_all()
	_transfer.grab_focus()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(_transfer.text.to_utf8_buffer(), "ssok-challenge.json", "application/json")
	SsokLocale.bind(_status, "Challenge exported. Imported files must be tested again.")
	return true
