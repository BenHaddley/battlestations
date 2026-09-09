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
	# Persisted side effects (discoveries, tutorial flags, campaign saves) must
	# never land in a real career while the suite runs.
	ProfileManager.use_sandbox_root("user://regression_sandbox")
	_check(_test_convoy_spacing_and_reverse() == true, "_test_convoy_spacing_and_reverse aborted on a script error")
	_check(_test_campaign_track_library() == true, "_test_campaign_track_library aborted on a script error")
	_check(_test_content_catalogs() == true, "_test_content_catalogs aborted on a script error")
	_check(_test_mail_carrier() == true, "_test_mail_carrier aborted on a script error")
	_check(_test_wallet_wave_and_selection_rules() == true, "_test_wallet_wave_and_selection_rules aborted on a script error")
	_check(_test_challenge_job_cards() == true, "_test_challenge_job_cards aborted on a script error")
	_check(_test_music_playlist_rotation() == true, "_test_music_playlist_rotation aborted on a script error")
	_check(_test_game_over_modes() == true, "_test_game_over_modes aborted on a script error")
	_check((await _test_title_feature_modals()) == true, "_test_title_feature_modals aborted on a script error")
	_check((await _test_reported_combat_regressions()) == true, "_test_reported_combat_regressions aborted on a script error")
	_check((await _test_station_attackers()) == true, "_test_station_attackers aborted on a script error")
	_check((await _test_spider_assault()) == true, "_test_spider_assault aborted on a script error")
	_check((await _test_main_scene_train_integration()) == true, "_test_main_scene_train_integration aborted on a script error")
	_check((await _test_wave_button_and_phase_clock()) == true, "_test_wave_button_and_phase_clock aborted on a script error")
	_check((await _test_rail_building()) == true, "_test_rail_building aborted on a script error")
	_check((await _test_train_obstacles()) == true, "_test_train_obstacles aborted on a script error")
	_check((await _test_range_preview_and_readout()) == true, "_test_range_preview_and_readout aborted on a script error")
	_check((await _test_lessons_and_profiles()) == true, "_test_lessons_and_profiles aborted on a script error")
	_check(_test_audio_normalization() == true, "_test_audio_normalization aborted on a script error")
	# Let short procedural/audio one-shots finish and release their players before
	# ObjectDB performs its exit leak check.
	await get_tree().create_timer(0.25).timeout
	if failures.is_empty():
		print("GAMEPLAY REGRESSION PASS")
		get_tree().quit(0)
	else:
		print("GAMEPLAY REGRESSION FAIL: %s" % [failures])
		get_tree().quit(1)

func _test_reported_combat_regressions() -> bool:
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
	# A lined-up spider at the far side of the board must be reached before
	# ordinary lane movement carries it away from the fixed firing ray.
	collision_enemy.position = Vector2(1400.0, 300.0)
	add_child(collision_enemy)
	collision_enemy.health.configure_hit_points(5)
	var swept_bullet: Bullet = BasicBulletScene.instantiate()
	swept_bullet.process_mode = Node.PROCESS_MODE_DISABLED
	swept_bullet.position = Vector2(0.0, 300.0)
	add_child(swept_bullet)
	swept_bullet.set_direction(Vector2.RIGHT)
	await get_tree().physics_frame
	swept_bullet._physics_process(0.25)
	_check(collision_enemy.health.is_destroyed, "straight Gunner projectile failed to one-hit a far level-one spider")
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

	# Both campaign gun cars restore circular targeting, rotating art and aimed shots.
	for scene in [BasicTurretScene, MinigunScene]:
		var swivel: Turret = scene.instantiate()
		add_child(swivel)
		swivel.set_process(false)
		_check(not swivel.fixed_direction_enabled, "gun car still defaults to direction locking")
		_check(swivel.train_chassis.visible and swivel.turret_rotation_point.get_node("Top").visible and not swivel._fixed_art.visible, "gun car did not restore swivelling artwork")
		var side_target := Node2D.new()
		add_child(side_target)
		side_target.position = Vector2.LEFT * 100.0
		swivel.target = side_target
		_check(swivel._target_in_range(), "swivel gun rejected a target on the opposite side")
		swivel._rotate_towards_target(10.0)
		_check(is_equal_approx(wrapf(swivel.turret_rotation_point.rotation, -PI, PI), -PI / 2.0), "swivel gun did not rotate toward its target")
		if swivel.has_method("_fire_burst_round"):
			swivel._fire_burst_round(0)
		else:
			swivel._shoot()
		var aimed_bullet := _latest_minigun_bullet()
		_check(aimed_bullet != null and aimed_bullet.target == side_target, "swivel gun did not fire a targeted projectile")
		if aimed_bullet:
			aimed_bullet.free()
		side_target.position = Vector2.LEFT * (swivel.targeting_range + 50.0)
		_check(not swivel._target_in_range(), "swivel gun ignored its circular range limit")
		swivel.queue_free()
		side_target.queue_free()

	var minigun: Turret = MinigunScene.instantiate()
	add_child(minigun)
	# The directional experiment remains opt-in in the debug sandbox.
	minigun.set_fixed_direction_enabled(true)
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
	var rounds_before := int(minigun.get("total_rounds_fired"))
	minigun._shoot()
	_check(int(minigun.get("total_rounds_fired")) == rounds_before + 1, "Chaingunner emitted more than one bullet on its initial burst frame")
	var first_bullet: Bullet = _latest_minigun_bullet()
	_check(first_bullet != null and first_bullet.target == null and first_bullet.travel_direction.is_equal_approx(Vector2.RIGHT), "directional gun projectile still homes instead of travelling straight")
	await get_tree().create_timer(minigun.get("burst_interval") * 1.2).timeout
	_check(int(minigun.get("total_rounds_fired")) == rounds_before + 2, "Chaingunner rounds are not arriving sequentially")
	await get_tree().create_timer(minigun.get("burst_interval") * 6.2).timeout
	_check(int(minigun.get("total_rounds_fired")) == rounds_before + 7, "Chaingunner burst did not emit exactly seven rounds")
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
	return true

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

func _test_convoy_spacing_and_reverse() -> bool:
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
	return true

