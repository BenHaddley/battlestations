extends Node2D
class_name EnemySpawner
## Wave director. Sizes and paces each wave, assigns each spider to one of
## the courtyard's seven vertical lanes. Waves start only when the player
## calls start_next_wave() — there is no auto-timer between them.

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)

@export var enemy_prefabs: Array[PackedScene] = []
@export var lane_x_positions: PackedFloat32Array = PackedFloat32Array([-350.0, -235.0, -118.0, 0.0, 118.0, 235.0, 350.0])
@export var spawn_y: float = -520.0
@export var leak_y: float = 720.0

@export_group("Attributes")
@export var base_enemies: int = 8
@export var enemies_per_second: float = 0.5
@export var difficulty_scaling_factor: float = 0.75
@export var enemies_per_second_cap: float = 15.0

var current_wave: int = 0
var time_since_last_spawn: float = 0.0
var enemies_alive: int = 0
var enemies_left_to_spawn: int = 0
var eps: float = 0.0 ## enemies per second, current wave
var is_spawning: bool = false

func _ready() -> void:
	GameEvents.enemy_destroyed.connect(_on_enemy_destroyed)

func _process(delta: float) -> void:
	if not is_spawning:
		return

	time_since_last_spawn += delta

	if time_since_last_spawn >= (1.0 / eps) and enemies_left_to_spawn > 0:
		_spawn_enemy()
		enemies_left_to_spawn -= 1
		enemies_alive += 1
		time_since_last_spawn = 0.0

	if enemies_alive == 0 and enemies_left_to_spawn == 0:
		_end_wave()

func can_start_next_wave() -> bool:
	return not is_spawning

func start_next_wave() -> void:
	if is_spawning:
		return
	current_wave += 1
	is_spawning = true
	time_since_last_spawn = 0.0
	enemies_left_to_spawn = _enemies_per_wave()
	eps = _enemies_per_second()
	wave_started.emit(current_wave)

func enemies_remaining() -> int:
	return enemies_alive + enemies_left_to_spawn

func _on_enemy_destroyed() -> void:
	enemies_alive -= 1

func _end_wave() -> void:
	is_spawning = false
	wave_cleared.emit(current_wave)

func _spawn_enemy() -> void:
	if enemy_prefabs.is_empty() or lane_x_positions.is_empty():
		return
	var prefab: PackedScene = enemy_prefabs[randi() % enemy_prefabs.size()]
	var enemy: Node2D = prefab.instantiate()
	get_tree().current_scene.add_child(enemy)
	var lane_x: float = lane_x_positions[randi() % lane_x_positions.size()]
	enemy.global_position = Vector2(lane_x, spawn_y)
	if enemy.has_method("configure_lane"):
		enemy.configure_lane(leak_y)

func _enemies_per_wave() -> int:
	return roundi(base_enemies * pow(current_wave, difficulty_scaling_factor))

func _enemies_per_second() -> float:
	return clamp(enemies_per_second * pow(current_wave, difficulty_scaling_factor), 0.0, enemies_per_second_cap)
