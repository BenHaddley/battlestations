extends Node
## Headless regression coverage for convoy spacing/reverse motion and persistent
## station attackers. Run with: godot --headless --path . --script tests/gameplay_regression.gd

const ConvoyScene := preload("res://scenes/TrainConvoy.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const StationScene := preload("res://scenes/Station.tscn")
const MainScene := preload("res://scenes/Main.tscn")

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
	await _test_station_attackers()
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
	_check(CampaignManager.CHALLENGES.size() == 5, "challenge menu should expose five launchable job cards")
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

func _test_main_scene_train_integration() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
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