func _test_challenge_job_cards() -> bool:
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
	return true

func _test_campaign_track_library() -> bool:
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
	return true

func _test_content_catalogs() -> bool:
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
		"res://resources/mail_carrier.tres",
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
	return true

func _test_wallet_wave_and_selection_rules() -> bool:
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
	return true

func _test_music_playlist_rotation() -> bool:
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
	return true

func _test_game_over_modes() -> bool:
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
	return true

func _test_title_feature_modals() -> bool:
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
	return true

func _test_station_attackers() -> bool:
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
	return true

func _test_spider_assault() -> bool:
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
	return true

func _test_main_scene_train_integration() -> bool:
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
	_check(main.menu.mail_carrier_button != null and main.menu.mail_carrier_button.get_parent() == main.menu.tender_button.get_parent(), "Mail Carrier shop row is missing")
	_check(main.convoys.size() == 1, "normal level should begin with exactly one free locomotive")
	_check(main.track_routes.size() >= 2, "normal level should retain routes for purchased locomotives")
	if not main.convoys.is_empty():
		_check(main.convoys[0].path == main.track_routes[1], "first mission locomotive did not start on the bottom rail")
		var preview_screen_position: Vector2 = main.get_viewport().get_canvas_transform() * main.convoys[0].global_position
		main._on_train_drag_updated(0, preview_screen_position, 1)
		_check(main.car_placement_ghost.visible, "valid train drag did not show a track-snapped placement ghost")
		_check(not main.car_placement_ghost.get("_directional"), "swivel gun placement still shows a fixed-direction arrow")
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
	return true

## The START WAVE control must return during every STATION window (including
## before wave two and later), disable itself during BATTLE, never start a
## wave twice, and never wake the clock underneath a level-complete card even
## when Duck and Daisy finish talking after the final wave has cleared.
func _test_wave_button_and_phase_clock() -> bool:
	CampaignManager.clear_challenge()
	CampaignManager.current_level_index = 0
	CampaignManager.tutorial_requested = false
	CampaignManager.reset_for_current_level()
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	var director: TutorialDirector = main.get_node("TutorialDirector")
	director._skip_all()
	await get_tree().process_frame
	var button: Button = main.menu.station_progress_panel.skip_button
	var focus_free := true
	for button_name in Menu.TOWER_BUTTONS:
		var tower_button: Button = main.menu.get(button_name)
		focus_free = focus_free and tower_button.focus_mode == Control.FOCUS_NONE
	_check(focus_free and button.focus_mode == Control.FOCUS_NONE and main.menu.remove_button.focus_mode == Control.FOCUS_NONE, "HUD buttons can take keyboard focus away from train driving")
	_check(main.train_driving_enabled(), "train driving is disabled on a plain board")
	main.menu.pause_menu.open()
	_check(not main.train_driving_enabled(), "arrow keys still drive trains while the pause card is open")
	main.menu.pause_menu.close()
	_check(PhaseManager.is_station() and button.text == "START WAVE 1" and not button.disabled, "wave one start button is missing before the first wave, saw '%s'" % button.text)
	_check(PhaseManager.request_wave_start(), "START WAVE did not start wave one")
	_check(not PhaseManager.request_wave_start(), "a second press started a wave while one was underway")
	await get_tree().process_frame
	_check(main.spawner.current_wave == 1 and button.disabled and button.text == "WAVE 1 UNDERWAY", "wave button stayed enabled during BATTLE, saw '%s'" % button.text)
	main.spawner._end_wave()
	await get_tree().process_frame
	_check(PhaseManager.is_station() and button.text == "START WAVE 2" and not button.disabled, "wave button did not return before wave two, saw '%s'" % button.text)
	# A lesson holds the departure clock but never removes the player's control.
	PhaseManager.dialogue_hold = true
	PhaseManager._process(1000.0)
	_check(main.spawner.current_wave == 1, "held departure clock auto-started a wave")
	await get_tree().process_frame
	_check(not button.disabled and PhaseManager.request_wave_start(), "player could not start wave two while a lesson held the clock")
	PhaseManager.dialogue_hold = false
	main.spawner._end_wave()
	_check(main.spawner.current_wave == 2 and PhaseManager.is_station(), "wave two did not clear back to STATION")
	_check(PhaseManager.request_wave_start(), "START WAVE did not start the final wave")
	# Final wave: dialogue is still on screen when it clears. Dismissing the
	# dialogue must not release the level-complete pause.
	director._enqueue([director._entry("Duck", "Final wave chatter.")])
	main.spawner._end_wave()
	_check(main.spawner.level_finished and PhaseManager.paused, "final wave clear did not hand the clock to the level-complete flow")
	_check(main.level_complete_overlay.visible, "level-complete card did not appear after the final wave")
	director._skip_all()
	PhaseManager._process(1000.0)
	_check(PhaseManager.paused and main.spawner.current_wave == 3 and not main.spawner.is_spawning, "dismissing dialogue after the final wave restarted the station clock")
	_check(not PhaseManager.request_wave_start(), "wave started underneath the level-complete card")
	await get_tree().process_frame
	_check(button.disabled and button.text == "LEVEL COMPLETE", "wave button offered a wave after the level finished, saw '%s'" % button.text)
	main.queue_free()
	await get_tree().process_frame
	PhaseManager.reset()
	CampaignManager.current_level_index = 0
	return true

