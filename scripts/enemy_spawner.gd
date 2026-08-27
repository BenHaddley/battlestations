extends Node2D
class_name EnemySpawner
## Wave director. Sizes and paces each wave, assigns each spider to one of
## the courtyard's seven vertical lanes. Waves start only when the player
## calls start_next_wave() — there is no auto-timer between them.

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)

@export var enemy_prefabs: Array[PackedScene] = []
@export var lane_x_positions: PackedFloat32Array = PackedFloat32Array([-262.0, -196.5, -131.0, -65.5, 0.0, 65.5, 131.0, 196.5, 262.0])
@export var spawn_y: float = -425.0
@export var leak_y: float = 380.0
@export_range(20.0, 30.0, 0.5) var journey_duration_seconds: float = 25.0

@export_group("Attributes")
@export var base_enemies: int = 3
@export var enemies_per_second: float = 0.4
## Exponent for the enemy-count curve (see _enemies_per_wave). Kept separate
## from the spawn-rate exponent below so the two can be tuned independently.
@export var difficulty_scaling_factor: float = 1.15
@export var spawn_rate_scaling_factor: float = 0.75
@export var enemies_per_second_cap: float = 15.0
## Scaled up alongside the infowiki's car costs so early-wave payouts still
## feel proportionate to what things actually cost now.
@export var early_bounty: int = 120 ## Paid per kill through wave 3, so players can freely experiment.
@export var wave_bonus_base: int = 75 ## Flat currency awarded on top of the per-wave scaling bonus below.
@export var wave_bonus_per_wave: int = 30
## Set by Main from CampaignManager's current level. 0 means endless — no
## level-complete trigger, waves just keep climbing as before.
@export var wave_target: int = 0

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
	LevelManager.increase_currency(wave_bonus_base + wave_bonus_per_wave * current_wave)
	wave_cleared.emit(current_wave)
	if wave_target > 0 and current_wave >= wave_target:
		CampaignManager.complete_current_level()

func _spawn_enemy() -> void:
	if enemy_prefabs.is_empty() or lane_x_positions.is_empty():
		return
	var prefab: PackedScene = enemy_prefabs[randi() % enemy_prefabs.size()]
	var enemy: Node2D = prefab.instantiate()
	get_tree().current_scene.add_child(enemy)
	var campaign_level := int(CampaignManager.get("current_level_index"))
	var profile := EnemyRoster.pick(campaign_level)
	if enemy.has_method("configure_archetype"):
		enemy.configure_archetype(profile, current_wave, campaign_level)
	# The new courtyard uses 65.5-unit cells instead of the previous 90-unit
	# board. Scale the complete enemy body, including collision, with the art.
	enemy.scale = Vector2(0.54, 0.54)
	var lane_x: float = lane_x_positions[randi() % lane_x_positions.size()]
	enemy.global_position = Vector2(lane_x, spawn_y)
	if enemy.has_method("configure_difficulty") and String(profile.get("id", "generic")) == "generic":
		enemy.configure_difficulty(_hit_points_for_wave())
	if enemy.has_method("configure_bounty") and current_wave <= 3 and String(profile.get("id", "generic")) == "generic":
		enemy.configure_bounty(early_bounty)
	if enemy.has_method("configure_lane"):
		enemy.configure_lane(leak_y, _journey_duration_for_wave())

func _hit_points_for_wave() -> int:
	# The visual roster is also the difficulty ladder: wave one starts with
	# the forgiving one-dot form, then adds exactly one two-hit stage per wave.
	# Wave seven and later use the full six-dot, 15-hit spider.
	return mini(3 + maxi(current_wave - 1, 0) * 2, 15)

## Waves 1–4 target a gentle, hand-tuned 3 / 5 / 7 / 10 count so the opening
## of a run teaches rather than pressures; the power curve resumes from
## there so later waves still ramp toward the original intended difficulty.
func _enemies_per_wave() -> int:
	return base_enemies + roundi(2.0 * pow(maxf(current_wave - 1, 0), difficulty_scaling_factor))

func _enemies_per_second() -> float:
	return clamp(enemies_per_second * pow(current_wave, spawn_rate_scaling_factor), 0.0, enemies_per_second_cap)

## Early waves walk noticeably slower so a first-time player has time to
## watch a single spider get chewed up before the pace picks back up.
func _journey_duration_for_wave() -> float:
	var early_bonus_seconds := maxf(0.0, 9.0 - 2.0 * (current_wave - 1))
	return journey_duration_seconds + early_bonus_seconds
