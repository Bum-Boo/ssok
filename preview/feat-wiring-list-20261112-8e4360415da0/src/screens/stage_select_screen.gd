class_name StageSelectScreen
extends MenuScreen

## Stage map. Order is a recommendation; nothing is locked (product policy: no forced path).
## Each card leads with a picture of the challenge (assets/stages/art, see its README).

signal stage_chosen(level_id: String)
signal lab_requested

const ART: String = "res://assets/stages/art/%s.jpg"
const CARD_WIDTH: float = 228.0
const PICTURE_HEIGHT: float = 128.0

var play_buttons: Dictionary = {}


func build() -> void:
	header("Stages", "Pick a stage. Build your own robot to reach its goal.")
	var cleared: Dictionary = StageProgress.load_cleared()
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	var first_open: Button = null
	for level: Dictionary in StageLevels.all():
		var parts: Array = _picture_card(level.id)
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
		text(box, level.title, 20)
		if StageProgress.cleared_with_solution(level.id):
			text(box, "Cleared with solution", 13, true)
		var facts := HBoxContainer.new()
		facts.add_theme_constant_override("separation", 8)
		box.add_child(facts)
		text(facts, ["Beginner", "Intermediate", "Advanced"][int(level.number) - 1], 14, true).autowrap_mode = TextServer.AUTOWRAP_OFF
		text(facts, level.topic, 14, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var goal: Label = text(box, level.goal, 15)
		goal.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var play: Button = SsokTheme.button("Play again" if done else "Play", "play")
		play.name = "Play"
		play.custom_minimum_size.y = 44
		play.pressed.connect(func() -> void: stage_chosen.emit(level.id))
		box.add_child(play)
		play_buttons[level.id] = play
		if not done and first_open == null:
			first_open = primary(play)
	var lab_card: Array = _picture_card("lab")
	(lab_card[0] as Control).name = "Lab"
	grid.add_child(lab_card[0])
	text(lab_card[1], "Free building (Lab)", 20)
	var lab_detail: Label = text(lab_card[1], "Build, wire and program your own robot.", 15)
	lab_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lab: Button = SsokTheme.button("Open Lab", "box")
	lab.custom_minimum_size.y = 44
	lab.pressed.connect(func() -> void: lab_requested.emit())
	lab_card[1].add_child(lab)
	var soon := Label.new()
	soon.text = "Coming soon"
	soon.theme_type_variation = &"SectionLabel"
	content.add_child(soon)
	# Stages that are not playable yet are named in one quiet line, not as locked buttons.
	var planned := Label.new()
	planned.name = "Planned"
	planned.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	planned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	planned.label_settings = SsokTheme.dim_settings()
	var titles: PackedStringArray = []
	for title: String in StageLevels.PLANNED:
		titles.append(tr(title))
	planned.text = ", ".join(titles)
	content.add_child(planned)
	var focus_target: Button = first_open if first_open != null else play_buttons.values()[0]
	focus_target.grab_focus.call_deferred()


## A card whose picture runs edge to edge above its padded text.
func _picture_card(art_id: String) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = CARD_WIDTH
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = SsokTheme.BG_SUNKEN
	style.border_color = SsokTheme.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.texture = load(ART % art_id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size.y = PICTURE_HEIGHT
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(picture)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	column.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	return [panel, box]