## STATIONS rail building on the Boiler Room board: loop A is the 4x4 ring at
## cells (2..6, 2..6); loop B, which carries the starting train, is the 8x4
## ring at (0..8, 7..11).
func _test_rail_building() -> bool:
	CampaignManager.clear_challenge()
	CampaignManager.current_level_index = 0
	CampaignManager.tutorial_requested = false
	CampaignManager.reset_for_current_level()
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	(main.get_node("TutorialDirector") as TutorialDirector)._skip_all()
	var track: TrackRenderer = main.track
	var builder: RailBuilder = main.rail_builder
	var cost: int = builder.rail_cost
	_check(cost == 50, "provisional rail price is not Δ50")
	_check(track.is_rail(Vector2i(2, 2)) and track.is_rail(Vector2i(0, 7)), "campaign rings did not seed the rail graph")
	_check(track.graph.size() == 16 + 24, "rail graph cell count does not match the two authored rings")
	var candidates: Array[Vector2i] = track.expansion_candidates(Vector2i(2, 2))
	_check(candidates.size() == 2 and Vector2i(2, 1) in candidates and Vector2i(1, 2) in candidates, "corner hover did not offer exactly its two empty neighbours")
	_check(track.expansion_candidates(Vector2i(4, 4)).is_empty(), "an empty tile offered plus signs")
	_check(builder.active() and PhaseManager.is_station(), "rail builder is inactive during STATION")

	# Dead-end spur: charged once, capped with the buffer-stop art.
	LevelManager.currency = 300
	_check(builder.attempt_build(Vector2i(2, 2), Vector2i(2, 1)), "valid rail placement was refused")
	_check(LevelManager.currency == 300 - cost, "rail purchase charged the wrong amount")
	_check(track.is_built(Vector2i(2, 1)) and track.is_dead_end(Vector2i(2, 1)), "new spur tile is not a single-link dead end")
	_check(track.tiles_at(Vector2i(2, 1)).size() == 1 and String(track.tiles_at(Vector2i(2, 1))[0].get_meta("piece")) == "end", "dead end did not receive buffer-stop art")
	_check(track.tiles_at(Vector2i(2, 2)).size() == 2, "junction under the new spur did not gain a branch piece")
	_check(builder.attempt_build(Vector2i(2, 1), Vector2i(2, 0)), "spur could not be extended from its own end")
	_check(String(track.tiles_at(Vector2i(2, 1))[0].get_meta("piece")) == "straight", "extended spur kept its end cap")

	# Refusals leave the wallet and railway untouched.
	var before_currency := LevelManager.currency
	var before_cells := track.graph.size()
	_check(not track.evaluate_placement(Vector2i(2, 2), Vector2i(3, 2)).ok, "placement onto existing rail was accepted")
	_check(not track.evaluate_placement(Vector2i(2, 2), Vector2i(4, 4)).ok, "placement away from the anchor was accepted")
	_check(builder.attempt_build(Vector2i(2, 6), Vector2i(1, 6)), "spur toward loop B could not be laid")
	var join_verdict: Dictionary = track.evaluate_link(Vector2i(1, 6), Vector2i(1, 7))
	_check(not join_verdict.ok and String(join_verdict.reason).contains("separate circuits"), "joining two separate circuits was accepted")
	_check(track.link_candidates(Vector2i(1, 6)).is_empty(), "a foreign circuit was offered as a join target")
	_check(builder.attempt_remove(Vector2i(1, 6)) and LevelManager.currency == before_currency and track.graph.size() == before_cells, "probe spur could not be lifted for a refund")
	LevelManager.currency = cost - 1
	_check(not builder.attempt_build(Vector2i(2, 0), Vector2i(1, 0)), "unaffordable rail was laid")
	_check(LevelManager.currency == cost - 1 and track.graph.size() == before_cells, "refused placement changed the wallet or railway")
	LevelManager.currency = before_currency
	_check(PhaseManager.request_wave_start(), "could not start a wave for the BATTLE gating check")
	_check(not builder.active(), "rail builder stayed active during BATTLE")
	_check(not builder.attempt_build(Vector2i(2, 0), Vector2i(1, 0)), "rail was laid during BATTLE")
	_check(track.graph.size() == before_cells and LevelManager.currency == before_currency, "BATTLE placement attempt changed state")
	main.spawner._end_wave()
	_check(PhaseManager.is_station() and builder.active(), "rail builder did not return after the wave")
	LevelManager.currency = 1000

	# Spurs are dismantled from the end; lifting a middle tile would strand
	# the rail beyond it.
	_check(not track.remove_rail(Vector2i(3, 2)).ok, "authored rail could be removed")
	_check(not track.remove_rail(Vector2i(2, 1)).ok, "removing a mid-spur tile stranded the track beyond it")
	var refund_before := LevelManager.currency
	_check(builder.attempt_remove(Vector2i(2, 0)) and builder.attempt_remove(Vector2i(2, 1)), "spur could not be dismantled from its end")
	_check(LevelManager.currency == refund_before + 2 * cost, "lifted rail was not refunded in full")
	_check(track.built_cells.is_empty() and track.graph.size() == 40, "dismantling did not return the railway to its authored state")

	# A detour that leaves loop A at (3,2) and rejoins at (5,2) is longer than
	# the two-step stretch it bypasses, so joining it reroutes the circuit.
	var loop_a_before: int = track.routes[0].size()
	for step in [[Vector2i(3, 2), Vector2i(3, 1)], [Vector2i(3, 1), Vector2i(3, 0)], [Vector2i(3, 0), Vector2i(4, 0)], [Vector2i(4, 0), Vector2i(5, 0)], [Vector2i(5, 0), Vector2i(5, 1)]]:
		_check(builder.attempt_build(step[0], step[1]), "detour tile %s was refused" % step[1])
	_check(track.route_index_of(Vector2i(4, 0)) == -1 and track.routes[0].size() == loop_a_before, "open detour was adopted before it was joined")
	var joins: Array = track.link_candidates(Vector2i(5, 1))
	_check(joins.size() == 1 and joins[0][1] == Vector2i(5, 2), "dead end beside the circuit did not offer exactly one join")
	_check(builder.attempt_link(Vector2i(5, 1), Vector2i(5, 2)), "closing join was refused")
	_check(track.routes[0].size() == loop_a_before - 1 + 5 and track.routes_are_traversable(), "joined detour did not reroute loop A, ring has %d cells" % track.routes[0].size())
	_check(track.route_index_of(Vector2i(4, 0)) == 0 and track.route_index_of(Vector2i(4, 2)) == -1, "rerouted ring did not swap the bypassed stretch for the detour")
	_check(track.is_rail(Vector2i(4, 2)), "bypassed rail was deleted instead of kept as a siding")
	# A tile in the notch is a shortcut: it is laid, but joining it through
	# the authored siding never rewrites the circuit into a zigzag.
	_check(builder.attempt_build(Vector2i(4, 0), Vector2i(4, 1)), "shortcut tile was refused")
	_check(track.link_candidates(Vector2i(4, 1)).size() == 3, "notch tile did not offer joins to its three neighbours")
	_check(builder.attempt_link(Vector2i(4, 1), Vector2i(4, 2)), "shortcut join was refused")
	_check(track.route_index_of(Vector2i(4, 1)) == -1 and track.routes[0].size() == loop_a_before + 4, "a shortcut rerouted the ring")

	# Lifting any detour tile drops the whole detour and restores the stretch.
	refund_before = LevelManager.currency
	_check(builder.attempt_remove(Vector2i(4, 0)), "detour tile could not be lifted")
	_check(LevelManager.currency == refund_before + cost, "lifted detour tile was not refunded")
	_check(not track.is_rail(Vector2i(4, 0)) and track.routes[0].size() == loop_a_before and track.route_index_of(Vector2i(4, 2)) == 0, "lifting a detour tile did not restore the original stretch")
	_check(track.is_rail(Vector2i(3, 0)) and track.is_dead_end(Vector2i(3, 0)), "leftover detour pieces were not kept as a spur")
	for cell in [Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 0), Vector2i(5, 1)]:
		_check(builder.attempt_remove(cell), "leftover tile %s could not be lifted" % cell)
	_check(track.built_cells.is_empty() and track.routes[0].size() == loop_a_before, "loop A did not return to its authored ring")

	# The starting train drives loop B. A detour built on its bottom edge is
	# adopted immediately, but the convoy only rebinds once its whole consist
	# is on track both rings share.
	var convoy: TrainConvoy = main.convoys[0]
	_check(convoy.route_index == 1 and convoy.path == track.routes[1], "starting train is not bound to loop B")
	var bottom_edge := track.cell_of(track.routes[1][14])
	_check(bottom_edge == Vector2i(6, 11), "loop B ring order changed; expected cell (6,11) at index 14, got %s" % bottom_edge)
	# Park the engine 30 units into the stretch the detour will bypass.
	convoy.place_at_route_distance(convoy.segment_starts[14] + 30.0)
	var loop_b_before: int = track.routes[1].size()
	var engine_position := convoy.global_position
	_check(builder.attempt_build(Vector2i(4, 11), Vector2i(4, 10)) and builder.attempt_build(Vector2i(4, 10), Vector2i(5, 10)) and builder.attempt_build(Vector2i(5, 10), Vector2i(6, 10)), "loop B detour could not be built")
	_check(builder.attempt_link(Vector2i(6, 10), Vector2i(6, 11)), "loop B detour could not be joined")
	_check(track.routes[1].size() == loop_b_before + 2, "loop B did not adopt its detour")
	_check(main.pending_rebinds.has(convoy) and convoy.path.size() == loop_b_before, "convoy on the bypassed stretch was rebound while still standing on it")
	_check(convoy.global_position.is_equal_approx(engine_position), "pending rebind moved the train")
	for step in range(80):
		convoy._advance_safely(5.0)
		main._retry_pending_rebinds()
		_check(convoy._positions_valid_at(convoy.route_distance, convoy.followers.size()), "consist overlapped while a rebind was pending")
	_check(not main.pending_rebinds.has(convoy) and convoy.path.size() == loop_b_before + 2, "convoy never adopted the revised loop after leaving the bypassed stretch")
	# Rail under a standing train cannot be lifted.
	var detour_index := -1
	for index in range(convoy.path.size()):
		if track.cell_of(convoy.path[index]) == Vector2i(5, 10):
			detour_index = index
	_check(detour_index >= 0, "rebound convoy path does not include the detour")
	convoy.place_at_route_distance(convoy.segment_starts[detour_index])
	_check(main.rail_cell_occupied(Vector2i(5, 10)), "occupancy check missed the engine standing on the detour")
	var occupied_currency := LevelManager.currency
	_check(not builder.attempt_remove(Vector2i(5, 10)) and track.is_rail(Vector2i(5, 10)) and LevelManager.currency == occupied_currency, "rail under a train could be lifted")

	# Locomotives need a closed circuit: a dead end refuses, a closed lobe
	# off loop A becomes a circuit of its own.
	_check(builder.attempt_build(Vector2i(2, 2), Vector2i(2, 1)), "lobe spur could not be started")
	var convoys_before: int = main.convoys.size()
	LevelManager.currency = Menu.ENGINE_COST
	main._on_engine_drop_requested(main.get_viewport().get_canvas_transform() * track.world_of(Vector2i(2, 1)))
	_check(main.convoys.size() == convoys_before and LevelManager.currency == Menu.ENGINE_COST, "a locomotive was parked on a dead end")
	_check(main.menu.placement_banner_label.text.contains("dead-ends"), "dead-end refusal did not explain itself, saw '%s'" % main.menu.placement_banner_label.text)
	LevelManager.currency = 1000
	_check(builder.attempt_build(Vector2i(2, 1), Vector2i(1, 1)) and builder.attempt_build(Vector2i(1, 1), Vector2i(1, 2)), "lobe could not be built")
	_check(builder.attempt_link(Vector2i(1, 2), Vector2i(2, 2)), "lobe could not be closed")
	_check(track.route_index_of(Vector2i(1, 1)) == -1 and track.routes[0].size() == loop_a_before, "a single-cell lobe was spliced into loop A")
	var routes_before: int = track.routes.size()
	LevelManager.currency = Menu.ENGINE_COST
	main._on_engine_drop_requested(main.get_viewport().get_canvas_transform() * track.world_of(Vector2i(1, 1)))
	_check(main.convoys.size() == convoys_before + 1 and track.routes.size() == routes_before + 1 and LevelManager.currency == 0, "closed lobe did not become a circuit for a new locomotive")
	_check(main.convoys[-1].path.size() == 4 and main.convoys[-1].route_index == routes_before, "lobe locomotive is not driving the four-cell lobe")
	main.queue_free()
	await get_tree().process_frame
	PhaseManager.reset()
	CampaignManager.current_level_index = 0
	return true

