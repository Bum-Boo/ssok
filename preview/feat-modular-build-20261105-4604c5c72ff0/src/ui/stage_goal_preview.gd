class_name StageGoalPreview
extends Control

## Small goal illustrations, independent of robot presets and scoring.
var stage_id: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(240, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var ink: Color = SsokTheme.ACCENT
	var baseline: float = 78.0
	draw_line(Vector2(12, baseline), Vector2(size.x - 12, baseline), SsokTheme.BORDER, 2, true)
	if stage_id == "raise-flag":
		draw_line(Vector2(25, 30), Vector2(size.x - 25, 30), ink, 2, true)
		draw_line(Vector2(75, 76), Vector2(75, 30), SsokTheme.TEXT, 4, true)
		draw_colored_polygon(PackedVector2Array([Vector2(77, 30), Vector2(120, 30), Vector2(105, 48), Vector2(77, 48)]), ink)
	else:
		draw_style_box(SsokTheme._flat(ink, 0, ink, 5), Rect2(30, 52, 70, 20))
		for x: float in [45.0, 85.0]:
			draw_circle(Vector2(x, 74), 6, SsokTheme.TEXT)
		if stage_id == "finish-line":
			for index: int in 6:
				draw_rect(Rect2(size.x - 62, 22 + index * 9, 14, 9), ink if index % 2 == 0 else SsokTheme.BG)
			draw_line(Vector2(118, 62), Vector2(size.x - 82, 62), ink, 3, true)
		else:
			draw_rect(Rect2(size.x - 90, 74, 36, 6), ink)
			draw_rect(Rect2(size.x - 50, 20, 12, 58), SsokTheme.TEXT_DIM)
