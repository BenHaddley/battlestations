extends Node
## Deterministic visual smoke helper. Optional output path is supplied with
## --capture-path; defaults to /tmp/battle-stations-main.png.

const MainScene := preload("res://scenes/Main.tscn")
const TitleScene := preload("res://scenes/TitleScreen.tscn")

func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if "--title" in arguments:
		var title := TitleScene.instantiate()
		add_child(title)
		for frame in range(12):
			await get_tree().process_frame
		_save_capture(arguments, "/tmp/battle-stations-title.png")
		return
	if "--spider-assault" in arguments:
		CampaignManager.start_challenge("spider_assault")
	if "--open-rails" in arguments:
		CampaignManager.campaign_complete = true
	var level_flag := arguments.find("--campaign-level")
	if level_flag >= 0 and level_flag + 1 < arguments.size():
		CampaignManager.current_level_index = clampi(int(arguments[level_flag + 1]), 0, CampaignManager.levels.size() - 1)
	var main = MainScene.instantiate()
	add_child(main)
	for frame in range(8):
		await get_tree().process_frame
	if "--no-dialogue" in arguments:
		var tutorial: TutorialDirector = main.get_node_or_null("TutorialDirector")
		if tutorial and tutorial.overlay:
			tutorial.queue.clear()
			tutorial.current = {}
			tutorial.overlay.visible = false
			tutorial.tutorial_active = false
			PhaseManager.paused = false
	if "--spider-assault" in arguments and main.spider_assault_controller:
		main.spider_assault_controller._finish_intro()
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
	if "--combat" in arguments:
		if main.spawner.can_start_next_wave():
			main.spawner.start_next_wave()
		for frame in range(300):
			await get_tree().process_frame
	if "--sequence-dir" in arguments:
		var sequence_flag := arguments.find("--sequence-dir")
		var sequence_dir := arguments[sequence_flag + 1]
		if main.spawner.can_start_next_wave():
			main.spawner.start_next_wave()
		for sequence_frame in range(24):
			for skipped_frame in range(10):
				await get_tree().process_frame
			var frame_path := "%s/frame_%02d.png" % [sequence_dir, sequence_frame]
			get_viewport().get_texture().get_image().save_png(frame_path)
		print("VISUAL SEQUENCE: %s" % sequence_dir)
		get_tree().quit()
		return
	_save_capture(arguments, "/tmp/battle-stations-main.png")

func _save_capture(arguments: PackedStringArray, fallback: String) -> void:
	var output := fallback
	var flag_index := arguments.find("--capture-path")
	if flag_index >= 0 and flag_index + 1 < arguments.size():
		output = arguments[flag_index + 1]
	get_viewport().get_texture().get_image().save_png(output)
	print("VISUAL CAPTURE: %s" % output)
	get_tree().quit()