## Spiders steer round trains, bite when boxed in (about 25 DPS in ticks),
## take one Gunner bullet from a moving train that recoils, and destroyed
## cars or engines never corrupt the consist.
func _test_train_obstacles() -> bool:
	var dummy := Node2D.new()
	add_child(dummy)
	var health := UnitHealth.attach_to(dummy, 200.0, "Test Car")
	var destroyed_units: Array = []
	health.destroyed.connect(func(unit: Node2D) -> void: destroyed_units.append(unit))
	health.take_damage(50.0, true)
	_check(is_equal_approx(health.hit_points, 150.0) and health.is_damaged(), "unit health did not record bite damage")
	health.take_damage(150.0)
	_check(health.is_destroyed and destroyed_units.size() == 1 and destroyed_units[0] == dummy, "unit health did not announce its destruction")
	health.take_damage(10.0)
	_check(destroyed_units.size() == 1, "destroyed unit announced destruction twice")
	dummy.queue_free()

	# A lone unit ahead: step into the clear neighbouring lane and keep going.
	var blocker := Node2D.new()
	blocker.position = Vector2(0.0, 90.0)
	blocker.add_to_group("train_units")
	add_child(blocker)
	UnitHealth.attach_to(blocker, 200.0, "Blocker")
	var spider: EnemyMovement = EnemyScene.instantiate()
	add_child(spider)
	spider.global_position = Vector2.ZERO
	spider.configure_route(Vector2(0.0, 600.0), 10.0)
	for step in range(120):
		spider._physics_process(1.0 / 60.0)
	_check(not spider.is_biting() and is_equal_approx(absf(spider.route_target.x), 65.5), "spider did not sidestep round a lone train unit, lane x is %f" % spider.route_target.x)
	_check(spider.global_position.y > 0.0, "sidestepping spider stopped advancing")
	_check(spider._blocking_unit(Vector2.DOWN).is_empty(), "spider still saw the unit as blocking after moving lanes")
	spider.queue_free()
	blocker.queue_free()

	# Every lane within three steps blocked: stop and bite the unit in contact.
	var wall: Array[Node2D] = []
	for lane_x in [-196.5, -131.0, -65.5, 0.0, 65.5, 131.0, 196.5]:
		var unit := Node2D.new()
		unit.position = Vector2(lane_x, 140.0)
		unit.add_to_group("train_units")
		add_child(unit)
		UnitHealth.attach_to(unit, 200.0, "Wall")
		wall.append(unit)
	var biter: EnemyMovement = EnemyScene.instantiate()
	add_child(biter)
	biter.global_position = Vector2(0.0, 100.0)
	biter.configure_route(Vector2(0.0, 600.0), 10.0)
	var wall_health := UnitHealth.of(wall[3])
	for step in range(60):
		biter._physics_process(1.0 / 60.0)
	_check(biter.is_biting() and biter.biting_target == wall[3], "boxed-in spider did not bite the unit in front of it")
	_check(is_equal_approx(biter.global_position.y, 100.0), "biting spider kept walking")
	var chewed := 200.0 - wall_health.hit_points
	_check(chewed >= 24.0 and chewed <= 32.0, "bite damage over one second was %.2f, expected about 25" % chewed)
	_check(biter.bites_landed >= 4, "bite ticks did not land at the configured cadence")
	# The bitten unit disappears: the spider must recover and walk on.
	wall[3].free()
	biter._physics_process(1.0 / 60.0)
	biter._physics_process(1.0 / 60.0)
	_check(not biter.is_biting() and biter.global_position.y > 100.0, "spider stayed frozen after its bite target vanished")
	for unit in wall:
		if is_instance_valid(unit):
			unit.queue_free()
	biter.queue_free()

	# Ramming: one Gunner bullet per spider per cooldown, only at real speed,
	# and the train recoils.
	var convoy: TrainConvoy = ConvoyScene.instantiate()
	add_child(convoy)
	convoy.configure_path(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 520), Vector2(0, 520)]))
	convoy.current_speed = convoy.cruise_speed
	var victim: EnemyMovement = EnemyScene.instantiate()
	add_child(victim)
	victim.global_position = convoy.global_position
	victim.configure_route(Vector2(victim.global_position.x, 600.0), 25.0)
	victim.health.configure_hit_points(100)
	convoy._apply_impacts()
	_check(victim.health.hit_points == 80, "train impact did not deal one Gunner bullet of damage, HP is %d" % victim.health.hit_points)
	_check(convoy.current_speed < convoy.cruise_speed * 0.5 and convoy.impacts_landed == 1, "train did not recoil after striking a spider")
	convoy.current_speed = convoy.cruise_speed
	convoy._apply_impacts()
	_check(victim.health.hit_points == 80, "impact cooldown allowed a second strike immediately")
	victim._impact_cooldowns.clear()
	convoy.current_speed = convoy.cruise_speed * 0.3
	convoy._apply_impacts()
	_check(victim.health.hit_points == 80, "a crawling train still hurt a spider")
	victim.queue_free()

	# Losing a middle car closes the gap and keeps the survivors coupled.
	var car_a := Node2D.new()
	car_a.set_script(preload("res://tests/train_test_car.gd"))
	add_child(car_a)
	var car_b := Node2D.new()
	car_b.set_script(preload("res://tests/train_test_car.gd"))
	add_child(car_b)
	_check(convoy.attach_car(car_a) and convoy.attach_car(car_b), "test cars could not be coupled")
	var health_a := UnitHealth.attach_to(car_a, 200.0, "Car A")
	health_a.destroyed.connect(func(unit: Node2D) -> void: convoy.remove_car(unit))
	var tail_before := car_b.global_position
	health_a.take_damage(999.0)
	_check(convoy.followers.size() == 1 and convoy.followers[0] == car_b, "destroyed car was not removed from the consist")
	_check(not car_b.global_position.is_equal_approx(tail_before) and car_b.global_position.is_equal_approx(convoy._sample_route(convoy.route_distance - convoy.car_spacing).position), "surviving car did not close the gap behind the engine")
	_check(convoy._positions_valid_at(convoy.route_distance, convoy.followers.size()), "consist overlapped after a car was destroyed")
	convoy.queue_free()
	await get_tree().process_frame

	# A destroyed engine leaves a recoverable wreck.
	CampaignManager.clear_challenge()
	CampaignManager.current_level_index = 0
	CampaignManager.tutorial_requested = false
	CampaignManager.reset_for_current_level()
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	(main.get_node("TutorialDirector") as TutorialDirector)._skip_all()
	var train: TrainConvoy = main.convoys[0]
	_check(train.is_in_group("train_units") and train.followers[0].is_in_group("train_units"), "engine and starter car are not registered as spider obstacles")
	_check(UnitHealth.of(train.followers[0]) != null and is_equal_approx(UnitHealth.of(train.followers[0]).max_hit_points, 200.0), "starter Gunner did not receive its workbook health")
	_check(is_equal_approx(train.unit_health.max_hit_points, 300.0), "engine did not receive its workbook health")
	train.unit_health.take_damage(train.unit_health.max_hit_points)
	_check(train.wrecked, "destroyed engine did not wreck the train")
	train._process(0.5)
	_check(is_zero_approx(train.current_speed), "wrecked engine kept moving")
	_check(not train.can_attach_at(train.global_position), "cars could be coupled to a wreck")
	_check(train.followers.size() == 1 and is_instance_valid(train.followers[0]), "wreck lost its surviving car")
	var probe: EnemyMovement = EnemyScene.instantiate()
	add_child(probe)
	probe.global_position = train.global_position + Vector2(0.0, -70.0)
	probe.configure_route(Vector2(train.global_position.x, 600.0), 25.0)
	var wreck_seen: Dictionary = probe._blocking_unit(Vector2.DOWN)
	_check(wreck_seen.is_empty() or wreck_seen.unit != train, "a wrecked engine still blocks spiders")
	probe.queue_free()
	var convoy_count: int = main.convoys.size()
	LevelManager.currency = Menu.ENGINE_COST
	main._on_engine_drop_requested(main.get_viewport().get_canvas_transform() * train.global_position)
	_check(not train.wrecked and LevelManager.currency == 0 and main.convoys.size() == convoy_count, "dropping a locomotive on the wreck did not recover the train")
	_check(is_equal_approx(train.unit_health.hit_points, train.unit_health.max_hit_points) and train.current_speed != 0.0, "recovered engine is not back at full health and moving")
	main.queue_free()
	await get_tree().process_frame
	PhaseManager.reset()
	CampaignManager.current_level_index = 0
	return true

