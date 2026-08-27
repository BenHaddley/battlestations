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
	convoy.queue_free()

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
		_check(main.train_control_panel.visible, "engine selection did not reveal train controls")
		main._on_train_command_changed(1)
		_check(main.convoys[0].manual_command == 1, "forward UI command did not reach selected train")
		main._clear_train_selection()
		_check(not main.train_control_panel.visible, "train controls remained after deselection")
	main.queue_free()
	await get_tree().process_frame
