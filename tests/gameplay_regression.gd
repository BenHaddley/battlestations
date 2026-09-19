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
	ProfileManager.use_sandbox_root("/tmp/battlestations-regression-%d" % OS.get_process_id())
	_check(_test_convoy_spacing_and_reverse() == true, "_test_convoy_spacing_and_reverse aborted on a script error")
	_check(_test_convoy_never_self_blocks() == true, "_test_convoy_never_self_blocks aborted on a script error")
	_check(_test_campaign_track_library() == true, "_test_campaign_track_library aborted on a script error")
	_check(_test_content_catalogs() == true, "_test_content_catalogs aborted on a script error")
	_check((await _test_playtest_revision()) == true, "playtest revision checks aborted")
	_check(_test_mail_carrier() == true, "_test_mail_carrier aborted on a script error")
	_check(_test_wallet_wave_and_selection_rules() == true, "_test_wallet_wave_and_selection_rules aborted on a script error")
	_check(_test_challenge_job_cards() == true, "_test_challenge_job_cards aborted on a script error")
	_check((await _test_unit_sandbox()) == true, "_test_unit_sandbox aborted on a script error")
	_check(_test_music_playlist_rotation() == true, "_test_music_playlist_rotation aborted on a script error")
	_check(_test_game_over_modes() == true, "_test_game_over_modes aborted on a script error")
	_check((await _test_title_feature_modals()) == true, "_test_title_feature_modals aborted on a script error")
	_check((await _test_reported_combat_regressions()) == true, "_test_reported_combat_regressions aborted on a script error")
	_check((await _test_station_attackers()) == true, "_test_station_attackers aborted on a script error")
	_check((await _test_spider_assault()) == true, "_test_spider_assault aborted on a script error")
	_check((await _test_main_scene_train_integration()) == true, "_test_main_scene_train_integration aborted on a script error")
	_check((await _test_wave_button_and_phase_clock()) == true, "_test_wave_button_and_phase_clock aborted on a script error")
	_check((await _test_rail_building()) == true, "_test_rail_building aborted on a script error")
	_check((await _test_connect_existing_tracks()) == true, "existing track joins checks aborted")
	_check((await _test_train_obstacles()) == true, "_test_train_obstacles aborted on a script error")
	_check((await _test_range_preview_and_readout()) == true, "_test_range_preview_and_readout aborted on a script error")
	_check((await _test_lessons_and_profiles()) == true, "_test_lessons_and_profiles aborted on a script error")
	_check(_test_audio_normalization() == true, "_test_audio_normalization aborted on a script error")
	_check((await _test_almanac_discovery_and_profiles()) == true, "almanac/profile checks aborted")
	_check(_test_export_preset_covers_preloads() == true, "_test_export_preset_covers_preloads aborted on a script error")
	_check((await _test_train_yard_readability()) == true, "_test_train_yard_readability aborted on a script error")
	_check(_test_roster_baseline() == true, "roster baseline checks aborted")
	_check(_test_junction_and_jump_timing() == true, "junction/jump checks aborted")
	_check((await _test_cadence_and_offspring_economy()) == true, "cadence/economy checks aborted")
	_check((await _test_full_campaign_flow()) == true, "full campaign flow checks aborted")
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
	PhaseManager.phase = PhaseManager.Phase.BATTLE
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

## A train must keep moving on every authored campaign board. The consist
## clearance check compares straight-line distance between sampled vehicles,
## but two cars either side of a 90-degree corner are closer in a straight
## line than their spacing along the rail — so a consist could declare itself
## blocked, zero its speed and freeze for the rest of the level. The older
## spacing test only asserted that positions were valid, which a frozen train
## satisfies trivially, so it never caught this.
func _test_convoy_never_self_blocks() -> bool:
	var renderer := TrackRenderer.new()
	add_child(renderer)
	for layout_index in range(TrackRenderer.REFERENCE_LAYOUT_NAMES.size()):
		var routes := renderer.generate_campaign_layout(layout_index)
		for route_index in range(routes.size()):
			var convoy: TrainConvoy = ConvoyScene.instantiate()
			add_child(convoy)
			convoy.configure_path(routes[route_index])
			var attached := 0
			for car_index in range(3):
				var car := Node2D.new()
				car.set_script(preload("res://tests/train_test_car.gd"))
				add_child(car)
				if convoy.attach_car(car):
					attached += 1
				else:
					car.queue_free()
					break
			var blocked_steps := 0
			# A full lap, so every corner on the ring is driven through. Distance
			# is accumulated per step because route_distance wraps at the lap.
			var steps := int(convoy.route_length / 4.0) + 8
			var travelled := 0.0
			var previous := convoy.route_distance
			for step in range(steps):
				convoy._advance_safely(4.0)
				travelled += fposmod(convoy.route_distance - previous, convoy.route_length)
				previous = convoy.route_distance
				if convoy.movement_blocked:
					blocked_steps += 1
			_check(blocked_steps == 0, "layout %d route %d froze a %d-car train on %d of %d steps" % [layout_index, route_index, attached, blocked_steps, steps])
			_check(travelled > convoy.route_length, "layout %d route %d train travelled only %.0f of %.0f units" % [layout_index, route_index, travelled, convoy.route_length])
			convoy.queue_free()
	renderer.queue_free()
	return true

func _test_challenge_job_cards() -> bool:
	_check(CampaignManager.CHALLENGES.size() == 7, "challenge menu should expose seven launchable job cards")
	var seen_ids: Dictionary = {}
	for challenge in CampaignManager.CHALLENGES:
		var challenge_id := String(challenge.get("id", ""))
		_check(not challenge_id.is_empty() and not seen_ids.has(challenge_id), "challenge ids must be present and unique")
		seen_ids[challenge_id] = true
		_check(CampaignManager.start_challenge(challenge_id), "challenge %s did not start" % challenge_id)
		var level := CampaignManager.current_level()
		_check(level != null and level.level_name == String(challenge.name), "challenge %s did not supply its level data" % challenge_id)
		# The sandbox is deliberately endless; every scored job card ends.
		if challenge_id == "sandbox":
			_check(level.wave_count == 0, "the sandbox should run endlessly")
		else:
			_check(level.wave_count > 0, "challenge %s must have a finite wave target" % challenge_id)
	CampaignManager.clear_challenge()
	return true

