class_name StageSelectScreen
extends MenuScreen

## Stage map. Order is a recommendation; nothing is locked (product policy: no forced path).

signal stage_chosen(level_id: String)

var play_buttons: Dictionary = {}


func build() -> void:
	header("Stages", "Pick a stage. Each one has its own place, goal and robot.")
	var cleared: Dictionary = StageProgress.load_cleared()
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	var first_open: Button = null
	for level: Dictionary in StageLevels.all():
		var parts: Array = card(300)
		var panel: PanelContainer = parts[0]
		var box: VBoxContainer = parts[1]
		panel.name = "Stage_" + level.id
		grid.add_child(panel)
		var top := HBoxContainer.new()
		box.add_child(top)
		var number: Label = text(top, "", 13, false, SsokTheme.ACCENT)
		SsokLocale.bind(number, "STAGE %s", [level.number])
		number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var done: bool = cleared.has(level.id)
		var badge: Label = text(top, "Cleared" if done else "New", 13, not done, SsokTheme.ACCENT if done else Color.TRANSPARENT)
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		text(box, level.title, 22)
		text(box, level.topic, 14, true)
		text(box, level.goal, 15)
		var play: Button = SsokTheme.button("Play again" if done else "Play", "play")
		play.name = "Play"
		play.custom_minimum_size.y = 44
		play.pressed.connect(func() -> void: stage_chosen.emit(level.id))
		box.add_child(play)
		play_buttons[level.id] = play
		if not done and first_open == null:
			first_open = primary(play)
	var soon := Label.new()
	soon.text = "Coming soon"
	soon.theme_type_variation = &"SectionLabel"
	content.add_child(soon)
	var planned := HFlowContainer.new()
	planned.add_theme_constant_override("h_separation", 10)
	planned.add_theme_constant_override("v_separation", 10)
	content.add_child(planned)
	for title: String in StageLevels.PLANNED:
		var chip := Button.new()
		chip.text = title
		chip.icon = SsokTheme.icon("lock")
		chip.disabled = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.tooltip_text = "This stage is not ready yet."
		planned.add_child(chip)
	var focus_target: Button = first_open if first_open != null else play_buttons.values()[0]
	focus_target.grab_focus.call_deferred()
