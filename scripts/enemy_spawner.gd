extends Node2D
class_name EnemySpawner
## Wave director. Sizes and paces each wave, spawns a random enemy scene at
## the start point, waits between waves once the board is clear.

@export var enemy_prefabs: Array[PackedScene] = []
@export var start_point: Node2D

@export_group("Attributes")
@export var base_enemies: int = 8
@export var enemies_per_second: float = 0.5
@export var time_between_waves: float = 5.0
@export var difficulty_scaling_factor: float = 0.75
@export var enemies_per_second_cap: float = 15.0

var current_wave: int = 1
var time_since_last_spawn: float = 0.0
var enemies_alive: int = 0
var enemies_left_to_spawn: int = 0
var eps: float = 0.0 ## enemies per second, current wave
var is_spawning: bool = false

func _ready() -> void:
	GameEvents.enemy_destroyed.connect(_on_enemy_destroyed)
	_start_wave()

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

func _on_enemy_destroyed() -> void:
	enemies_alive -= 1

func _start_wave() -> void:
	await get_tree().create_timer(time_between_waves).timeout
	is_spawning = true
	enemies_left_to_spawn = _enemies_per_wave()
	eps = _enemies_per_second()

func _end_wave() -> void:
	is_spawning = false
	time_since_last_spawn = 0.0
	current_wave += 1
	_start_wave()

func _spawn_enemy() -> void:
	if enemy_prefabs.is_empty() or start_point == null:
		return
	var prefab: PackedScene = enemy_prefabs[randi() % enemy_prefabs.size()]
	var enemy: Node2D = prefab.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = start_point.global_position

func _enemies_per_wave() -> int:
	return roundi(base_enemies * pow(current_wave, difficulty_scaling_factor))

func _enemies_per_second() -> float:
	return clamp(enemies_per_second * pow(current_wave, difficulty_scaling_factor), 0.0, enemies_per_second_cap)