## The unit lab has to hand over every car at no cost and lift the carry limit,
## and — just as importantly — must not leak either of those into normal play.
func _test_unit_sandbox() -> bool:
	_check(not CampaignManager.is_sandbox(), "sandbox reported active before it was started")
	_check(CampaignManager.start_challenge("sandbox"), "sandbox challenge did not start")
	_check(CampaignManager.is_sandbox(), "sandbox challenge did not report itself as a sandbox")
	var level := CampaignManager.current_level()
	_check(BuildManager.towers.size() == 22, "sandbox is missing the 14 draft-art cars")
	for index in range(BuildManager.towers.size()):
		_check(index in level.unlocked_tower_indices, "sandbox did not unlock tower %d" % index)
		var tower: TowerData = BuildManager.towers[index]
		_check(CampaignManager.cost_of(tower) == 0, "%s was not free in the sandbox" % tower.tower_name)
	_check(CampaignManager.challenge_shop_enabled(), "sandbox must leave the shop open")

	var train: TrainConvoy = ConvoyScene.instantiate()
	add_child(train)
	train.set_process(false)
	train.configure_path(PackedVector2Array([Vector2.ZERO, Vector2(3000, 0), Vector2(3000, 3000), Vector2(0, 3000)]))
	_check(is_inf(train.effective_capacity()), "sandbox did not lift the carry limit")
	# The whole current roster is only 1050 weight, so it already fits inside the
	# normal 1200 limit — coupling it once would prove nothing. Two of everything
	# is 2100 and could never be attached without the lift. The Brake Van caps
	# the consist by design and is left out rather than fought with.
	var cars: Array[Node2D] = []
	for _copy in range(2):
		for index in range(BuildManager.towers.size()):
			var car: Node2D = BuildManager.towers[index].scene.instantiate()
			add_child(car)
			if car.get("is_train_cap") == true:
				car.free()
				continue
			cars.append(car)
	var attached := 0
	for car in cars:
		if train.attach_car(car):
			attached += 1
	_check(attached == cars.size(), "sandbox could not couple a double roster: %d of %d" % [attached, cars.size()])
	_check(train.total_weight() > 1200.0, "double roster should outweigh the normal 1200 limit, else the lift is untested")
	train.free()

	var sandbox_main := MainScene.instantiate()
	add_child(sandbox_main)
	await get_tree().process_frame
	_check(sandbox_main.menu.sandbox_art_buttons.size() == 14, "sandbox shop is missing art prototype rows")
	var engine: TrainConvoy = sandbox_main.convoys[0]
	var engine_screen: Vector2 = get_viewport().get_canvas_transform() * engine.global_position
	sandbox_main._on_train_drop_requested(8, engine_screen)
	_check(engine.followers.size() == 1, "draft car could not be placed from sandbox shop")
	if not engine.followers.is_empty():
		_check(engine.followers[0].get_node("Base").texture.resource_path.ends_with("DIESEL ENGINE.png"), "placed draft car did not use generated texture")
	BuildManager.set_selected_tower(21)
	sandbox_main.queue_free()
	await get_tree().process_frame

	CampaignManager.clear_challenge()
	_check(not CampaignManager.is_sandbox(), "sandbox stayed active after being cleared")
	_check(BuildManager.towers.size() == 8, "draft-art cars leaked into the campaign roster")
	var paid: TowerData = BuildManager.towers[0]
	_check(CampaignManager.cost_of(paid) == paid.cost, "clearing the sandbox did not restore real prices")
	var normal: TrainConvoy = ConvoyScene.instantiate()
	add_child(normal)
	normal.set_process(false)
	_check(normal.effective_capacity() == 1200.0, "clearing the sandbox did not restore the carry limit")
	normal.free()
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
		for numeric_key in ["weight", "hp", "speed", "scale"]:
			_check(float(profile.get(numeric_key, 0)) > 0.0, "%s has invalid %s" % [profile_id, numeric_key])
		_check(int(profile.get("bounty", -1)) >= 0, "%s has negative bounty" % profile_id)
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
	_check(title.almanac.visible and title.almanac.tab_buttons.size() == 4, "illustrated Almanac did not open with four categories")
	title.almanac.close()
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
	# The reported symptom was simply "the train is not moving": assert the
	# real level's convoy actually travels, not just that a synthetic one can.
	var starter: TrainConvoy = main.convoys[0]
	var origin := starter.global_position
	var distance_before := starter.route_distance
	for frame in range(30):
		starter._process(1.0 / 60.0)
	_check(not starter.movement_blocked, "the level's starting train reported itself blocked")
	_check(starter.route_distance == distance_before and starter.global_position.is_equal_approx(origin), "station train moved without being selected and piloted")
	_check(main.menu.get_node("NewIllustratedUi").visible, "normal play lost its illustrated UI background")
	_check(main.get_node("Board").texture.resource_path == "res://assets/the_new_map.png", "normal play lost the shared new map background")
	# The live health gauge must sit inside the channel drawn in the UI artwork.
	# If it drifts wider or taller the meter reads as a slab of red laid over the
	# casing rather than a fill rising inside it.
	var hp_slot: Rect2 = Rect2(Menu.HP_CHANNEL_RECT.position / Menu.UI_TEXTURE_SCALE, Menu.HP_CHANNEL_RECT.size / Menu.UI_TEXTURE_SCALE)
	var gauge: HpGauge = main.menu.hp_fill
	_check(gauge.get_global_rect().is_equal_approx(hp_slot), "HP gauge does not cover the drawn health channel, it is at %s and the slot is %s" % [gauge.get_global_rect(), hp_slot])
	_check(hp_slot.size.x < hp_slot.size.y * 0.1, "HP gauge lost its narrow proportions, the slot is %s" % hp_slot)
	# Only the fill moves. Damage must never resize or reposition the gauge.
	gauge.set_fraction(0.25)
	gauge.displayed_fraction = 0.25
	_check(gauge.get_global_rect().is_equal_approx(hp_slot), "taking damage resized the HP gauge itself")
	gauge.set_fraction(1.0)
	gauge.displayed_fraction = 1.0
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
		LevelManager.currency = 120
		main.upgrade_panel.open_for(starter_car, main.convoys[0], starter_data)
		_check(LevelManager.currency == 120, "opening car information spent currency")
		_check(is_equal_approx(float(starter_car.get("bps")), fire_rate_before), "car information changed weapon stats")
		_check(not main.upgrade_panel.title_label.text.contains("UPGRADE"), "removed upgrade tree still advertised")
		main.upgrade_panel.close_panel()
		main._select_convoy(main.convoys[0])
		await get_tree().create_timer(0.2).timeout
		_check(main.train_control_panel._expansion > 0.9, "engine selection did not expand train controls")
		_check(main.train_control_panel.size.y <= 44.0, "selected-engine indicator obscures too much battlefield")
		var selected: TrainConvoy = main.convoys[0]
		PhaseManager.phase = PhaseManager.Phase.BATTLE
		var cruise_before := selected.current_speed
		selected.set_manual_axis(1, 0.2)
		selected._update_speed(0.5)
		_check(selected.current_speed > cruise_before, "Up override did not accelerate the selected engine")
		selected.current_speed = selected.cruise_speed
		selected.set_manual_axis(-1, 0.2)
		selected._update_speed(0.5)
		_check(selected.current_speed > 0.0 and selected.current_speed < selected.cruise_speed, "short Down override did not slow without parking")
		selected.set_manual_axis(-1, selected.REVERSE_HOLD_SECONDS)
		for step in range(5):
			selected._update_speed(0.5)
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
	_check(PhaseManager.is_station() and button.text == "START WAVE 1 !" and not button.disabled, "wave one start button is missing before the first wave, saw '%s'" % button.text)
	_check(PhaseManager.request_wave_start(), "START WAVE did not start wave one")
	_check(not PhaseManager.request_wave_start(), "a second press started a wave while one was underway")
	await get_tree().process_frame
	_check(main.spawner.current_wave == 1 and button.disabled and button.text == "WAVE 1 UNDERWAY", "wave button stayed enabled during BATTLE, saw '%s'" % button.text)
	main.spawner._end_wave()
	await get_tree().process_frame
	_check(PhaseManager.is_station() and button.text == "START WAVE 2 !" and not button.disabled, "wave button did not return before wave two, saw '%s'" % button.text)
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
	# Construction markers stay off the board until the player arms BUILD TRACK.
	_check(PhaseManager.is_station() and not builder.active(), "rail builder was live before BUILD TRACK was armed")
	main.menu.set_build_track(true)
	_check(main.menu.building_track and builder.active(), "arming BUILD TRACK did not enable construction")

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
	_check(join_verdict.ok, "a bridge between separate circuits was refused")
	_check(track.link_candidates(Vector2i(1, 6)).has([Vector2i(1, 6), Vector2i(1, 7)]), "bridge join marker is missing")
	_check(builder.attempt_remove(Vector2i(1, 6)) and LevelManager.currency == before_currency and track.graph.size() == before_cells, "probe spur could not be lifted for a refund")
	LevelManager.currency = cost - 1
	_check(not builder.attempt_build(Vector2i(2, 0), Vector2i(1, 0)), "unaffordable rail was laid")
	_check(LevelManager.currency == cost - 1 and track.graph.size() == before_cells, "refused placement changed the wallet or railway")
	LevelManager.currency = before_currency
	_check(not PhaseManager.request_wave_start(), "wave started while building rails")
	main.menu.set_build_track(false)
	_check(PhaseManager.request_wave_start(), "could not start a wave for the BATTLE gating check")
	main.menu._on_phase_changed("battle")
	_check(not builder.active(), "rail builder stayed active during BATTLE")
	_check(not builder.attempt_build(Vector2i(2, 0), Vector2i(1, 0)), "rail was laid during BATTLE")
	_check(track.graph.size() == before_cells and LevelManager.currency == before_currency, "BATTLE placement attempt changed state")
	_check(not main.menu.building_track, "BUILD TRACK stayed armed into BATTLE")
	main.spawner._end_wave()
	main.menu.set_build_track(true)
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

	# A locomotive can be purchased directly on an open spur.
	_check(builder.attempt_build(Vector2i(2, 2), Vector2i(2, 1)), "engine spur could not be built")
	main.menu.set_build_track(false)
	var convoys_before: int = main.convoys.size()
	LevelManager.currency = Menu.ENGINE_COST
	main._on_engine_drop_requested(main.get_viewport().get_canvas_transform() * track.world_of(Vector2i(2, 1)))
	_check(main.convoys.size() == convoys_before + 1 and LevelManager.currency == 0, "dead-end rail rejected a locomotive")
	_check(main.convoys[-1].navigator != null, "new locomotive is not driving the live railway")
	main.menu.set_build_track(true)
	main._process(0.01)
	for train in main.convoys:
		_check(not train.visible and train.current_speed == 0.0, "building mode did not hide and park an engine")
		for car in train.followers:
			_check(not car.visible, "building mode left a car visible")
			_check(main.rail_cell_occupied(track.cell_of(car.global_position)), "hidden car lost its rail occupancy")
	main.menu.set_build_track(false)
	main._process(0.01)
	_check(main.convoys[0].visible and main.convoys[0].followers[0].visible, "trains did not return after building")
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
	_check(not spider.is_biting() and is_equal_approx(absf(spider.route_target.x), 65.5), "spider did not sidestep round a lone train unit, lane x is %f at %s, row %f" % [spider.route_target.x, spider.global_position, spider._sidestep_row])
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
	# Selecting an engine lifts the ring it drives and fades everything else,
	# so the player can see which track belongs to this train.
	var own_cell: Vector2i = main.track.cell_of(convoy.path[0])
	var other_cell: Vector2i = main.track.route_cells(0)[0] if convoy.route_index != 0 else main.track.route_cells(1)[0]
	main._select_convoy(convoy)
	var own_tint: Color = main.track.tiles_at(own_cell)[0].modulate
	var other_tint: Color = main.track.tiles_at(other_cell)[0].modulate
	_check(other_tint.a < 0.95 and other_tint.r < 0.95, "unrelated track did not fade when a train was selected, saw %s" % other_tint)
	_check(own_tint.b > other_tint.b and own_tint.a > other_tint.a, "the selected train's own route was not lifted above the rest")
	main._clear_train_selection()
	_check(main.track.tiles_at(other_cell)[0].modulate.is_equal_approx(Color.WHITE), "track stayed faded after deselecting")
	main._select_convoy(convoy)
	var status: String = main.train_control_panel.status_line()
	_check(status.contains("WEIGHT 150 / 1200") and status.contains("ENGINE HP 300 / 300"), "controlled-train readout is wrong: '%s'" % status)
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
	_check(director.tutorial_active and director.current_lesson == "opening", "switching back to a different profile did not replay its tutorial")
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
	# Multiple introductions are queued from one wallet snapshot. Spending
	# before a later objective must turn it into advice, not a stuck task.
	LevelManager.currency = 0
	for step in range(64):
		if director.current.is_empty():
			break
		director._advance()
	_check(director.current.is_empty() and not director.overlay.waiting_for_action, "queued car introduction required an unaffordable purchase")
	LevelManager.currency = 600

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

