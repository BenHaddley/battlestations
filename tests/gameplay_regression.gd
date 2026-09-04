extends Node
## Headless regression coverage for convoy spacing/reverse motion and persistent
## station attackers. Run with:
## godot --headless --path . tests/GameplayRegression.tscn

const ConvoyScene := preload("res://scenes/TrainConvoy.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const StationScene := preload("res://scenes/Station.tscn")
const MainScene := preload("res://scenes/Main.tscn")
const GameOverScene := preload("res://scenes/ui/GameOverOverlay.tscn")
const TitleScene := preload("res://scenes/TitleScreen.tscn")
const BasicTurretScene := preload("res://scenes/Turret.tscn")
const MinigunScene := preload("res://scenes/TurretMinigun.tscn")
const BasicBulletScene := preload("res://scenes/Bullet.tscn")
const MinigunBulletScript := preload("res://scripts/bullet.gd")

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
	_test_content_catalogs()
	_test_wallet_wave_and_selection_rules()
	_test_challenge_job_cards()
	_test_music_playlist_rotation()
	_test_game_over_modes()
	await _test_title_feature_modals()
	await _test_reported_combat_regressions()
	await _test_station_attackers()
	await _test_spider_assault()
	await _test_main_scene_train_integration()
	# Let short procedural/audio one-shots finish and release their players before
	# ObjectDB performs its exit leak check.
	await get_tree().create_timer(0.25).timeout
	if failures.is_empty():
		print("GAMEPLAY REGRESSION PASS")
		get_tree().quit(0)
	else:
		print("GAMEPLAY REGRESSION FAIL: %s" % [failures])
		get_tree().quit(1)

func _test_reported_combat_regressions() -> void:
	var basic_bullet: Bullet = BasicBulletScene.instantiate()
	_check(basic_bullet.bullet_damage == 20, "basic Gunner did not receive its 4x damage increase")
	basic_bullet.queue_free()
	var basic_turret: Turret = BasicTurretScene.instantiate()
	add_child(basic_turret)
	var basic_target := Node2D.new()
	basic_target.position = Vector2.RIGHT * 200.0
	add_child(basic_target)
	basic_turret.target = basic_target
	basic_turret._shoot()
	var fired_basic_bullet: Bullet
	for child in get_tree().current_scene.get_children():
		if child is Bullet and child != basic_bullet:
			fired_basic_bullet = child
	_check(fired_basic_bullet != null and fired_basic_bullet.bullet_damage == 20, "live Gunner shot fell back below 20 damage")
	if fired_basic_bullet:
		fired_basic_bullet.free()
	basic_target.free()
	basic_turret.free()
	var collision_enemy: EnemyMovement = EnemyScene.instantiate()
	collision_enemy.position = Vector2(120.0, 300.0)
	add_child(collision_enemy)
	collision_enemy.health.configure_hit_points(5)
	var swept_bullet: Bullet = BasicBulletScene.instantiate()
	swept_bullet.process_mode = Node.PROCESS_MODE_DISABLED
	swept_bullet.position = Vector2(0.0, 300.0)
	add_child(swept_bullet)
	swept_bullet.set_direction(Vector2.RIGHT)
	await get_tree().physics_frame
	swept_bullet._physics_process(0.25)
	_check(collision_enemy.health.is_destroyed, "fast straight Gunner projectile tunnelled through a level-one spider")
	if is_instance_valid(swept_bullet):
		swept_bullet.free()
	if is_instance_valid(collision_enemy):
		collision_enemy.free()
	var minigun_bullet: Bullet = preload("res://scenes/MinigunBullet.tscn").instantiate()
	_check(minigun_bullet.bullet_damage == 4, "Chaingunner rounds did not receive their 4x damage increase")
	minigun_bullet.queue_free()
	var coal_ball = preload("res://scenes/CoalCannonball.tscn").instantiate()
	_check(coal_ball.direct_damage == 12 and coal_ball.splash_damage == 4, "Coal Cannon did not receive its 4x damage increase")
	coal_ball.queue_free()
	_check(preload("res://scripts/turret_ballast.gd").BLAST_DAMAGE == 8, "Ballast Blaster did not receive its 4x damage increase")

	var jump_spider: EnemyMovement = EnemyScene.instantiate()
	add_child(jump_spider)
	jump_spider.global_position = Vector2(100, 100)
	jump_spider.configure_route(Vector2(100, 600), 10.0)
	jump_spider.ability = "jump"
	jump_spider._jumping = false
	var grounded_position := jump_spider.global_position
	jump_spider._physics_process(0.25)
	_check(jump_spider.global_position.is_equal_approx(grounded_position), "grounded Jump Spider moved between hops")
	jump_spider._jumping = true
	jump_spider._special_clock = 4.0
	jump_spider._physics_process(0.25)
	_check(jump_spider.global_position.y > grounded_position.y, "Jump Spider did not advance during its hop")
	var before_knockback := jump_spider.global_position
	jump_spider.apply_knockback(90.0)
	_check(jump_spider.global_position.y < before_knockback.y, "Coal Cannon knockback did not move a spider away from its destination")
	jump_spider.queue_free()

	var minigun: Turret = MinigunScene.instantiate()
	add_child(minigun)
	_check(minigun.fixed_direction_enabled, "Chaingunner did not enable the new static-facing prototype")
	_check(minigun._fixed_art != null and minigun._fixed_art.visible, "Chaingunner static sprite is missing")
	_check(minigun.fixed_line_half_width <= 18.0, "directional targeting corridor is wider than a swept projectile can hit")
	minigun.set_convoy_transform(Vector2.ZERO, Vector2.DOWN)
	_check(minigun._fixed_fire_direction().is_equal_approx(Vector2.RIGHT), "unflipped directional gun art points right but fires left")
	var initial_fire_direction := minigun._fixed_fire_direction()
	minigun.set_fixed_facing(-1)
	_check(minigun._fixed_fire_direction().dot(initial_fire_direction) < -0.99, "directional gun flip did not reverse its firing side")
	minigun.set_fixed_facing(1)
	var barrel_origin: Vector2 = minigun.firing_point.global_position
	var distant_inline := Node2D.new()
	distant_inline.global_position = barrel_origin + Vector2.RIGHT * 5000.0
	add_child(distant_inline)
	_check(minigun._is_in_fixed_firing_line(distant_inline), "directional gun retained a circular distance limit")
	var angled_target := Node2D.new()
	angled_target.global_position = barrel_origin + Vector2(500.0, minigun.fixed_line_half_width + 5.0)
	add_child(angled_target)
	_check(not minigun._is_in_fixed_firing_line(angled_target), "directional gun accepted a target outside its straight corridor")
	var behind_target := Node2D.new()
	behind_target.global_position = barrel_origin + Vector2.LEFT * 100.0
	add_child(behind_target)
	_check(not minigun._is_in_fixed_firing_line(behind_target), "directional gun accepted a target behind its barrel")
	distant_inline.queue_free()
	angled_target.queue_free()
	behind_target.queue_free()
	var target_node := Node2D.new()
	# Default static artwork and facing +1 point toward screen-right.
	target_node.position = Vector2(200, 0)
	add_child(target_node)
	minigun.target = target_node
	var bullets_before := _count_minigun_bullets()
	minigun._shoot()
	_check(_count_minigun_bullets() == bullets_before + 1, "Chaingunner emitted more than one bullet on its initial burst frame")
	var first_bullet: Bullet = _latest_minigun_bullet()
	_check(first_bullet != null and first_bullet.target == null and first_bullet.travel_direction.is_equal_approx(Vector2.RIGHT), "directional gun projectile still homes instead of travelling straight")
	await get_tree().create_timer(minigun.get("burst_interval") * 1.2).timeout
	_check(_count_minigun_bullets() == bullets_before + 2, "Chaingunner rounds are not arriving sequentially")
	await get_tree().create_timer(minigun.get("burst_interval") * 6.2).timeout
	_check(_count_minigun_bullets() == bullets_before + 7, "Chaingunner burst did not emit exactly seven rounds")
	var reverse_test_convoy: TrainConvoy = ConvoyScene.instantiate()
	add_child(reverse_test_convoy)
	reverse_test_convoy.configure_path(PackedVector2Array([
		Vector2(0, 0), Vector2(720, 0), Vector2(720, 520), Vector2(0, 520)
	]))
	_check(reverse_test_convoy.attach_car(minigun), "directional turret could not attach for reverse-facing regression")
	var fire_direction_before_reverse := minigun._fixed_fire_direction()
	reverse_test_convoy.cruise_direction = -1
	reverse_test_convoy._apply_consist_positions()
	_check(minigun._fixed_fire_direction().is_equal_approx(fire_direction_before_reverse), "reversing the train switched the turret's placed firing side")
	minigun.queue_free()
	reverse_test_convoy.queue_free()
	target_node.queue_free()

func _count_minigun_bullets() -> int:
	var count := 0
	for child in get_tree().current_scene.get_children():
		if child.get_script() == MinigunBulletScript:
			count += 1
	return count

func _latest_minigun_bullet() -> Bullet:
	for child in get_tree().current_scene.get_children():
		if child.get_script() == MinigunBulletScript:
			return child
	return null

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

func _test_content_catalogs() -> void:
	var balance := load("res://resources/game_balance.tres") as GameBalance
	_check(balance != null, "shared game balance resource failed to load")
	if balance:
		_check(balance.base_enemies > 0 and balance.base_spawn_rate > 0.0, "shared wave balance is invalid")
		_check(balance.minimum_speed > 0.0 and balance.minimum_speed < balance.cruise_speed, "shared train speeds do not preserve a minimum crawl")
		_check(balance.cruise_speed < balance.maximum_speed, "shared train maximum must exceed cruise speed")
		_check(balance.passenger_income > 0 and balance.passenger_income_interval > 0.0, "shared Passenger Coach economy is invalid")
	var tower_paths: Array[String] = [
		"res://resources/basic_turret.tres",
		"res://resources/minigun_turret.tres",
		"res://resources/ballast_turret.tres",
		"res://resources/coal_cannon_turret.tres",
		"res://resources/passenger_coach.tres",
		"res://resources/brake_van.tres",
		"res://resources/tender_car.tres",
	]
	var tower_names: Dictionary = {}
	for path in tower_paths:
		var tower := load(path) as TowerData
		_check(tower != null, "tower catalog entry failed to load: %s" % path)
		if tower == null:
			continue
		_check(not tower.tower_name.is_empty(), "tower catalog entry has no name: %s" % path)
		_check(not tower_names.has(tower.tower_name), "tower name is duplicated: %s" % tower.tower_name)
		tower_names[tower.tower_name] = true
		_check(tower.cost >= 0, "%s has a negative cost" % tower.tower_name)
		_check(tower.weight >= 0.0, "%s has a negative weight" % tower.tower_name)
		_check(tower.scene != null, "%s has no scene" % tower.tower_name)
		_check(tower.icon != null, "%s has no shop icon" % tower.tower_name)

	var enemy_ids: Dictionary = {}
	for profile in EnemyRoster.PROFILES:
		var profile_id := String(profile.get("id", ""))
		_check(not profile_id.is_empty(), "enemy profile has no id")
		_check(not enemy_ids.has(profile_id), "enemy id is duplicated: %s" % profile_id)
		enemy_ids[profile_id] = true
		for numeric_key in ["weight", "hp", "speed", "bounty", "scale"]:
			_check(float(profile.get(numeric_key, 0)) > 0.0, "%s has invalid %s" % [profile_id, numeric_key])
		for texture_key in ["walk_a", "walk_b", "death"]:
			_check(profile.get(texture_key) is Texture2D, "%s has no %s texture" % [profile_id, texture_key])

func _test_wallet_wave_and_selection_rules() -> void:
	var original_currency := LevelManager.currency
	LevelManager.reset_currency(100)
	_check(LevelManager.spend_currency(100), "wallet rejected an exactly affordable purchase")
	_check(LevelManager.currency == 0, "wallet deducted the wrong amount")
	_check(not LevelManager.spend_currency(1, "test", false), "wallet allowed an unaffordable purchase")
	_check(LevelManager.currency == 0, "failed purchase changed the wallet balance")
	LevelManager.increase_currency(25)
	_check(LevelManager.currency == 25, "wallet income was not credited")
	LevelManager.reset_currency(original_currency)

	var original_selection := BuildManager.selected_tower
	BuildManager.set_selected_tower(0)
	BuildManager.set_selected_tower(-1, false)
	_check(BuildManager.selected_tower == 0, "invalid negative shop selection replaced the valid selection")
	BuildManager.set_selected_tower(BuildManager.towers.size(), false)
	_check(BuildManager.selected_tower == 0, "out-of-range shop selection replaced the valid selection")
	BuildManager.selected_tower = original_selection

	var spawner := EnemySpawner.new()
	spawner.base_enemies = 3
	spawner.difficulty_scaling_factor = 1.15
	spawner.enemies_per_second = 0.4
	spawner.spawn_rate_scaling_factor = 0.75
	spawner.enemies_per_second_cap = 15.0
	for wave in range(1, 11):
		spawner.current_wave = wave
		var expected_count := 3 + roundi(2.0 * pow(maxf(wave - 1, 0), 1.15))
		_check(spawner._enemies_per_wave() == expected_count, "wave %d enemy count drifted from its documented formula" % wave)
		_check(spawner._enemies_per_second() > 0.0 and spawner._enemies_per_second() <= 15.0, "wave %d spawn rate is invalid" % wave)
		_check(spawner._journey_duration_for_wave() >= spawner.journey_duration_seconds, "wave %d journey duration is too short" % wave)
	spawner.queue_free()

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
	var native_tracks: Array[AudioStream] = music_player._load_native_playlist()
	_check(native_tracks.size() == 20, "native gameplay playlist should retain all 20 songs")
	var unique_paths: Dictionary = {}
	for track in native_tracks:
		unique_paths[track.resource_path] = true
		_check(track.resource_path.begins_with("res://assets/audio/songs/"), "gameplay playlist contains a track outside the songs folder")
	_check(unique_paths.size() == 20, "native gameplay playlist contains duplicate songs")
	_check(music_player.WEB_TRACKS.size() == 1, "web gameplay playlist should remain a minimal one-track payload")
	main.queue_free()

func _test_game_over_modes() -> void:
	var mission: GameOverOverlay = GameOverScene.instantiate()
	add_child(mission)
	mission.show_failure(false)
	_check(mission.visible and get_tree().paused, "mission failure did not freeze gameplay and show its overlay")
	_check(mission._title_art.texture.resource_path.ends_with("GAME_OVER_TEXT.webp"), "normal level loss did not use the supplied GAME OVER artwork")
	_check(mission._primary_button.get_meta("failure_action") == "restart_level", "normal level loss did not offer Restart Level")
	_check(not mission._primary_button.get_rect().intersects(mission._menu_button.get_rect()), "failure action buttons overlap")
	_check(is_equal_approx(mission._dim.color.a, 0.0), "failure overlay should begin its dimmer fade from transparent")
	get_tree().paused = false
	mission.queue_free()

	var challenge: GameOverOverlay = GameOverScene.instantiate()
	add_child(challenge)
	challenge.show_failure(true)
	_check(challenge._title_art.texture.resource_path.ends_with("GAME_OVER_TEXT.webp"), "challenge loss did not use the supplied GAME OVER artwork")
	_check(challenge._primary_button.get_meta("failure_action") == "retry_challenge", "challenge loss did not offer Retry Challenge")
	_check(challenge._menu_button.texture_normal.resource_path.contains("951252df"), "failure overlay did not use the supplied Main Menu button")
	get_tree().paused = false
	challenge.queue_free()

func _test_title_feature_modals() -> void:
	var title = TitleScene.instantiate()
	add_child(title)
	await get_tree().process_frame
	title._show_level_select()
	_check(title.modal.visible and title.modal_title.text == "LEVEL SELECT", "level-select grid did not replace its placeholder")
	await get_tree().process_frame
	title._show_options()
	_check(title._modal_content().find_children("*", "HSlider", true, false).size() == 2, "settings modal is missing separate music and SFX sliders")
	await get_tree().process_frame
	title._show_almanac()
	_check(title.modal_title.text == "ALMANAC", "Almanac grid did not open")
	await get_tree().process_frame
	title._show_achievements()
	_check(title.modal_title.text == "ACHIEVEMENTS", "achievement medal list did not open")
	await get_tree().process_frame
	title._show_profiles()
	_check(title.modal_title.text == "PROFILES", "three-slot profile selector did not open")
	title.queue_free()
	await get_tree().process_frame

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
	_check(not main.menu.get_node("NewIllustratedUi").visible, "normal-play illustrated UI remains behind Spider Assault")
	_check(main.get_node("Board").texture.resource_path == "res://assets/the_new_map.png", "Spider Assault is not using the clean new map background")
	var nest_rect: Rect2 = assault.get_node("SpiderNest").get_rect()
	_check(nest_rect.end.x <= 350.0, "Spider Nest overlaps the center board, rect is %s" % nest_rect)
	_check(assault.get_node("AssaultStatus").get_rect().position.x >= 1030.0, "Spider Assault status panel overlaps the center board")
	var assault_music := main.get_node("MusicPlayer") as AudioStreamPlayer
	_check(assault_music.tracks.size() == 1, "Spider Assault did not replace the shuffled music playlist")
	_check(assault_music.stream.resource_path.ends_with("Spider Assault - The Fun House.mp3"), "Spider Assault loaded the wrong level song")
	_check((assault_music.stream as AudioStreamMP3).loop, "Spider Assault level song is not configured to loop")
	_check(main.convoys.size() == 2, "Spider Assault did not create its two-train defense")
	var engine_blocker: Node = main.convoys[0].get_node_or_null("SpiderBlocker")
	_check(engine_blocker is AnimatableBody2D, "Spider Assault train blocker is not synchronised with the moving train")
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
	_check(deployed != null and deployed.has_route_target, "player-deployed spider did not receive an entrance lane")
	_check(deployed != null and is_equal_approx(float(deployed.route_target.x), float(SpiderAssaultController.ENTRANCES[0].world.x)), "Spider Assault spider cut diagonally out of its selected lane")
	_check(deployed != null and is_equal_approx(float(deployed.get_meta("assault_lane_x")), float(deployed.global_position.x)), "Spider Assault did not retain the selected normal-game lane")
	var blocked_cars := 0
	for convoy in main.convoys:
		for car in convoy.followers:
			if car.get_node_or_null("SpiderBlocker") is AnimatableBody2D:
				blocked_cars += 1
	_check(blocked_cars == defensive_cars, "one or more Spider Assault turret cars allow spiders to pass through")
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
	_check(main.menu.get_node("NewIllustratedUi").visible, "normal play lost its illustrated UI background")
	_check(main.get_node("Board").texture.resource_path == "res://assets/the_new_map.png", "normal play lost the shared new map background")
	_check(main.menu.wave_banner != null, "HUD did not create the wave-start banner")
	main.menu._show_wave_start_cue(3)
	_check(main.menu.wave_banner.text == "WAVE 3 — DEFEND!", "wave-start cue did not identify the active wave")
	if main.menu._wave_banner_tween and main.menu._wave_banner_tween.is_valid():
		main.menu._wave_banner_tween.kill()
	var pause_menu: PauseMenu = main.menu.pause_menu
	_check(pause_menu != null, "main HUD did not create the pause menu")
	pause_menu.open()
	_check(get_tree().paused and pause_menu.visible, "pause menu did not pause gameplay")
	_check(pause_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "pause menu cannot process input while paused")
	_check(pause_menu.get_node_or_null("Shade/Card/Margin/Content/RestartButton") != null, "pause menu is missing restart")
	_check(pause_menu.get_node_or_null("Shade/Card/Margin/Content/TitleButton") != null, "pause menu is missing return to title")
	_check(pause_menu.volume_slider != null and pause_menu.mute_check != null, "pause menu is missing audio settings")
	_check(pause_menu.fullscreen_check != null, "pause menu is missing display settings")
	_check(main.get_node_or_null("TutorialDirector") is TutorialDirector, "main campaign scene is missing first-run instructions")
	pause_menu.close()
	_check(not get_tree().paused and not pause_menu.visible, "resume did not restore gameplay")
	_check(main.convoys.size() == 1, "normal level should begin with exactly one free locomotive")
	_check(main.track_routes.size() >= 2, "normal level should retain routes for purchased locomotives")
	if not main.convoys.is_empty():
		_check(main.convoys[0].path == main.track_routes[1], "first mission locomotive did not start on the bottom rail")
		var preview_screen_position: Vector2 = main.get_viewport().get_canvas_transform() * main.convoys[0].global_position
		main._on_train_drag_updated(0, preview_screen_position, 1)
		_check(main.car_placement_ghost.visible, "valid train drag did not show a track-snapped placement ghost")
		var preview_fire_direction: Vector2 = main.car_placement_ghost.get("_fire_direction")
		main._on_train_drag_updated(0, preview_screen_position, -1)
		_check(main.car_placement_ghost.get("_fire_direction").dot(preview_fire_direction) < -0.99, "right-click facing did not flip the placement arrow")
		main._hide_car_placement_ghost()
		_check(main.convoys[0].car_count() >= 1, "starter car was rejected or missing")
		var starter_car: Node2D = main.convoys[0].followers[0]
		var starter_data := BuildManager.towers[0]
		var fire_rate_before := float(starter_car.get("bps"))
		LevelManager.currency = UnitUpgradePanel.COSTS[0]
		main.upgrade_panel.open_for(starter_car, main.convoys[0], starter_data)
		main.upgrade_panel._select_node(0, 0)
		main.upgrade_panel._buy_selected()
		_check(LevelManager.currency == 0, "upgrade purchase did not spend its listed cost")
		_check(is_equal_approx(float(starter_car.get("bps")), fire_rate_before * 1.25), "Rapid Fire upgrade did not apply its documented multiplier")
		_check(main.upgrade_panel._levels()[0] == 1, "purchased upgrade level was not persisted on the car")
		main.upgrade_panel.close_panel()
		main._select_convoy(main.convoys[0])
		await get_tree().create_timer(0.2).timeout
		_check(main.train_control_panel._expansion > 0.9, "engine selection did not expand train controls")
		_check(main.train_control_panel.size.y <= 44.0, "selected-engine indicator obscures too much battlefield")
		var selected: TrainConvoy = main.convoys[0]
		var cruise_before := selected.cruise_speed
		selected.set_manual_axis(1, 0.2)
		selected._update_speed(0.5)
		_check(selected.current_speed > cruise_before, "Up override did not accelerate the selected engine")
		selected.current_speed = selected.cruise_speed
		selected.set_manual_axis(-1, 0.2)
		selected._update_speed(0.5)
		_check(selected.current_speed > 0.0 and selected.current_speed < selected.cruise_speed, "short Down override did not slow without parking")
		selected.set_manual_axis(-1, selected.REVERSE_HOLD_SECONDS)
		for step in range(5): selected._update_speed(0.5)
		_check(selected.current_speed < 0.0, "held Down override did not reverse the selected engine")
		var placement: Dictionary = main._nearest_free_rail_placement(main.track_routes[1][2])
		_check(not placement.is_empty(), "empty railway rejected purchased-engine placement")
		LevelManager.currency = Menu.ENGINE_COST
		main._on_engine_drop_requested(main.get_viewport().get_canvas_transform() * main.track_routes[1][2])
		_check(main.convoys.size() == 2 and LevelManager.currency == 0, "purchased locomotive was not placed using the shared convoy system")
		main._clear_train_selection()
		await get_tree().create_timer(0.2).timeout
		_check(main.train_control_panel._expansion < 0.1, "train controls did not collapse after deselection")
	main.queue_free()
	await get_tree().process_frame
