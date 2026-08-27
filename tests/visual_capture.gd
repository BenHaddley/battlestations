extends Node
## Deterministic visual smoke helper. Optional output path is supplied with
## --capture-path; defaults to /tmp/battle-stations-main.png.

const MainScene := preload("res://scenes/Main.tscn")

func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	var level_flag := arguments.find("--campaign-level")
	if level_flag >= 0 and level_flag + 1 < arguments.size():
		CampaignManager.current_level_index = clampi(int(arguments[level_flag + 1]), 0, CampaignManager.levels.size() - 1)
	var main = MainScene.instantiate()
	add_child(main)
	for frame in range(8):
		await get_tree().process_frame
	if not main.convoys.is_empty() and "--no-select" not in arguments:
		main._select_convoy(main.convoys[0])
		await get_tree().create_timer(0.22).timeout
	if "--pause-menu" in arguments:
		main.menu.pause_menu.open()
		await get_tree().process_frame
	if "--game-over" in arguments:
		main.game_over_overlay.show_failure("--challenge" in arguments)
		for frame in range(40):
			await get_tree().process_frame
	var output := "/tmp/battle-stations-main.png"
	var flag_index := arguments.find("--capture-path")
	if flag_index >= 0 and flag_index + 1 < arguments.size():
		output = arguments[flag_index + 1]
	get_viewport().get_texture().get_image().save_png(output)
	print("VISUAL CAPTURE: %s" % output)
	get_tree().quit()
