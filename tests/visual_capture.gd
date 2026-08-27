extends Node
## Deterministic visual smoke helper. Optional output path is supplied with
## --capture-path; defaults to /tmp/battle-stations-main.png.

const MainScene := preload("res://scenes/Main.tscn")

func _ready() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	for frame in range(8):
		await get_tree().process_frame
	if not main.convoys.is_empty():
		main._select_convoy(main.convoys[0])
		await get_tree().process_frame
	var output := "/tmp/battle-stations-main.png"
	var arguments := OS.get_cmdline_user_args()
	var flag_index := arguments.find("--capture-path")
	if flag_index >= 0 and flag_index + 1 < arguments.size():
		output = arguments[flag_index + 1]
	get_viewport().get_texture().get_image().save_png(output)
	print("VISUAL CAPTURE: %s" % output)
	get_tree().quit()