## Placement ghosts and hovered cars show the radius the gun really acquires
## at; utility cars show none; the controlled train reports weight, capacity
## and engine health; every shop surface shares the placed car's artwork.
func _test_range_preview_and_readout() -> bool:
	var gunner_art := CarArt.for_tower(BuildManager.towers[0])
	_check(is_equal_approx(float(gunner_art.range), 315.0) and gunner_art.top != null, "Gunner preview art is missing its radius or turret")
	_check(is_zero_approx(float(CarArt.for_tower(BuildManager.towers[3]).range)), "Passenger Coach preview reports an attack radius")
	_check(is_equal_approx(float(CarArt.for_tower(BuildManager.towers[7]).range), 225.0), "Mail Carrier preview does not report its 5×5 radius")
	for tower in BuildManager.towers:
		_check(CarArt.icon_for(tower) != null, "%s has no shop icon" % tower.tower_name)
	_check(CarArt.icon_for(BuildManager.towers[0]) is ImageTexture, "Gunner shop icon is not composited from its chassis and turret")
	_check(CarArt.icon_for(BuildManager.towers[6]) == CarArt.for_tower(BuildManager.towers[6]).base, "Tender icon should be its single placed sprite")

	# Acquisition matches the previewed radius instead of the scaled physics area.
	var gun: Turret = BasicTurretScene.instantiate()
	add_child(gun)
	gun.set_process(false)
	gun.scale = Vector2(0.54, 0.54)
	var far_spider: EnemyMovement = EnemyScene.instantiate()
	add_child(far_spider)
	far_spider.set_physics_process(false)
	far_spider.position = Vector2(300.0, 0.0)
	var near_spider: EnemyMovement = EnemyScene.instantiate()
	add_child(near_spider)
	near_spider.set_physics_process(false)
	near_spider.position = Vector2(-120.0, 0.0)
	_check(gun._find_target() == near_spider, "Gunner did not pick the nearest spider in range")
	near_spider.position = Vector2(-400.0, 0.0)
	_check(gun._find_target() == far_spider, "Gunner cannot acquire a spider at 300 units despite a 315 radius")
	far_spider.position = Vector2(330.0, 0.0)
	_check(gun._find_target() == null, "Gunner acquired a spider beyond its radius")
	var ballast: Turret = preload("res://scenes/TurretBallast.tscn").instantiate()
	add_child(ballast)
	ballast.set_process(false)
	ballast.scale = Vector2(0.54, 0.54)
	far_spider.position = Vector2(130.0, 0.0)
	_check(ballast._spiders_in_range().size() == 1, "Ballast Blaster area does not cover its 3×3 radius")
	gun.queue_free()
	ballast.queue_free()
	far_spider.queue_free()
	near_spider.queue_free()

	CampaignManager.clear_challenge()
	CampaignManager.current_level_index = 0
	CampaignManager.tutorial_requested = false
	CampaignManager.reset_for_current_level()
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	(main.get_node("TutorialDirector") as TutorialDirector)._skip_all()
	var convoy: TrainConvoy = main.convoys[0]
	var screen_engine: Vector2 = main.get_viewport().get_canvas_transform() * convoy.global_position
	main._on_train_drag_updated(0, screen_engine, 1)
	_check(main.car_placement_ghost.visible and is_equal_approx(main.car_placement_ghost.range_radius(), 315.0), "Gunner ghost does not draw its 315 radius")
	main._on_train_drag_updated(7, screen_engine, 1)
	_check(is_equal_approx(main.car_placement_ghost.range_radius(), 225.0), "Mail Carrier ghost does not draw its 5×5 radius")
	main._on_train_drag_updated(3, screen_engine, 1)
	_check(is_zero_approx(main.car_placement_ghost.range_radius()), "Passenger Coach ghost draws an attack radius")
	main._hide_car_placement_ghost()
	var starter: Node2D = convoy.followers[0]
	main.range_preview.follow(starter)
	_check(main.range_preview.visible and is_equal_approx(main.range_preview.radius(), 315.0), "hovered Gunner does not show its radius")
	starter.set("targeting_range", 400.0)
	main.range_preview._refresh()
	_check(is_equal_approx(main.range_preview.radius(), 400.0), "range ring did not follow an upgraded radius")
	starter.set("targeting_range", 315.0)
	main.range_preview.follow(null)
	_check(not main.range_preview.visible, "range ring lingered with nothing hovered")
	main._select_convoy(convoy)
	var status: String = main.train_control_panel.status_line()
	_check(status.contains("WEIGHT 150 / 1000") and status.contains("ENGINE HP 300 / 300"), "controlled-train readout is wrong: '%s'" % status)
	_check(convoy.selected and convoy.selected_number == 1, "selected engine is not marked as engine 1")
	_check(main.train_control_panel.size.y <= 44.0, "train readout grew tall enough to hide the station edge")
	main.upgrade_panel.open_for(starter, convoy, BuildManager.towers[0])
	_check(main.upgrade_panel.stats_label.text.contains("RANGE   4.8 tiles") and main.upgrade_panel.stats_label.text.contains("HP   200 / 200"), "upgrade card stats are wrong: '%s'" % main.upgrade_panel.stats_label.text)
	main.upgrade_panel.close_panel()
	main._clear_train_selection()
	main.queue_free()
	await get_tree().process_frame
	PhaseManager.reset()
	CampaignManager.current_level_index = 0
	return true

