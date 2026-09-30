extends SceneTree
var app: Node3D
const OUT: String = "/home/bumboo/Projects/ssok-release/docs/research/playful-ux-2026-09-30/"
func _initialize() -> void:
	capture.call_deferred()
func capture() -> void:
	root.size = Vector2i(1440, 900)
	root.gui_embed_subwindows = true
	SsokLocale.select_locale("ko", false)
	app = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(app)
	await process_frame
	SsokLocale.select_locale("ko", false)
	await shot("01-workshop")
	app._open_tutorial()
	await shot("02-tutorial")
	app.tutorial.close_panel()
	app._on_learned_biped_pressed()
	app.mode_button.button_pressed = true
	for tick: int in range(60):
		await physics_frame
	_key(true)
	for tick: int in range(180):
		await physics_frame
	await shot("03-run")
	_key(false)
	app.mode_button.button_pressed = false
	app._on_biped_pressed()
	app._open_motion_lab()
	app.motion_lab.workflow_tabs.current_tab = 1
	await shot("04-ai-cost")
	app.free()
	quit()
func shot(label: String) -> void:
	for frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(OUT + label + ".png")
	print("AUDIT_CAPTURE ", label, " ", result)

func _key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	root.push_input(event, true)
