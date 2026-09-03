extends Node2D
class_name EnemySpawner
## Wave director. Sizes and paces each wave, assigns each spider to one of
## the courtyard's seven vertical lanes. Waves start only when the player
## calls start_next_wave() — there is no auto-timer between them.

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)

@export var balance: GameBalance = preload("res://resources/game_balance.tres")

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
@export var early_bounty: int = 18 ## Kills are bonus income; coaches fund sustained expansion.
@export var wave_bonus_base: int = 35
@export var wave_bonus_per_wave: int = 12
## Set by Main from CampaignManager's current level. 0 means endless — no
## level-complete trigger, waves just keep climbing as before.
@export var wave_target: int = 0

var current_wave: int = 0
var time_since_last_spawn: float = 0.0
var enemies_alive: int = 0
var enemies_left_to_spawn: int = 0
var eps: float = 0.0 ## enemies per second, current wave
var is_spawning: bool = false
var telemetry: Dictionary = {}

func _ready() -> void:
	_apply_balance()
	GameEvents.enemy_destroyed.connect(_on_enemy_destroyed)
	LevelManager.currency_changed.connect(_on_currency_changed)

func _apply_balance() -> void:
	if balance == null:
		return
	base_enemies = balance.base_enemies
	enemies_per_second = balance.base_spawn_rate
	difficulty_scaling_factor = balance.enemy_count_exponent
	spawn_rate_scaling_factor = balance.spawn_rate_exponent
	enemies_per_second_cap = balance.spawn_rate_cap
	journey_duration_seconds = balance.journey_duration
	early_bounty = balance.early_generic_bounty
	wave_bonus_base = balance.wave_bonus_base
	wave_bonus_per_wave = balance.wave_bonus_per_wave

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
	telemetry = {
		"wave": current_wave,
		"starting_delta": LevelManager.currency,
		"kills": 0,
		"spending": 0,
		"income": 0,
	}
	wave_started.emit(current_wave)

func enemies_remaining() -> int:
	return enemies_alive + enemies_left_to_spawn

func _on_enemy_destroyed() -> void:
	enemies_alive -= 1
	if not telemetry.is_empty():
		telemetry.kills = int(telemetry.get("kills", 0)) + 1

func _on_currency_changed(_balance: int, delta: int, _reason: String) -> void:
	if telemetry.is_empty() or not is_spawning:
		return
	if delta < 0:
		telemetry.spending = int(telemetry.get("spending", 0)) - delta
	elif delta > 0:
		telemetry.income = int(telemetry.get("income", 0)) + delta

func _end_wave() -> void:
	is_spawning = false
	var payout_scale := float(CampaignManager.challenge_value("bounty", 1.0))
	LevelManager.increase_currency(roundi((wave_bonus_base + wave_bonus_per_wave * current_wave) * payout_scale), "wave_bonus")
	telemetry.ending_delta = LevelManager.currency
	telemetry.net_delta = LevelManager.currency - int(telemetry.get("starting_delta", LevelManager.currency))
	if OS.is_debug_build():
		print("WAVE TELEMETRY %s" % telemetry)
	wave_cleared.emit(current_wave)
	GameEvents.wave_completed.emit(current_wave)
	if wave_target > 0 and current_wave >= wave_target:
		CampaignManager.complete_current_level()

## Debug-only jump used for balance passes. The requested wave becomes the next
## wave started, preserving the normal start signal and formula setup.
func debug_select_next_wave(wave_number: int) -> bool:
	if not OS.is_debug_build() or is_spawning or wave_number < 1:
		return false
	current_wave = wave_number - 1
	return true

func _spawn_enemy() -> void:
	if enemy_prefabs.is_empty() or lane_x_positions.is_empty():
		return
	var prefab: PackedScene = enemy_prefabs[randi() % enemy_prefabs.size()]
	var enemy: Node2D = prefab.instantiate()
	get_tree().current_scene.add_child(enemy)
	var campaign_level := int(CampaignManager.get("current_level_index"))
	var forced_enemy := String(CampaignManager.challenge_value("enemy", ""))
	var profile := EnemyRoster.by_id(forced_enemy) if not forced_enemy.is_empty() else EnemyRoster.pick(campaign_level)
	DiscoveryTracker.discover("enemy:%s" % String(profile.get("id", "generic")))
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
	var bounty_scale := float(CampaignManager.challenge_value("bounty", 1.0))
	if enemy.has_method("configure_bounty") and not is_equal_approx(bounty_scale, 1.0):
		var normal_bounty := early_bounty if current_wave <= 3 and String(profile.get("id", "generic")) == "generic" else int(profile.get("bounty", 45)) + campaign_level * 8
		enemy.configure_bounty(maxi(1, roundi(normal_bounty * bounty_scale)))
	if enemy.has_method("configure_lane"):
		enemy.configure_lane(leak_y, _journey_duration_for_wave())

## Player-requested deployment for Spider Assault. This deliberately uses the
## same scene, roster data, lane movement, health and station-attack behavior
## as normal waves. `destination.x` is intentionally ignored: spiders remain
## in the top lane the player chose instead of cutting diagonally across lanes.
func spawn_controlled_spider(profile_id: String, entrance: Vector2, destination: Vector2, swarm_active: bool = false) -> Node2D:
	if enemy_prefabs.is_empty():
		return null
	var profile := EnemyRoster.by_id(profile_id)
	if profile.is_empty():
		return null
	DiscoveryTracker.discover("enemy:%s" % profile_id)
	var enemy: Node2D = enemy_prefabs[0].instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = entrance
	enemy.scale = Vector2(0.54, 0.54)
	enemy.set_meta("player_deployed", true)
	if enemy.has_method("configure_archetype"):
		enemy.configure_archetype(profile, 1, 2)
	if enemy.has_method("configure_bounty"):
		enemy.configure_bounty(0)
	if enemy.has_method("configure_lane"):
		enemy.configure_lane(destination.y, journey_duration_seconds)
	enemy.set_meta("assault_lane_x", entrance.x)
	enemy.set("assault_speed_multiplier", 1.6 if swarm_active else 1.0)
	enemies_alive += 1
	return enemy

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
