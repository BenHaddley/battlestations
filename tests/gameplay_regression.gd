extends Node
## Headless regression coverage for convoy spacing/reverse motion and persistent
## station attackers. Run with: godot --headless --path . --script tests/gameplay_regression.gd

const ConvoyScene := preload("res://scenes/TrainConvoy.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const StationScene := preload("res://scenes/Station.tscn")
const MainScene := preload("res://scenes/Main.tscn")
const GameOverScene := preload("res://scenes/ui/GameOverOverlay.tscn")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	await get_tree().process_frame
	_test_convoy_spacing_and_reverse()
	_test_campaign_track_library()
	_test_challenge_job_cards()
	_test_music_playlist_rotation()
	_test_game_over_modes()
	await _test_station_attackers()
	await _test_spider_assault()
	await _test_main_scene_train_integration()
	if failures.is_empty():
		print("GAMEPLAY REGRESSION PASS")
		get_tree().quit(0)
	else:
		print("GAMEPLAY REGRESSION FAIL: %s" % [failures])
		get_tree().quit(1)

func _test_convoy_spacing_and_reverse() -> void:
	var convoy: TrainConvoy = ConvoyScene.instantiate()
	add_child(convoy)
	convoy.configure_path(PackedVector2Array([
		Vector2(0, 0), Vector2(720, 0), Vector2(720, 520), Vector2(0, 520)
	]))
	for index in range(12):
		var car := Node2D.new()
		car.set_script(preload("res://tests/train_test_car.gd"))
		add_child(car)
		_check(convoy.attach_car(car), "long test consist should attach car %d" % index)
	for step in range(720):
		convoy._advance_safely(5.0)
		_check(convoy._positions_valid_at(convoy.route_distance, convoy.followers.size()), "consist overlapped at movement step %d" % step)
	var distance_before := convoy.route_distance
	convoy.current_speed = convoy.cruise_speed
	convoy.set_manual_command(-1)
	convoy._update_speed(1.0)
	_check(convoy.current_speed >= 0.0, "reverse command flipped direction without braking")
	convoy._update_speed(1.0)
	convoy._update_speed(1.0)
	_check(convoy.current_speed < 0.0, "convoy did not accelerate in reverse after stopping")
	convoy._advance_safely(convoy.current_speed)
	_check(convoy.route_distance != distance_before, "reversing convoy did not move along route")
	_check(convoy._positions_valid_at(convoy.route_distance, convoy.followers.size()), "reverse movement caused consist overlap")
	convoy.current_speed = convoy.max_speed
	convoy.set_driver_controls(0, 0)
	convoy._update_speed(0.5)
	_check(convoy.current_speed < convoy.max_speed, "BRAKE notch did not actively decelerate")
	convoy.current_speed = convoy.cruise_speed
	convoy.set_driver_controls(1, 2)
	convoy._update_speed(0.5)
	_check(convoy.current_speed > convoy.cruise_speed, "POWER 1 did not add light acceleration")
	convoy.release_driver_controls()
	_check(convoy.requested_direction == 0 and convoy.throttle_notch == 1, "releasing driver controls did not restore automatic COAST")
	convoy.queue_free()

func _test_challenge_job_cards() -> void:
	_check(CampaignManager.CHALLENGES.size() == 6, "challenge menu should expose six launchable job cards")
	var seen_ids: Dictionary = {}
	for challenge in CampaignManager.CHALLENGES:
		var challenge_id := String(challenge.get("id", ""))
		_check(not challenge_id.is_empty() and not seen_ids.has(challenge_id), "challenge ids must be present and unique")
		seen_ids[challenge_id] = true
		_check(CampaignManager.start_challenge(challenge_id), "challenge %s did not start" % challenge_id)
		var level := CampaignManager.current_level()
		_check(level != null and level.level_name == String(challenge.name), "challenge %s did not supply its level data" % challenge_id)
		_check(level.wave_count > 0, "challenge %s must have a finite wave target" % challenge_id)
	CampaignManager.clear_challenge()

func _test_campaign_track_library() -> void:
	var renderer := TrackRenderer.new()
	add_child(renderer)
	var figure_eight := renderer.generate_bottom_figure_eight()
	_check(figure_eight.size() == 1, "Last Train Standing should have exactly one route")
	_check(figure_eight[0].size() == 18, "Last Train Standing figure eight has an unexpected rail length")
	_check(renderer.routes_are_traversable(), "Last Train Standing figure eight is not a closed traversable route")
	var crossing := Vector2(renderer.columns[4], renderer.rows[9])
	var crossing_visits := 0
	for point in figure_eight[0]:
		if point.is_equal_approx(crossing):
			crossing_visits += 1
	_check(crossing_visits == 2, "Last Train Standing route does not cross itself at the center")
	for point in figure_eight[0]:
		_check(point.y >= renderer.rows[8], "Last Train Standing rails escaped the bottom of the board")
	for layout_index in range(TrackRenderer.REFERENCE_LAYOUT_NAMES.size()):
		var layout := renderer.generate_campaign_layout(layout_index)
		_check(not layout.is_empty(), "campaign track %d produced no routes" % layout_index)
		_check(renderer.routes_are_traversable(), "campaign track %d contains a disconnected route" % layout_index)
		for route in layout:
			var unique: Dictionary = {}
			for point in route:
				_check(not unique.has(point), "campaign track %d repeats a cell within one route" % layout_index)
				unique[point] = true
	renderer.queue_free()

func _test_music_playlist_rotation() -> void:
	var playlist := preload("res://scripts/music_playlist.gd").new()
	playlist.tracks = [AudioStreamMP3.new(), AudioStreamMP3.new(), AudioStreamMP3.new()]
	# Consume two full shuffled cycles without requiring an audio device.
	for index in range(6):
		playlist._take_next_index()
	_check(playlist.play_history.size() == 6, "music playlist did not advance through both shuffle cycles")
	for index in range(1, playlist.play_history.size()):
		_check(playlist.play_history[index] != playlist.play_history[index - 1], "music playlist repeated a track back to back")
	var first_cycle: Dictionary = {}
	for index in range(3):
		first_cycle[playlist.play_history[index]] = true
	_check(first_cycle.size() == 3, "music playlist repeated before playing every track")
	playlist.queue_free()
	var main = MainScene.instantiate()
	var music_player := main.get_node("MusicPlayer") as AudioStreamPlayer
	_check(music_player.tracks.size() == 20, "gameplay playlist should contain all 20 songs")
	var unique_paths: Dictionary = {}
	for track in music_player.tracks:
		unique_paths[track.resource_path] = true
		_check(track.resource_path.begins_with("res://assets/audio/songs/"), "gameplay playlist contains a track outside the songs folder")
	_check(unique_paths.size() == 20, "gameplay playlist contains duplicate songs")
	main.queue_free()

func _test_game_over_modes() -> void:
	var mission: GameOverOverlay = GameOverScene.instantiate()
	add_child(mission)
	mission.show_failure(false)
	_check(mission.visible and get_tree().paused, "mission failure did not freeze gameplay and show its overlay")
	_check(mission._banner.texture.resource_path.ends_with("speed up.png"), "normal level loss did not use the Mission Failed banner")
	_check(mission._primary_button.get_meta("failure_action") == "restart_level", "normal level loss did not offer Restart Level")
	_check(not mission._character.get_rect().intersects(mission._message.get_rect()), "failure character overlaps its message")
	_check(not mission._primary_button.get_rect().intersects(mission._menu_button.get_rect()), "failure action buttons overlap")
	var panel_rect := Rect2(Vector2(410, 70), mission._panel.size)
	_check(panel_rect.encloses(mission._primary_button.get_rect()) and panel_rect.encloses(mission._menu_button.get_rect()), "failure buttons extend outside the industrial panel")
	get_tree().paused = false
	mission.queue_free()

	var challenge: GameOverOverlay = GameOverScene.instantiate()
	add_child(challenge)
	challenge.show_failure(true)
	_check(challenge._banner.texture.resource_path.contains("9176d68e"), "challenge loss did not use the Challenge Failed banner")
	_check(challenge._primary_button.get_meta("failure_action") == "retry_challenge", "challenge loss did not offer Retry Challenge")
	_check(challenge._menu_button.texture_normal.resource_path.contains("951252df"), "failure overlay did not use the supplied Main Menu button")
	get_tree().paused = false
	challenge.queue_free()

func _test_station_attackers() -> void:
	var station: Station = StationScene.instantiate()
	add_child(station)
	var enemy: EnemyMovement = EnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = Vector2(0, 100)
	enemy.configure_lane(100, 25)
	enemy._physics_process(0.01)
	_check(enemy.attacking_station, "enemy did not enter station attack state")
	_check(not enemy.is_queued_for_deletion(), "enemy despawned on station arrival")
	var hp_before := station.current_health
	enemy._physics_process(enemy.station_attack_windup + 0.01)
	_check(station.current_health == hp_before - enemy.station_attack_damage, "station did not take periodic attack damage")
	_check(enemy.is_in_group("spiders"), "station attacker stopped being targetable")
	enemy.take_damage(enemy.health.hit_points)
	await get_tree().process_frame
	_check(not is_instance_valid(enemy), "station attacker survived lethal train damage")
	station.queue_free()

func _test_spider_assault() -> void:
	_check(CampaignManager.start_challenge("spider_assault"), "Spider Assault challenge could not start")
	_check(CampaignManager.is_spider_assault(), "Spider Assault did not activate reverse-mode rules")
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var assault: SpiderAssaultController = main.spider_assault_controller
	_check(assault != null, "Spider Assault did not create its deployment controller")
	_check(SpiderAssaultController.ENTRANCES.size() == 5, "Spider Assault should expose five roof entrances")
	for entrance in SpiderAssaultController.ENTRANCES:
		_check(is_equal_approx(float(entrance.world.y), -425.0), "Spider Assault still contains a side or bottom entrance")
	_check(assault.entrance_buttons.size() == 5, "Spider Assault did not render all five roof entrances")
	_check(assault.spider_buttons.size() == 5, "Spider Nest does not show all five spider roles")
	_check(not main.menu.get_node("LeftPanel").visible and not main.menu.get_node("HpRail").visible and not main.menu.get_node("RightPanel").visible, "normal HUD overlaps the Spider Assault faction UI")
	var nest_rect: Rect2 = assault.get_node("SpiderNest").get_rect()
	_check(nest_rect.end.x <= 318.0, "Spider Nest overlaps the center board, rect is %s" % nest_rect)
	_check(assault.get_node("AssaultStatus").get_rect().position.x >= 1030.0, "Spider Assault status panel overlaps the center board")
	var assault_music := main.get_node("MusicPlayer") as AudioStreamPlayer
	_check(assault_music.tracks.size() == 1, "Spider Assault did not replace the shuffled music playlist")
	_check(assault_music.stream.resource_path.ends_with("Spider Assault - The Fun House.mp3"), "Spider Assault loaded the wrong level song")
	_check((assault_music.stream as AudioStreamMP3).loop, "Spider Assault level song is not configured to loop")
	_check(main.convoys.size() == 2, "Spider Assault did not create its two-train defense")
	_check(main.convoys[0].get_node_or_null("SpiderBlocker") != null, "Spider Assault trains do not physically block spiders")
	_check(PhaseManager.paused, "Spider Assault left the automatic campaign wave clock running")
	var defensive_cars := 0
	for convoy in main.convoys:
		defensive_cars += convoy.car_count()
	_check(defensive_cars >= 4, "Spider Assault pre-built defense is missing turret cars")
	assault._finish_intro()
	var web_before := assault.web
	assault._deploy_at(SpiderAssaultController.ENTRANCES[0])
	_check(assault.web == web_before - 1.0, "Spider Assault deployment did not spend Web")
	var deployed: Node = null
	for spider in get_tree().get_nodes_in_group("spiders"):
		if spider.get_meta("player_deployed", false):
			deployed = spider
			break
	_check(deployed != null and deployed.has_route_target, "player-deployed spider did not receive an entrance route")
	assault._activate_swarm()
	_check(deployed != null and is_equal_approx(float(deployed.assault_speed_multiplier), 1.6), "SWARM did not accelerate deployed spiders")
	main.get_node("Station").take_damage(main.get_node("Station").max_health)
	_check(assault.victory_overlay.visible and get_tree().paused, "destroying the station did not show Spider Assault victory")
	_check(not main.game_over_overlay.visible, "Spider Assault victory incorrectly opened Challenge Failed")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame
	CampaignManager.clear_challenge()
	PhaseManager.reset()

func _test_main_scene_train_integration() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var pause_menu: PauseMenu = main.menu.pause_menu
	_check(pause_menu != null, "main HUD did not create the pause menu")
	pause_menu.open()
	_check(get_tree().paused and pause_menu.visible, "pause menu did not pause gameplay")
	_check(pause_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "pause menu cannot process input while paused")
	_check(pause_menu.get_node_or_null("Shade/Card/Margin/Content/RestartButton") != null, "pause menu is missing restart")
	_check(pause_menu.get_node_or_null("Shade/Card/Margin/Content/TitleButton") != null, "pause menu is missing return to title")
	pause_menu.close()
	_check(not get_tree().paused and not pause_menu.visible, "resume did not restore gameplay")
	_check(main.convoys.size() >= 2, "main scene did not create its train routes")
	if not main.convoys.is_empty():
		_check(main.convoys[0].car_count() >= 1, "starter car was rejected or missing")
		main._select_convoy(main.convoys[0])
		await get_tree().create_timer(0.2).timeout
		_check(main.train_control_panel._expansion > 0.9, "engine selection did not expand train controls")
		_check(main.train_control_panel.find_children("*", "Button", true, false).is_empty(), "train stand still contains generic Godot buttons")
		main.train_control_panel._set_reverser(-1)
		main.train_control_panel._set_throttle(3)
		_check(main.convoys[0].requested_direction == -1 and main.convoys[0].throttle_notch == 3, "physical reverser/throttle controls did not reach selected train")
		_check(main.train_control_panel._nearest_throttle(166.0) == 0 and main.train_control_panel._nearest_throttle(368.5) == 5, "throttle click targets do not snap to end notches")
		main._clear_train_selection()
		await get_tree().create_timer(0.2).timeout
		_check(main.train_control_panel._expansion < 0.1, "train controls did not collapse after deselection")
	main.queue_free()
	await get_tree().process_frame