func _start_campaign_scene(level_index: int, new_game: bool) -> Node:
	CampaignManager.clear_challenge()
	CampaignManager.current_level_index = level_index
	CampaignManager.tutorial_requested = new_game
	CampaignManager.reset_for_current_level()
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	return main

## Duck and Daisy: the opening pairs its objective with a highlighted
## control, lessons persist per profile (a different profile sees the
## opening again), every unlocked car gets its own guided lesson, battle
## events wait for STATION, and replaying resets everything.
func _test_lessons_and_profiles() -> bool:
	ProfileManager.select_profile(1)
	TutorialDirector.reset_progress()
	var main = await _start_campaign_scene(0, true)
	var director: TutorialDirector = main.get_node("TutorialDirector")
	_check(director.tutorial_active and director.overlay.visible and director.current_lesson == "opening", "new game on a fresh profile did not start the opening lesson")
	_check(PhaseManager.dialogue_hold and not PhaseManager.clock_running(), "opening dialogue did not hold the departure clock")
	director._advance()
	director._advance()
	_check(String(director.current.get("wait_for", "")) == "gunner_placed", "third opening line is not the Gunner objective")
	director._advance()
	_check(director.overlay.waiting_for_action and director.overlay.highlight_target == main.menu.gunner_button, "Gunner objective did not highlight the Gunner shop row")
	_check(director.overlay.highlight_rect().size.x > 0.0, "highlighted control has no on-screen frame")
	_check(PhaseManager.dialogue_hold and PhaseManager.can_start_wave(), "objective must hold the clock without removing the player's START WAVE control")
	LevelManager.currency = 500
	var engine_screen: Vector2 = main.get_viewport().get_canvas_transform() * main.convoys[0].global_position
	main._on_train_drop_requested(0, engine_screen, 1)
	director._process(0.0)
	_check(not director.overlay.waiting_for_action and String(director.current.get("text", "")).begins_with("Good."), "coupling the Gunner did not complete the objective")
	# Starting the wave over an open STATION objective abandons that lesson
	# and keeps the rest for the next STATION.
	director._advance()
	director._advance()
	_check(String(director.current.get("wait_for", "")) == "wave_started", "opening did not reach the START WAVE objective")
	director._advance()
	_check(director.overlay.highlight_target == main.menu.station_progress_panel.skip_button, "START WAVE objective did not highlight the wave button")
	_check(PhaseManager.request_wave_start(), "player could not start the wave from the objective")
	_check(String(director.current.get("text", "")).begins_with("Spiders incoming"), "wave start did not play the combat follow-up")
	director._advance()
	director._advance()
	_check(director.current.is_empty() and not PhaseManager.dialogue_hold, "combat follow-up did not release the clock")
	# A bite during BATTLE is explained at the next STATION, not mid-wave.
	GameEvents.train_unit_bitten.emit(main.convoys[0])
	_check(director.current.is_empty() and director.deferred_lessons.has("biting"), "battle event lesson interrupted combat")
	main.spawner._end_wave()
	_check(director.current_lesson == "payout", "first STATION after the opening did not start the payout lesson")
	director._skip_all()
	_check(director.is_done("opening") and director.is_done("payout") and director.is_done("biting") and director.is_done("driving"), "skipping did not record the queued lessons for this profile")
	main.queue_free()
	await get_tree().process_frame

	# Same profile, continued: no opening. Another profile: opening again.
	main = await _start_campaign_scene(0, false)
	director = main.get_node("TutorialDirector")
	_check(not director.tutorial_active and not director.overlay.visible, "completed opening replayed on the same profile")
	main.queue_free()
	await get_tree().process_frame
	ProfileManager.select_profile(2)
	main = await _start_campaign_scene(0, false)
	director = main.get_node("TutorialDirector")
	_check(director.tutorial_active and director.overlay.visible, "switching to a fresh profile did not restart the opening tutorial")
	director._skip_all()
	main.queue_free()
	await get_tree().process_frame
	ProfileManager.select_profile(1)
	main = await _start_campaign_scene(0, false)
	director = main.get_node("TutorialDirector")
	_check(not director.tutorial_active, "profile one inherited profile two's fresh lesson state")
	main.queue_free()
	await get_tree().process_frame

	# Level seven unlocks two cars; a profile that has never met any car gets
	# a guided lesson for each, Mail Carrier included.
	ProfileManager.select_profile(3)
	main = await _start_campaign_scene(6, false)
	director = main.get_node("TutorialDirector")
	var lessons_queued: Dictionary = {}
	if not director.current_lesson.is_empty():
		lessons_queued[director.current_lesson] = true
	var mail_line_seen := false
	var mail_objective_seen := false
	for entry in director.queue:
		lessons_queued[String(entry.get("lesson", ""))] = true
		if String(entry.get("lesson", "")) == "car:7":
			mail_line_seen = mail_line_seen or String(entry.get("text", "")).contains("5×5")
			mail_objective_seen = mail_objective_seen or String(entry.get("wait_for", "")) == "car_placed:7"
	_check(lessons_queued.size() == 8 and lessons_queued.has("car:1") and lessons_queued.has("car:7"), "level seven did not queue a lesson for every unlocked car, got %s" % [lessons_queued.keys()])
	_check(mail_line_seen and mail_objective_seen, "Mail Carrier lesson lacks its 5×5 explanation or a guided placement")
	var level_seven: LevelData = CampaignManager.levels[6]
	_check(level_seven.new_tower_indices == [1, 7], "level seven does not record both newly unlocked cars")
	main.level_complete_overlay.show_for(level_seven, false)
	_check(main.level_complete_overlay._reward_label.text.contains("Chaingunner") and main.level_complete_overlay._reward_label.text.contains("Mail Carrier"), "level-complete card does not list every unlocked car: '%s'" % main.level_complete_overlay._reward_label.text)
	main.level_complete_overlay.visible = false
	director._skip_all()
	_check(director.is_done("car:7"), "skipping did not record the Mail Carrier lesson")
	TutorialDirector.reset_progress()
	director.reload_progress()
	_check(not director.is_done("car:7") and director.current_lesson == "car:0", "replaying lessons did not reintroduce the unlocked cars")
	director._skip_all()
	main.queue_free()
	await get_tree().process_frame
	ProfileManager.select_profile(1)
	PhaseManager.reset()
	CampaignManager.current_level_index = 0
	return true

