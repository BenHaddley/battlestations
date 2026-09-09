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
	if "--objective-demo" in arguments:
		# Force the opening lesson regardless of this profile's progress.
		CampaignManager.current_level_index = 0
		CampaignManager.tutorial_requested = true
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
	if "--objective-demo" in arguments:
		# Advance the opening to its first objective so the highlighted shop
		# row, arrow and objective tag are all on screen.
		var director: TutorialDirector = main.get_node_or_null("TutorialDirector")
		if director:
			director._advance()
			director._advance()
			director._advance()
		await get_tree().process_frame
	if "--hover-shop" in arguments:
		# Hover a shop row: the old build drew a full-width native tooltip here.
		var row: Button = main.menu.passenger_button
		main.menu._show_shop_detail(3)
		Input.warp_mouse(row.get_global_rect().get_center())
		for frame in range(8):
			await get_tree().process_frame
	if "--build-mode" in arguments:
		LevelManager.currency = 1000
		main.menu.set_build_track(true)
		var anchor_cell := Vector2i(3, 2)
		Input.warp_mouse(main.get_viewport().get_canvas_transform() * main.track.world_of(anchor_cell))
		for frame in range(8):
			await get_tree().process_frame
	if "--rails-demo" in arguments:
		# Boiler Room loop A: a detour off its top edge plus a dead-end spur,
		# then hover a rail tile so the plus signs and join marker render.
		LevelManager.currency = 1000
		var builder: RailBuilder = main.rail_builder
		for step in [[Vector2i(3, 2), Vector2i(3, 1)], [Vector2i(3, 1), Vector2i(3, 0)], [Vector2i(3, 0), Vector2i(4, 0)], [Vector2i(4, 0), Vector2i(5, 0)], [Vector2i(5, 0), Vector2i(5, 1)], [Vector2i(2, 4), Vector2i(1, 4)], [Vector2i(1, 4), Vector2i(0, 4)]]:
			builder.attempt_build(step[0], step[1])
		var hover_cell := Vector2i(5, 1)
		var hover_screen: Vector2 = main.get_viewport().get_canvas_transform() * main.track.world_of(hover_cell)
		Input.warp_mouse(hover_screen)
		for frame in range(6):
			await get_tree().process_frame
	if "--damage-demo" in arguments:
		# Chewed cars, a biting spider and a wrecked engine, all standing still.
		var train: TrainConvoy = main.convoys[0]
		var second: TrainConvoy = main.TrainConvoyScene.instantiate()
		main.trains.add_child(second)
		second.configure_path(main.track.routes[0])
		second.route_index = 0
		second.set_engine_livery(main.ENGINE_LIVERIES[3])
		main.convoys.append(second)
		second.unit_health.take_damage(second.unit_health.max_hit_points)
		var car: Node2D = train.followers[0]
		UnitHealth.of(car).take_damage(120.0, true)
		train.unit_health.take_damage(90.0)
		var spider: EnemyMovement = main.spawner.enemy_prefabs[0].instantiate()
		main.add_child(spider)
		spider.scale = Vector2(0.54, 0.54)
		spider.configure_archetype(EnemyRoster.PROFILES[0], 1, 0)
		spider.global_position = car.global_position + Vector2(0.0, -62.0)
		spider.configure_route(Vector2(spider.global_position.x, 600.0), 25.0)
		spider.set_physics_process(false)
		spider.biting_target = car
		train.set_process(false)
		spider.queue_redraw()
		for frame in range(6):
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
