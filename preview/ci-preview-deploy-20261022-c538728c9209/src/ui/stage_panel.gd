class_name StagePanel
extends VBoxContainer

signal stage_requested(stage: Dictionary)
signal lab_requested
signal outcome_changed(message: String)
signal attempt_terminated

var assembly: AssemblyMode
var run_mode: RunMode
var source: Callable
var pending_blocks: Callable
var context_provider: Callable
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
var _run_context: Dictionary = {}
var _resource_identity: Dictionary = {}
var _challenge_controls: Array[Control] = []


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
	_challenge_controls = [heading, _picker, load_button, answer_button, lab_button]
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


## Free building reaches challenges from the stage menu, so only authoring stays here.
func set_lab_only(value: bool) -> void:
	for control: Control in _challenge_controls:
		control.visible = not value


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
	for index: int in assembly.graph.parts.size():
		var part: Dictionary = assembly.graph.parts[index]
		_target.add_item("%s #%d" % [tr(part.part_def.display_name), index + 1])
		_target.set_item_metadata(_target.item_count - 1, index)
	_proof_fingerprint = ""


func load_goal(stage: Dictionary) -> void:
	current = stage.duplicate(true)
	for index: int in _catalog.size():
		if _catalog[index].id == current.id:
			_picker.select(index)
			break
	evaluator.configure(current, assembly.graph)
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


func _context() -> Dictionary:
	var context: Dictionary = context_provider.call() if context_provider.is_valid() else StageDefinition.runtime_context(run_mode, assembly.graph, _resource_identity)
	_resource_identity = context.resources
	if not run_mode.is_built() and not _run_context.is_empty():
		context.sensor_conditions = _run_context.sensor_conditions.duplicate(true)
	return context


func on_run() -> bool:
	if current.is_empty():
		return true
	_proof_fingerprint = ""
	_observing = false
	if not evaluator.start(assembly.graph):
		_show_result()
		return false
	# Resolve graph-wired goal sensors before freezing the execution context.
	for index: int in current.rules.size():
		if current.rules[index].metric == "sonar_distance":
			run_mode.sonar_for_part(evaluator.resolve_target(index, assembly.graph).index)
	_run_context = _context()
	_run_fingerprint = StageDefinition.fingerprint(current, assembly.graph, source.call(), _run_context)
	_observing = true
	SsokLocale.bind(_status, "Challenge running. Watching the real robot.")
	return true


func on_stop() -> void:
	if _observing:
		evaluator.finish("cancelled", "user_stop")
		_proof_fingerprint = ""
		_show_result()
	_observing = false


func on_program_error() -> void:
	if _observing:
		evaluator.finish("not_met", "program_error")
		_observing = false
		_proof_fingerprint = ""
		_show_result()


func _show_result() -> void:
	var message: String = "This attempt could not be judged. Return to edit mode and try again."
	match evaluator.reason:
		"target_ambiguous": message = "Several parts match this goal. Choose one target when creating the challenge."
		"target_missing", "target_changed": message = "The target part changed or was removed. Choose it again and recreate the challenge."
		"part_limit": message = "This build exceeds the challenge part limit. Remove parts and try again."
		"time_limit": message = "Time is up. Change your build or code and try again."
		"program_error": message = "The program stopped with an error. Fix the highlighted code and try again."
		"sensor_missing", "sensor_unavailable": message = "The target sensor is unavailable. Check its wiring and try again."
		"user_stop": message = "Attempt stopped. Your build and code are kept."
		"program_finished": message = "The program ended before the goal was met. Change it and try again."
	SsokLocale.bind(_status, message)
	outcome_changed.emit(message)


func _physics_process(delta: float) -> void:
	if not _observing:
		return
	# Check the execution contract before observing; a changed goal cannot certify old results.
	if StageDefinition.fingerprint(current, assembly.graph, source.call(), _context()) != _run_fingerprint:
		evaluator.finish("indeterminate", "execution_changed")
	else:
		evaluator.observe(run_mode, assembly.graph, delta)
	if evaluator.success:
		_observing = false
		_proof_fingerprint = _run_fingerprint
		SsokLocale.bind(_status, "Challenge cleared. Change your build and try another solution.")
		outcome_changed.emit("Challenge cleared. Change your build and try another solution.")
	elif evaluator.status != "running":
		_observing = false
		_proof_fingerprint = ""
		_show_result()
		attempt_terminated.emit()


func _author() -> void:
	if pending_blocks.is_valid() and pending_blocks.call():
		SsokLocale.bind(_status, "Blocks are ready. Apply them to update the code; Run code starts the robot.")
		return
	if run_mode.is_built() or _target.selected < 0:
		SsokLocale.bind(_status, "Return to edit mode and choose a target part first.")
		return
	var target_index: int = _target.get_item_metadata(_target.selected)
	var rule: Dictionary = StageDefinition.rule(StageDefinition.METRICS[_metric.selected], String(assembly.graph.parts[target_index].part_def.id), _minimum.value, _maximum.value, _hold.value, target_index)
	var stage: Dictionary = StageDefinition.create("local-challenge", _title.text, assembly.graph, source.call(), [rule])
	if stage.is_empty():
		SsokLocale.bind(_status, "Challenge data is invalid. Your build is unchanged.")
		return
	load_goal(stage)
	_authoring = true
	SsokLocale.bind(_status, "Run and clear your challenge before exporting it.")


func _export() -> bool:
	if current.is_empty() or _proof_fingerprint.is_empty() or (pending_blocks.is_valid() and pending_blocks.call()) or _proof_fingerprint != StageDefinition.fingerprint(current, assembly.graph, source.call(), _context()):
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