## Crowded moments stay readable: identical sounds are capped at four
## voices with the extras ducked, and the SFX bus carries a limiter.
func _test_audio_normalization() -> bool:
	_check(AppSettings.sfx_limiter_installed(), "SFX bus has no limiter")
	var stream := preload("res://assets/audio/sfx/turret_shoot_minigun.wav")
	var dropped_before: int = AudioFX.dropped_voices
	for shot in range(7):
		AudioFX.play(stream, -12.0)
	_check(AudioFX.active_voices(stream) <= AudioFX.MAX_VOICES_PER_STREAM, "seven simultaneous Chaingunner rounds exceeded the voice cap")
	_check(AudioFX.dropped_voices - dropped_before == 3, "voice cap did not drop the surplus rounds, dropped %d" % (AudioFX.dropped_voices - dropped_before))
	var quietest := 0.0
	for player in get_tree().root.get_children():
		if player is AudioStreamPlayer and player.stream == stream:
			quietest = minf(quietest, player.volume_db)
	_check(quietest <= -12.0 + AudioFX.STACK_DUCK_DB * 3.0 + 0.01, "stacked copies of a sound were not ducked, quietest is %.1f dB" % quietest)
	# Release the players now; a round still sounding at quit would otherwise be
	# reported as a leaked playback by the exit check.
	for player in get_tree().root.get_children():
		if player is AudioStreamPlayer and player.stream == stream:
			player.stop()
			player.free()
	return true