## The Web preset exports the selected scenes, their (transitive) scene and
## resource dependencies, and an include_filter allowlist — never a script's
## own preload() targets. A script that preloads a file outside that set
## compiles in the editor but fails to load in the exported build, taking
## every dependent script with it (this is how the starting railway and train
## vanished from the first Pages build). Every preload must be covered.
func _test_export_preset_covers_preloads() -> bool:
	var preset := ConfigFile.new()
	_check(preset.load("res://export_presets.cfg") == OK, "export_presets.cfg could not be read")
	var include_patterns: PackedStringArray = String(preset.get_value("preset.0", "include_filter", "")).split(",", false)
	var export_files: PackedStringArray = preset.get_value("preset.0", "export_files", PackedStringArray())
	_check(export_files.has("res://scenes/Main.tscn") and export_files.has("res://scenes/TitleScreen.tscn"), "Web preset no longer exports the title and main scenes")
	var covered: Dictionary = {}
	var pending: Array[String] = []
	for path in export_files:
		pending.append(String(path))
	var ext_resource := RegEx.create_from_string('path="(res://[^"]+)"')
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if covered.has(path):
			continue
		covered[path] = true
		if path.ends_with(".tscn") or path.ends_with(".tres"):
			var text := FileAccess.get_file_as_string(path)
			for found in ext_resource.search_all(text):
				pending.append(found.get_string(1))
	var preload_call := RegEx.create_from_string('preload\\("(res://[^"]+)"\\)')
	var uncovered: Array[String] = []
	var preloads_seen := 0
	var scripts := DirAccess.get_files_at("res://scripts")
	for script_name in scripts:
		if not script_name.ends_with(".gd"):
			continue
		var script_path := "res://scripts/" + script_name
		var source := FileAccess.get_file_as_string(script_path)
		for found in preload_call.search_all(source):
			preloads_seen += 1
			var target := found.get_string(1)
			if covered.has(target) or _matches_include_filter(target.trim_prefix("res://"), include_patterns):
				continue
			var entry := "%s (from %s)" % [target, script_name]
			if not uncovered.has(entry):
				uncovered.append(entry)
	_check(preloads_seen > 100, "preload scan found only %d preloads; the pattern is no longer matching the scripts" % preloads_seen)
	_check(covered.has("res://assets/sprites/board/Rail End.png") and covered.has("res://assets/the_new_map.png"), "scene dependency scan did not follow Main.tscn's textures")
	_check(_matches_include_filter("assets/sprites/ui/portrait/duck_talking.png", include_patterns) and _matches_include_filter("assets/sprites/effects/BREAK 1.png", include_patterns), "include filter matching is broken")
	_check(uncovered.is_empty(), "script preload targets are not exported to the Web build: %s" % [uncovered])
	return true

