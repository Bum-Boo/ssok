class_name ExamplesScreen
extends MenuScreen

## Finished robots to watch and take apart. Indexes match the workshop example loaders.

signal example_chosen(index: int)

const EXAMPLES: Array[Dictionary] = [
	{"title": "Servo arm", "detail": "One servo lifts an arm. The simplest robot to read."},
	{"title": "Biped", "detail": "Two legs, four servos. Drive it with WASD."},
	{"title": "Humanoid (experimental)", "detail": "Walks and picks up a box. Movement is still unstable."},
	{"title": "Construction-kit humanoid", "detail": "Built only from kit beams, plates and fasteners."},
	{"title": "Kit bridge", "detail": "The same kit parts, assembled into a bridge."},
	{"title": "Learned biped", "detail": "Walks with a learned policy. Hold W."},
]


func build() -> void:
	header("Examples", "Open a finished robot, run it, then change it.")
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	for index: int in EXAMPLES.size():
		var parts: Array = card(280)
		var box: VBoxContainer = parts[1]
		grid.add_child(parts[0])
		text(box, EXAMPLES[index].title, 20)
		text(box, EXAMPLES[index].detail, 14, true)
		var open: Button = SsokTheme.button("Open", "box")
		open.name = "Open%d" % index
		open.pressed.connect(func() -> void: example_chosen.emit(index))
		box.add_child(open)
		if index == 0:
			open.grab_focus.call_deferred()