func _test_mail_carrier() -> bool:
	var mail: Turret = preload("res://scenes/MailCarrier.tscn").instantiate()
	add_child(mail)
	mail.set_process(false)
	_check(mail.targeting_range == 225.0 and not mail.fixed_direction_enabled, "Mail Carrier must use swivelling 5×5 targeting")
	var spiders: Array[EnemyMovement] = []
	for position in [Vector2(100, 0), Vector2(-100, 0), Vector2(226, 0)]:
		var spider: EnemyMovement = EnemyScene.instantiate()
		add_child(spider)
		spider.set_process(false)
		spider.set_physics_process(false)
		spider.position = position
		spiders.append(spider)
	var recipients: Dictionary = {}
	for index in range(128):
		var recipient := mail._find_target()
		_check(recipient == spiders[0] or recipient == spiders[1], "Mail Carrier selected a spider outside its radius")
		recipients[recipient] = true
	_check(recipients.size() == 2, "Mail Carrier always selected the same spider")
	spiders[1].position = Vector2(-226, 0)
	mail._process(1.0 / mail.bps)
	var envelope: Bullet = null
	for child in get_children():
		if child.get_script() == preload("res://scripts/mail_envelope.gd"):
			envelope = child
	_check(envelope != null and envelope.target == spiders[0], "Mail Carrier failed to fire at its only eligible recipient")
	if envelope:
		var hp_before := spiders[0].health.hit_points
		envelope._physics_process(1.0)
		_check(spiders[0].health.hit_points == hp_before - mail.base_projectile_damage, "Envelope overshot its recipient or dealt incorrect damage")
		envelope.free()
	spiders[0].position = Vector2(226, 0)
	spiders[1].position = Vector2(-100, 0)
	mail.attack_speed_multiplier = 2.0
	mail._process(1.0 / (mail.bps * mail.attack_speed_multiplier))
	envelope = null
	for child in get_children():
		if child.get_script() == preload("res://scripts/mail_envelope.gd"):
			envelope = child
	_check(envelope != null and envelope.target == spiders[1], "Mail Carrier retained its old target or ignored a fire-rate upgrade")
	if envelope:
		envelope.free()
	spiders[1].health.is_destroyed = true
	_check(mail._find_target() == null, "Mail Carrier targeted a destroyed spider")
	spiders[1].health.is_destroyed = false
	spiders[1].queue_free()
	_check(mail._find_target() == null, "Mail Carrier targeted a despawning spider")
	mail._process(10.0)
	for child in get_children():
		_check(child.get_script() != preload("res://scripts/mail_envelope.gd"), "Mail Carrier fired with no eligible spiders")
	for spider in spiders:
		spider.queue_free()
	mail.queue_free()
	_check(CampaignManager.tower_unlock_level(7) == 7, "Mail Carrier is unreachable in the campaign shop")
	return true