func _matches_include_filter(relative_path: String, patterns: PackedStringArray) -> bool:
	for pattern in patterns:
		var trimmed := String(pattern).strip_edges()
		if trimmed.is_empty():
			continue
		if relative_path.match(trimmed):
			return true
	return false

## Unit copy belongs in the Train Yard. Godot's native tooltip rendered these
## multi-paragraph blurbs as a banner across the board, the train yard and the
## right-hand UI, so no shop control may carry tooltip_text any more.
func _test_train_yard_readability() -> bool:
	var main = await _start_campaign_scene(0, false)
	var menu: Menu = main.menu
	(main.get_node("TutorialDirector") as TutorialDirector)._skip_all()
	var engine_row: Button = menu.get_node("LeftPanel/Margin/VBox/ScrollContainer/ShopList/EngineRow")
	for button_name in Menu.TOWER_BUTTONS:
		var button: Button = menu.get(button_name)
		_check(button.tooltip_text.is_empty(), "%s still carries a native tooltip" % button_name)
	_check(engine_row.tooltip_text.is_empty(), "the locomotive row still carries a native tooltip")
	_check(menu.shop_detail_panel != null and menu.shop_detail_panel.get_parent() == menu.get_node("LeftPanel/Margin/VBox"), "unit descriptions are not inside the Train Yard panel")
	_check(menu.shop_detail_panel.get_index() < menu.remove_button.get_index(), "the description card should sit above REMOVE UNIT")

	# Hovering a row fills the card with that unit's name, stats and blurb.
	# The Train Yard is a column of non-overlapping regions. A card that grew
	# with its text stole height from the unit list until shop rows sat under
	# it and could not be clicked.
	var scroll_rect: Rect2 = menu.get_node("LeftPanel/Margin/VBox/ScrollContainer").get_global_rect()
	var panel_rect: Rect2 = menu.shop_detail_panel.get_global_rect()
	_check(not scroll_rect.intersects(panel_rect), "the unit list and the info card overlap: %s vs %s" % [scroll_rect, panel_rect])
	_check(menu.shop_detail_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the info card intercepts mouse input")
	_check(panel_rect.size.y <= Menu.DETAIL_PANEL_HEIGHT + 8.0, "the info card grew past its reserved band: %.0f" % panel_rect.size.y)
	_check(scroll_rect.size.y > panel_rect.size.y * 2.0, "the info card is crowding out the unit list (%.0f list vs %.0f card)" % [scroll_rect.size.y, panel_rect.size.y])
	for button_name in Menu.TOWER_BUTTONS:
		var row: Button = menu.get(button_name)
		var row_rect: Rect2 = row.get_global_rect()
		# Rows scrolled out of view keep rects below the fold, but the scroll
		# viewport clips them; only rows actually on screen matter here.
		if scroll_rect.encloses(row_rect):
			_check(not row_rect.intersects(panel_rect), "%s is drawn under the info card" % button_name)
	# The longest blurb in the game must not change the reserved height.
	menu._show_shop_detail(5)
	_check(menu.shop_detail_panel.get_global_rect().size.y <= Menu.DETAIL_PANEL_HEIGHT + 8.0, "a long description resized the info card")

	# The shop shows the one-line summary; the authored paragraphs are Almanac
	# material and must not reappear in this small card.
	_check(not menu.shop_detail_body.text.contains("hearty defense"), "the long authored blurb is back in the shop card")
	_check(UnitLore.for_tower(BuildManager.towers[3]).contains("hearty defense"), "the Passenger Coach lore did not move to the Almanac source")
	for tower in BuildManager.towers:
		_check(UnitLore.for_tower(tower).length() > tower.summary.length(), "%s has no Almanac entry beyond its one-line summary" % tower.tower_name)
	menu._show_shop_detail(0)
	_check(menu.shop_detail_stats.text.contains("Δ150") and menu.shop_detail_stats.text.contains("150 WEIGHT") and menu.shop_detail_stats.text.contains("200 HP"), "detail card stats are wrong: '%s'" % menu.shop_detail_stats.text)
	# Ranges are quoted in the cards' grid notation, matching the lessons.
	_check(menu.shop_detail_stats.text.contains("7×7 RANGE"), "the Gunner should advertise its 7×7 card range, saw '%s'" % menu.shop_detail_stats.text)
	menu._show_shop_detail(7)
	_check(menu.shop_detail_stats.text.contains("5×5 RANGE"), "the Mail Carrier should advertise its 5×5 card range, saw '%s'" % menu.shop_detail_stats.text)
	menu._show_shop_detail(2)
	_check(menu.shop_detail_stats.text.contains("3×3 RANGE"), "the Ballast Blaster should advertise its 3×3 card range, saw '%s'" % menu.shop_detail_stats.text)
	menu._show_shop_detail(0)
	_check(menu.shop_detail_body.text.contains("Fires pellets"), "detail card lost the Gunner summary, saw '%s'" % menu.shop_detail_body.text)
	menu._show_shop_detail(-1)
	_check(menu.shop_detail_name.text == "LOCOMOTIVE" and menu.shop_detail_stats.text.contains("Δ%d" % Menu.ENGINE_COST), "the locomotive row has no description")

	# BUILD TRACK is a mode, and it steps the panels back while it is on.
	_check(menu.build_track_button != null and not menu.building_track, "BUILD TRACK button is missing or armed at level start")
	var shop_scroll: Control = menu.get_node("LeftPanel/Margin/VBox/ScrollContainer")
	_check(shop_scroll.modulate.is_equal_approx(Color.WHITE), "the Train Yard starts dimmed")
	menu.set_build_track(true)
	_check(menu.building_track and menu.build_track_button.text == "DONE BUILDING", "BUILD TRACK did not arm")
	_check(shop_scroll.modulate.r < 0.9 and menu.get_node("RightPanel/Margin/VBox/PortraitPanel").modulate.r < 0.9, "building track did not step the panels back")
	_check(menu.shop_detail_name.text == "BUILDING TRACK", "the detail card does not explain track building while it is armed")
	menu.set_build_track(false)
	_check(shop_scroll.modulate.is_equal_approx(Color.WHITE), "the Train Yard stayed dimmed after building ended")

	# A car the campaign has not granted yet is absent from the yard, not shown
	# as a dimmed STOP n row taking space from the cars that can be bought.
	menu._process(0.0)
	var shown := 0
	for index in range(Menu.TOWER_BUTTONS.size()):
		var row: Button = menu.get(Menu.TOWER_BUTTONS[index])
		var unlocked := CampaignManager.is_tower_unlocked(index)
		_check(row.visible == unlocked, "%s visible=%s but unlocked=%s" % [Menu.TOWER_BUTTONS[index], row.visible, unlocked])
		if row.visible:
			shown += 1
	_check(shown == 1, "the first campaign stop should offer exactly its one unlocked car, saw %d" % shown)
	# Every card on screen is one the player can actually act on.
	for button_name in Menu.TOWER_BUTTONS:
		var row: Button = menu.get(button_name)
		if row.visible:
			_check(not row.disabled, "%s is shown but not usable" % button_name)
	_check(menu._phase_heading(false).begins_with("STATION —") and menu._phase_instruction(false) == "BUILD & PREPARE YOUR TRAIN", "the STATION panel does not say what to do, saw '%s'" % menu._phase_heading(false))
	_check(menu.station_progress_panel.skip_button.custom_minimum_size.y >= 40.0, "START WAVE is too small to read as the primary action")
	main.queue_free()
	await get_tree().process_frame
	PhaseManager.reset()
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

func _test_almanac_discovery_and_profiles() -> bool:
	ProfileManager.select_profile(1)
	DiscoveryTracker.discovered_ids.clear()
	DiscoveryTracker.save_discoveries()
	var title = TitleScene.instantiate()
	add_child(title)
	await get_tree().process_frame
	title._show_almanac()
	var book: AlmanacPanel = title.almanac
	_check(book.counter.text == "0 / 9 DISCOVERED", "empty profile has revealed enemies")
	_check(DiscoveryTracker.discovered_ids.is_empty(), "opening the almanac discovered unseen content")
	for card in book.card_buttons:
		_check(card.disabled and not card.get_meta("revealed"), "unseen card exposes interaction or identity")
		var labels := card.find_children("*", "Label", true, false)
		_check(labels[0].text == "???" and labels[1].text == "NOT YET DISCOVERED", "unseen card leaks its name or description")
		var preview = card.get_child(0).get_child(0)
		_check(preview.layers.is_empty(), "unseen card loaded the hidden unit artwork")
	DiscoveryTracker.discover("enemy:generic")
	DiscoveryTracker.discover("enemy:generic")
	DiscoveryTracker.discover("tower:gunner_car")
	book.open()
	_check(book.counter.text == "1 / 9 DISCOVERED", "duplicate sightings inflated the discovery count")
	_check(not book.card_buttons[0].disabled, "seen enemy stayed locked")
	var enemy_preview = book.card_buttons[0].get_child(0).get_child(0)
	_check(enemy_preview.layers[0].texture == EnemyMovement.DOT_STAGE_TEXTURES[0][0], "almanac spider differs from gameplay art")
	book._show_detail(book.entries[0])
	_check(book.detail.visible, "discovered unit details did not open")
	book._close_detail()
	book._show_detail(book.entries[1])
	_check(not book.detail.visible, "unseen unit details were exposed")
	book.select_category(2)
	_check(book.counter.text == "1 / 5 DISCOVERED", "defense tab count does not match encountered weapons")
	var gun_preview = book.card_buttons[0].get_child(0).get_child(0)
	_check(gun_preview.layers.size() == 2 and gun_preview.layers[0].texture == CarArt.for_tower(BuildManager.towers[0]).base and gun_preview.layers[1].texture == CarArt.for_tower(BuildManager.towers[0]).top, "almanac turret omitted or replaced placed-car layers")
	book.select_category(1)
	_check(book.card_buttons.size() == 4, "train tab must contain engine and utility cars")
	book.select_category(3)
	_check(book.card_buttons.size() == 3, "track tab is missing a current rail piece")
	book.close()
	var completed := ConfigFile.new()
	completed.set_value("tutorial", "completed", true)
	completed.set_value("lessons", "opening", true)
	completed.save(ProfileManager.profile_path("tutorial.cfg", 1))
	completed.save(ProfileManager.profile_path("tutorial.cfg", 2))
	var campaign := ConfigFile.new()
	campaign.set_value("campaign", "current_level_index", 3)
	campaign.save(ProfileManager.profile_path("campaign_progress.cfg", 2))
	ProfileManager.delete_profile(3)
	title._select_profile(2)
	_check(not FileAccess.file_exists(ProfileManager.profile_path("tutorial.cfg", 2)), "profile switching did not reset selected profile lessons")
	_check(FileAccess.file_exists(ProfileManager.profile_path("tutorial.cfg", 1)), "switching erased the outgoing profile's tutorial")
	_check(CampaignManager.current_level_index == 3, "restarting profile guidance reset its campaign")
	DiscoveryTracker.discovered_ids.clear()
	DiscoveryTracker.save_discoveries()
	title._show_almanac()
	_check(book.counter.text == "0 / 9 DISCOVERED", "profile two inherited profile one's discoveries")
	book.close()
	completed.save(ProfileManager.profile_path("tutorial.cfg", 2))
	title._select_profile(2)
	_check(FileAccess.file_exists(ProfileManager.profile_path("tutorial.cfg", 2)), "reselecting the same profile reset its tutorial")
	title._select_profile(1)
	title._show_almanac()
	_check(book.counter.text == "1 / 9 DISCOVERED", "profile one's saved discoveries were lost on switching back")
	book.close()
	title.queue_free()
	await get_tree().process_frame
	var main = await _start_campaign_scene(0, false)
	_check(DiscoveryTracker.is_discovered("engine:steam") and DiscoveryTracker.is_discovered("track:straight") and DiscoveryTracker.is_discovered("track:curve"), "entering a run did not discover its engine and visible tracks")
	main.queue_free()
	await get_tree().process_frame
	return true

func _test_playtest_revision() -> bool:
	var previous_level := CampaignManager.current_level_index
	var renderer := TrackRenderer.new()
	add_child(renderer)
	renderer.columns.assign([0.0, 65.5, 131.0, 196.5, 262.0, 327.5, 393.0, 458.5, 524.0])
	renderer.rows.assign([0.0, 65.5, 131.0])
	renderer.track_bounds = Rect2(0, 0, 524, 131)
	renderer.graph.clear()
	for x in range(9):
		var neighbors: Array = []
		if x > 0:
			neighbors.append(Vector2i(x - 1, 0))
		if x < 8:
			neighbors.append(Vector2i(x + 1, 0))
		renderer.graph[Vector2i(x, 0)] = neighbors
	var train: TrainConvoy = ConvoyScene.instantiate()
	add_child(train)
	train.set_process(false)
	train.configure_path(PackedVector2Array([Vector2(131, 0), Vector2(196.5, 0)]))
	train.navigator = RailNavigator.new()
	train.navigator.setup_edge(renderer, Vector2(131, 0), Vector2(196.5, 0), Vector2(196.5, 0))
	train.route_distance = train.navigator.distance
	for i in range(2):
		var car := Node2D.new()
		car.set_script(preload("res://tests/train_test_car.gd"))
		add_child(car)
		_check(train.attach_car(car), "open railway rejected a car with enough rail behind it")
	PhaseManager.phase = PhaseManager.Phase.BATTLE
	var reversals := 0
	var last_direction := train.cruise_direction
	for step in range(1800):
		train._process(1.0 / 60.0)
		if train.cruise_direction != last_direction:
			reversals += 1
			_check(train.current_speed == 0.0 and train.buffer_pause > 0.6, "buffer reversal skipped its stop and pause")
			var stopped_position := train.global_position
			train._process(0.3)
			_check(train.global_position == stopped_position and is_equal_approx(train.buffer_pause, 0.35), "train moved during buffer dwell")
			train._process(0.35)
			_check(train.global_position == stopped_position and is_zero_approx(train.buffer_pause), "buffer dwell did not last 0.65 seconds")
			last_direction = train.cruise_direction
		_check(train._positions_valid_at(train.route_distance, 2), "backing train overlapped its cars")
		_check(train.followers[-1].global_position.x >= -0.01 and train.global_position.x <= 524.01, "a train member left the dead-end rails")
	_check(reversals >= 2, "train did not reverse at both ends of an open railway")
	# Add an open side branch to an already moving network. The engine must
	# enter it, pause at its buffer, and back out with all cars still on rail.
	renderer.graph[Vector2i(4, 0)].append(Vector2i(4, 1))
	renderer.graph[Vector2i(4, 1)] = [Vector2i(4, 0)]
	renderer.built_cells[Vector2i(4, 1)] = true
	renderer.revision += 1
	var entered_spur := false
	var spur_buffer := false
	for frame in range(3000):
		train._process(1.0 / 60.0)
		entered_spur = entered_spur or train.global_position.y > 1.0
		spur_buffer = spur_buffer or (train.global_position.y > 65.4 and train.buffer_pause > 0)
		_check(not train.movement_blocked, "train self-blocked at the new spur junction")
	_check(entered_spur and spur_buffer, "live train did not enter a newly built dead-end branch")
	PhaseManager.phase = PhaseManager.Phase.STATION
	train._process(0.2)
	_check(train.current_speed == 0.0, "station train did not park")
	train.set_selected(true)
	train.set_manual_axis(train.cruise_direction)
	train.buffer_pause = 0.0
	train._process(0.2)
	_check(absf(train.current_speed) > 0, "selected station train cannot be piloted")
	train.release_driver_controls()
	train._process(0.2)
	_check(train.current_speed == 0, "station train coasted after releasing controls")
	var spider: EnemyMovement = EnemyScene.instantiate()
	add_child(spider)
	spider.set_physics_process(false)
	spider.biting_target = train
	train._process(0.2)
	_check(train.current_speed == 0, "biting spider did not pin the entire train")
	spider._stop_biting()
	spider.configure_archetype(EnemyRoster.by_id("charger"), 1, 1)
	var hp := train.unit_health.hit_points
	spider._charge_hit(train)
	spider._charge_hit(train)
	_check(train.unit_health.hit_points == hp - 250.0 and train.current_speed == 0, "charger did not deal exactly one 250-damage stopping impact")
	spider.configure_archetype(EnemyRoster.by_id("jump"), 1, 5)
	spider.global_position = Vector2(0, -131)
	spider.configure_lane(500)
	spider._special_clock = 4.0
	for frame in range(45):
		spider._physics_process(1.0 / 60.0)
	_check(absf(spider.global_position.y) < 0.01 and not spider.is_biting(), "jump did not clear exactly two tiles over the train")
	spider.configure_archetype(EnemyRoster.by_id("generic"), 1, 0)
	spider.global_position = Vector2(0, -200)
	spider.configure_route(Vector2(131, 300))
	spider._physics_process(0.1)
	_check(spider.velocity.x == 0 or spider.velocity.y == 0, "spider moved diagonally")
	spider.queue_free()
	for car in train.followers:
		car.queue_free()
	train.queue_free()
	renderer.queue_free()
	await get_tree().process_frame
	var spawner := EnemySpawner.new()
	spawner.enemy_prefabs = [EnemyScene]
	add_child(spawner)
	CampaignManager.current_level_index = 2
	spawner.current_wave = 3
	spawner._spawn_enemy()
	var first: EnemyMovement = get_tree().get_nodes_in_group("spiders")[-1]
	_check(first.archetype_id == "rally" and first.health.hit_points == spawner._hit_points_for_wave() + 2 and first.speed_multiplier > 1.0, "wave did not open with its tougher, faster Rally leader")
	_check(first.ability == "leader", "Rally retained a support ability")
	first.queue_free()
	await get_tree().process_frame
	var roller := spawner.spawn_extra("roller", Vector2.ZERO, 380)
	spawner._add_roller_egg(roller)
	var egg := roller.pushed_egg
	_check(is_instance_valid(egg) and egg.global_position == Vector2(0, 65.5), "roller is not pushing an egg one tile ahead")
	var gun: Turret = BasicTurretScene.instantiate()
	add_child(gun)
	gun.set_process(false)
	gun.global_position = Vector2(0, -100)
	_check(gun._find_target() == egg, "gun preferred the closer roller over its egg")
	var count_before := spawner.enemies_alive
	egg.take_damage(1000)
	_check(spawner.enemies_alive == count_before + 3, "destroyed egg did not replace itself with four counted babies")
	_check(roller.health.hit_points > 0 and not roller.protected_by_egg(gun.global_position, gun.targeting_range), "broken egg kept protecting its roller")
	for enemy in get_tree().get_nodes_in_group("spiders"):
		enemy.queue_free()
	gun.queue_free()
	spawner.queue_free()
	await get_tree().process_frame
	CampaignManager.current_level_index = previous_level
	PhaseManager.reset()
	return true

## Real scene reloads and persisted profiles, with scripted kills to make this a
## deterministic flow test. This is not a human usability or combat-balance test.
func _test_full_campaign_flow() -> bool:
	# Earlier embedded-scene tests spawn under this harness; isolate the real
	# campaign from any remaining synthetic enemies before switching scenes.
	for enemy in get_tree().get_nodes_in_group("spiders"):
		enemy.free()
	ProfileManager.use_sandbox_root("/tmp/battlestations-campaign-%d" % OS.get_process_id())
	CampaignManager.restart_campaign()
	var harness := get_tree().current_scene
	var main = MainScene.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame
	seed(16092026)
	var introduced: Dictionary = {}
	for stop in range(CampaignManager.levels.size()):
		_check(CampaignManager.current_level_index == stop, "campaign transition skipped stop %d" % stop)
		var director: TutorialDirector = main.get_node("TutorialDirector")
		var expected: Array = [0] if stop == 0 else CampaignManager.levels[stop].new_tower_indices
		var scheduled: Dictionary = {}
		for entry in [director.current] + director.queue:
			scheduled[String(entry.get("lesson", ""))] = true
		for index in expected:
			var id := "opening" if stop == 0 else "car:%d" % index
			_check(scheduled.has(id), "stop %d omitted introduction %s" % [stop + 1, id])
			introduced[index] = true
		_check(PhaseManager.dialogue_hold, "new car introduction did not hold departure at stop %d" % stop)
		director._skip_all()
		# Save/continue reloads the stop, not a half-finished wave. Skipped
		# introductions must remain skipped on the same profile.
		CampaignManager.save_progress()
		CampaignManager.continue_saved_game()
		get_tree().reload_current_scene()
		await get_tree().process_frame
		await get_tree().process_frame
		main = get_tree().current_scene
		director = main.get_node("TutorialDirector")
		_check(CampaignManager.current_level_index == stop and main.spawner.current_wave == 0, "continue failed to restore stop %d" % stop)
		_check(director.current.is_empty(), "continued stop repeated a skipped introduction")
		_check(LevelManager.currency == CampaignManager.levels[stop].starting_currency, "continue inherited another stop's wallet")
		for wave in range(1, CampaignManager.levels[stop].wave_count + 1):
			_check(PhaseManager.request_wave_start(), "wave button failed at stop %d wave %d" % [stop + 1, wave])
			_check(not PhaseManager.request_wave_start(), "double wave-start advanced twice")
			director._skip_all()
			var spawner: EnemySpawner = main.spawner
			# Spawn every scheduled enemy and kill its complete egg family.
			for tick in range(100):
				if not spawner.is_spawning:
					break
				spawner._process(1.0 / spawner.eps + 0.01)
				for generation in range(2):
					for enemy in get_tree().get_nodes_in_group("spiders"):
						if not enemy.health.is_destroyed:
							enemy.take_damage(100000)
			_check(not spawner.is_spawning and spawner.enemies_remaining() == 0, "wave failed to clear after all enemies/offspring died: alive=%d left=%d" % [spawner.enemies_alive, spawner.enemies_left_to_spawn])
			director._skip_all()
			_check(spawner.current_wave == wave, "wave counter changed during post-wave lessons")
		_check(main.level_complete_overlay.visible and PhaseManager.paused, "stop completion did not show and pause")
		var wallet := LevelManager.currency
		main.spawner.start_next_wave()
		PhaseManager._process(1000)
		_check(LevelManager.currency == wallet and not main.spawner.is_spawning, "completed stop restarted or paid twice")
		print("CAMPAIGN FLOW PASS: %s (%d waves)" % [CampaignManager.levels[stop].level_name, main.spawner.current_wave])
		main.level_complete_overlay.continue_pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		main = get_tree().current_scene
	_check(introduced.size() == BuildManager.towers.size(), "campaign did not introduce the entire purchasable roster")
	_check(CampaignManager.campaign_complete and main.spawner.wave_target == 0, "finale failed to enter endless play")
	main.queue_free()
	get_tree().current_scene = harness
	await get_tree().process_frame
	# Switching profiles preserves both campaigns, while deliberately replaying
	# lessons on the selected profile. Same-profile selection preserves lessons.
	ProfileManager.select_profile(2)
	CampaignManager.continue_saved_game()
	_check(CampaignManager.current_level_index == 0 and not CampaignManager.campaign_complete, "fresh profile inherited campaign completion")
	CampaignManager.restart_campaign()
	ProfileManager.select_profile(1)
	CampaignManager.continue_saved_game()
	_check(CampaignManager.campaign_complete, "profile switch lost completed campaign")
	main = await _start_campaign_scene(6, false)
	var replay: TutorialDirector = main.get_node("TutorialDirector")
	_check(replay.current_lesson == "car:0", "profile switch did not reintroduce saved unlocked roster")
	replay._skip_all()
	ProfileManager.select_profile(1)
	replay.load_progress()
	_check(replay.is_done("car:7"), "same-profile selection forgot skipped lessons")
	main.queue_free()
	await get_tree().process_frame
	CampaignManager.restart_campaign()
	main = await _start_campaign_scene(0, true)
	replay = main.get_node("TutorialDirector")
	_check(replay.current_lesson == "opening" and not replay.is_done("car:7"), "new campaign retained old lesson progress")
	main.queue_free()
	await get_tree().process_frame
	PhaseManager.reset()
	return true

func _test_cadence_and_offspring_economy() -> bool:
	var old_level := CampaignManager.current_level_index
	CampaignManager.clear_challenge()
	# Sixty seconds should produce exactly 157 envelopes at 2.625/sec,
	# regardless of frame rate. Idle time must never accumulate a free volley.
	for fps in [30, 60, 144]:
		var mail: Turret = preload("res://scenes/MailCarrier.tscn").instantiate()
		add_child(mail)
		mail.set_process(false)
		mail._process(60.0)
		var target_spider: EnemyMovement = EnemyScene.instantiate()
		add_child(target_spider)
		target_spider.set_physics_process(false)
		target_spider.position = Vector2(100, 0)
		var shots := 0
		for frame in range(fps * 60):
			mail._process(1.0 / fps)
			for child in get_children():
				if child.get_script() == preload("res://scripts/mail_envelope.gd"):
					shots += 1
					child.free()
		_check(shots == 157, "Mail Carrier emitted %d shots at %d FPS, expected 157" % [shots, fps])
		mail.free()
		target_spider.free()
		# Let cosmetic one-shots finish before the next batch.
		await get_tree().create_timer(0.4).timeout
	var spawner := EnemySpawner.new()
	spawner.enemy_prefabs = [EnemyScene]
	add_child(spawner)
	spawner.set_process(false)
	for challenge in ["", "budget", "spider_assault"]:
		CampaignManager.active_challenge_id = challenge
		CampaignManager.current_level_index = 6
		spawner.current_wave = 8
		var player_deployed: bool = challenge == "spider_assault"
		var starting_cash := LevelManager.currency
		var roller := spawner.spawn_extra("roller", Vector2.ZERO, 380, player_deployed)
		spawner._add_roller_egg(roller)
		var egg := roller.pushed_egg
		_check(egg.health.currency_worth == 0, "egg shell pays a duplicate bounty")
		egg.take_damage(10000)
		egg.take_damage(10000)
		var babies := 0
		for enemy in get_tree().get_nodes_in_group("spiders"):
			if enemy.archetype_id == "baby" and not enemy.health.is_destroyed:
				babies += 1
				enemy.take_damage(10000)
		roller.take_damage(10000)
		_check(babies == 4 and spawner.enemies_alive == 0, "egg family spawned twice or left incorrect live count")
		var expected := 0 if player_deployed else (15 if challenge == "budget" else 33)
		_check(LevelManager.currency - starting_cash == expected, "egg family reward mismatch in %s: %d" % [challenge, LevelManager.currency - starting_cash])
		await get_tree().process_frame
	spawner.free()
	CampaignManager.clear_challenge()
	CampaignManager.current_level_index = old_level
	return true

func _test_roster_baseline() -> bool:
	var prices := [150, 225, 200, 100, 300, 175, 75, 125]
	var weights := [150, 200, 175, 125, 225, 0, 50, 125]
	for index in range(BuildManager.towers.size()):
		var data: TowerData = BuildManager.towers[index]
		_check(data.cost == prices[index] and data.weight == weights[index], "roster baseline differs for %s" % data.tower_name)
		var car: Node2D = data.scene.instantiate()
		_check(car.get("weight") == data.weight, "placed %s weight differs from shop" % data.tower_name)
		car.free()
	_check(Menu.ENGINE_COST == 250, "engine purchase/recovery price differs from workbook")
	var train: TrainConvoy = ConvoyScene.instantiate()
	add_child(train)
	train.set_process(false)
	train.configure_path(PackedVector2Array([Vector2.ZERO, Vector2(3000, 0), Vector2(3000, 3000), Vector2(0, 3000)]))
	_check(train.effective_capacity() == 1200, "Steam Engine carry differs from workbook")
	var tender := preload("res://scenes/Tender.tscn").instantiate()
	add_child(tender)
	_check(train.attach_car(tender) and train.effective_capacity() == 1700, "direct Tender did not add 500 carry")
	var guns: Array[Turret] = []
	for scene in [BasicTurretScene, MinigunScene, preload("res://scenes/TurretCoalCannon.tscn"), preload("res://scenes/TurretBallast.tscn"), preload("res://scenes/MailCarrier.tscn")]:
		var gun: Turret = scene.instantiate()
		add_child(gun)
		gun.set_process(false)
		_check(train.attach_car(gun), "baseline consist refused %s" % gun.name)
		guns.append(gun)
	var brake := preload("res://scenes/BrakeVan.tscn").instantiate()
	add_child(brake)
	_check(train.attach_car(brake), "Brake Van failed to attach")
	var spider: EnemyMovement = EnemyScene.instantiate()
	add_child(spider)
	spider.set_physics_process(false)
	spider.health.configure_hit_points(10000)
	for gun in guns:
		_check(gun.damage_multiplier() == 1.25 and gun.attack_speed_multiplier == 1.0, "Brake Van changed cadence or missed a weapon")
		spider.position = gun.global_position + Vector2(0, 70)
		gun.target = spider
		var hp := spider.health.hit_points
		if gun.get_script() == preload("res://scripts/turret_minigun.gd"):
			gun._fire_burst_round(0)
		else:
			gun._shoot()
		var projectile_found := false
		for child in get_children():
			if child is CoalCannonball:
				projectile_found = true
				_check(child.direct_damage == 15 and child.splash_damage == 5, "Brake Van missed Coal Cannon direct/splash damage")
				child.free()
			elif child is Bullet:
				projectile_found = true
				_check(child.bullet_damage == roundi(gun.base_projectile_damage * 1.25), "Brake Van missed projectile damage")
				child.free()
		if gun.get_script() == preload("res://scripts/turret_ballast.gd"):
			_check(hp - spider.health.hit_points == 10, "Brake Van missed Ballast area damage")
		else:
			_check(projectile_found, "buffed weapon did not emit a projectile")
	guns[0].set_meta("damage_multiplier", 2.0)
	_check(train.remove_car(brake) and not train.capped, "removing Brake Van left the consist capped")
	_check(guns[0].damage_multiplier() == 2.0, "removing Brake Van erased a car's own damage modifier")
	for index in range(1, guns.size()):
		_check(guns[index].damage_multiplier() == 1.0, "removed Brake Van left a stale damage buff")
	train.remove_car(tender)
	_check(train.effective_capacity() == 1200, "removing Tender left a stale carry bonus")
	for car in train.followers:
		car.queue_free()
	spider.queue_free()
	train.queue_free()
	return true

func _test_junction_and_jump_timing() -> bool:
	var track := TrackRenderer.new()
	add_child(track)
	track.columns.assign([0.0, 65.5, 131.0])
	track.rows.assign([0.0, 65.5, 131.0])
	track.track_bounds = Rect2(0, 0, 131, 131)
	var junction := Vector2i(1, 1)
	var straight := Vector2i(2, 1)
	var branch := Vector2i(1, 2)
	track.graph = {junction: [Vector2i(0, 1), branch, straight], straight: [junction], branch: [junction]}
	var navigator := RailNavigator.new()
	navigator.setup_edge(track, Vector2(0, 65.5), Vector2(65.5, 65.5), Vector2(65.5, 65.5))
	navigator._extend(true)
	_check(track.cell_of(navigator.points[-1]) == straight, "equal-use junction did not prefer straight")
	track.built_cells[branch] = true
	navigator.setup_edge(track, Vector2(0, 65.5), Vector2(65.5, 65.5), Vector2(65.5, 65.5))
	navigator._extend(true)
	_check(track.cell_of(navigator.points[-1]) == branch, "fresh player branch was ignored")
	# Both exits now visited once: built branch wins the tie; after that,
	# lower-use straight must win so the built spur cannot starve the circuit.
	navigator.setup_edge(track, Vector2(0, 65.5), Vector2(65.5, 65.5), Vector2(65.5, 65.5))
	navigator._extend(true)
	navigator.setup_edge(track, Vector2(0, 65.5), Vector2(65.5, 65.5), Vector2(65.5, 65.5))
	navigator._extend(true)
	_check(track.cell_of(navigator.points[-1]) == straight, "junction repeatedly favored a heavily used spur")
	track.free()
	for fps in [30, 60, 120]:
		var spider: EnemyMovement = EnemyScene.instantiate()
		add_child(spider)
		spider.set_physics_process(false)
		spider.configure_archetype(EnemyRoster.by_id("jump"), 1, 5)
		spider.position = Vector2.ZERO
		spider.configure_route(Vector2(0, 1000))
		for frame in range(int(3.5 * fps)):
			spider._physics_process(1.0 / fps)
		_check(spider.position == Vector2.ZERO, "Jump Spider moved during its windup")
		spider._special_clock = 3.55
		for frame in range(ceili(0.75 * fps)):
			spider._physics_process(1.0 / fps)
		_check(is_equal_approx(spider.position.y, 131.0) and not spider._jumping, "Jump Spider hop length/duration depends on frame rate")
		var landed := spider.position
		spider._physics_process(1.0)
		_check(spider.position == landed and not spider.is_biting(), "Jump Spider did not rest after landing")
		spider.position = Vector2(0, 980)
		spider._special_clock = 3.55
		spider._physics_process(0.75)
		_check(is_equal_approx(spider.position.y, 1000), "short final hop overshot station")
		spider.free()
	return true

func _test_connect_existing_tracks() -> bool:
	var main = await _start_campaign_scene(0, false)
	(main.get_node("TutorialDirector") as TutorialDirector)._skip_all()
	var track: TrackRenderer = main.track
	var builder: RailBuilder = main.rail_builder
	main.menu.set_build_track(true)
	LevelManager.currency = 300
	# The two authored rings touch at adjacent cells without sharing an edge.
	var a := Vector2i(3, 6)
	var b := Vector2i(3, 7)
	var original_routes := track.routes.duplicate()
	var revision := track.revision
	_check(not track.is_dead_end(a) and not track.is_dead_end(b) and not track.network_of(a).has(b), "join fixture is not two separate authored loops")
	_check(track.link_candidates(a).has([a, b]) and track.link_candidates(b).has([b, a]), "existing-track join cannot be selected from either side")
	_check(builder.attempt_link(a, b), "two adjacent existing loops could not be joined")
	_check(LevelManager.currency == 300 and track.revision == revision + 1, "existing-track join charged money or failed to invalidate navigation")
	_check(track.network_of(a).has(b) and b in track.neighbours(a) and a in track.neighbours(b), "join did not create a bidirectional connection")
	_check(track.routes == original_routes and track.routes_are_traversable(), "joining loops rewrote an authored ring")
	_check(track.tiles_at(a).size() > 1 and track.tiles_at(b).size() > 1, "join did not render both junctions")
	_check(not builder.attempt_link(b, a) and track.revision == revision + 1, "duplicate join changed the network")
	_check(not track.evaluate_link(a, Vector2i(4, 7)).ok, "diagonal track join was accepted")
	_check(not track.evaluate_link(a, Vector2i(3, 9)).ok, "join skipped a gap")
	# A second connection between the now-shared network is also valid.
	_check(builder.attempt_link(Vector2i(5, 6), Vector2i(5, 7)), "a second cross-connection between existing tracks was refused")
	main.menu.set_build_track(false)
	PhaseManager.phase = PhaseManager.Phase.BATTLE
	var edges_before := track.revision
	_check(not builder.attempt_link(Vector2i(4, 6), Vector2i(4, 7)) and track.revision == edges_before, "existing circuits were joined during BATTLE")
	var train: TrainConvoy = main.convoys[0]
	train.set_process(false)
	var upper_cells := track.route_cells(0)
	var visited_upper := false
	var visited_lower_after := false
	for frame in range(18000):
		train._process(1.0 / 60.0)
		var cell := track.cell_of(train.global_position)
		visited_upper = visited_upper or cell in upper_cells
		if visited_upper and cell.y >= 8:
			visited_lower_after = true
		_check(not train.movement_blocked, "train stalled while crossing joined circuits")
		_check(train._positions_valid_at(train.route_distance, train.followers.size()), "joined circuits caused the train to overlap itself")
		if visited_lower_after:
			break
	_check(visited_upper and visited_lower_after, "train did not travel into the joined circuit and return")
	main.queue_free()
	await get_tree().process_frame
	PhaseManager.reset()
	return true
