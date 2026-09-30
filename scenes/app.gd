extends Node

## Screen router. Menus are separate 2D scenes; each stage loads a fresh workshop with its
## own level scene, so nothing from a previous stage or free build leaks into the next one.

const WORKSHOP: String = "res://scenes/main.tscn"
const SCREENS: Dictionary = {
	"title": "res://scenes/screens/title.tscn",
	"stages": "res://scenes/screens/stage_select.tscn",
	"examples": "res://scenes/screens/examples.tscn",
	"loading": "res://scenes/screens/loading.tscn",
}

var current: Node
var current_name: String = ""


func _ready() -> void:
	SsokTheme.configure(Preferences.dark_appearance(), Preferences.values.text_scale, Preferences.values.code_scale)
	Preferences.changed.connect(_on_preferences_changed)
	if _direct_workshop_requested():
		_replace((load(WORKSHOP) as PackedScene).instantiate(), "workshop")
		return
	show_title()


## Browser gates click workshop coordinates, so `?ssok_workshop=1` (or the existing
## `?ssok_verify=1` evidence mode) opens the full legacy workshop without menus.
func _direct_workshop_requested() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("(() => { const q = new URLSearchParams(window.location.search); return q.get('ssok_workshop') === '1' || q.get('ssok_verify') === '1'; })()", true))


func _replace(node: Node, screen_name: String) -> void:
	if is_instance_valid(current):
		remove_child(current)
		current.queue_free()
	current = node
	current_name = screen_name
	add_child(node)


func _screen(screen_name: String) -> MenuScreen:
	return (load(SCREENS[screen_name]) as PackedScene).instantiate() as MenuScreen


func show_title() -> void:
	var screen: TitleScreen = _screen("title") as TitleScreen
	screen.stages_requested.connect(show_stages)
	screen.lab_requested.connect(start_workshop.bind({"mode": "lab"}))
	screen.examples_requested.connect(show_examples)
	screen.projects_requested.connect(start_workshop.bind({"mode": "lab", "open_projects": true}))
	_replace(screen, "title")


func show_stages() -> void:
	var screen: StageSelectScreen = _screen("stages") as StageSelectScreen
	screen.back_requested.connect(show_title)
	screen.stage_chosen.connect(start_stage)
	_replace(screen, "stages")


func show_examples() -> void:
	var screen: ExamplesScreen = _screen("examples") as ExamplesScreen
	screen.back_requested.connect(show_title)
	screen.example_chosen.connect(func(index: int) -> void: start_workshop({"mode": "example", "example": index}))
	_replace(screen, "examples")


func start_stage(level_id: String) -> void:
	var level: Dictionary = StageLevels.find(level_id)
	if level.is_empty():
		show_stages()
		return
	start_workshop({"mode": "stage", "level": level})


func start_workshop(session: Dictionary) -> void:
	var loading: LoadingScreen = _screen("loading") as LoadingScreen
	loading.level = session.get("level", {})
	_replace(loading, "loading")
	# Draw the loading screen before the synchronous scene build.
	await get_tree().process_frame
	await get_tree().process_frame
	if current != loading:
		return
	var workshop: Node3D = (load(WORKSHOP) as PackedScene).instantiate() as Node3D
	workshop.set("session", session)
	var back_to: Callable = show_stages if session.mode == "stage" else (show_examples if session.mode == "example" else show_title)
	workshop.connect("exit_requested", back_to)
	workshop.connect("next_stage_requested", start_stage)
	_replace(workshop, session.mode)


func _on_preferences_changed() -> void:
	# Menus are rebuilt with the new theme; the workshop applies preferences itself.
	if current is MenuScreen and current_name != "loading":
		SsokTheme.configure(Preferences.dark_appearance(), Preferences.values.text_scale, Preferences.values.code_scale)
		var rebuild: Dictionary = {"title": show_title, "stages": show_stages, "examples": show_examples}
		if rebuild.has(current_name):
			var settings_open: bool = current is TitleScreen and (current as TitleScreen).settings.visible
			rebuild[current_name].call()
			if settings_open:
				(current as TitleScreen).settings.open_panel()
