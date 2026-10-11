class_name LoadingScreen
extends MenuScreen

## Shown while a stage level and its robot are instanced. Loading is synchronous
## (no threads, per engine policy), so this screen gets one drawn frame first.

var level: Dictionary = {}


func build() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = maxf(0.0, get_viewport_rect().size.y * 0.22)
	content.add_child(spacer)
	if level.is_empty():
		var label: Label = text(content, "Loading...", 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var number: Label = text(content, "", 16, false, SsokTheme.ACCENT)
	SsokLocale.bind(number, "STAGE %s", [level.number])
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title: Label = text(content, level.title, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var goal: Label = text(content, level.goal, 18, true)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := ProgressBar.new()
	bar.indeterminate = true
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 8)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(bar)
	var loading: Label = text(content, "Loading...", 14, true)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
