extends CharacterBody2D
class_name EnemyMovement
## Walks a spider along LevelManager.path waypoint-by-waypoint. Reaching the
## last waypoint is a leak (no base-health system exists yet) — see wiki.

@export var move_speed: float = 1.0

@onready var health: Health = $Health

var target: Node2D = null
var path_index: int = 0
var base_speed: float

## Absolute ms timestamp (Time.get_ticks_msec()) the current slow expires at.
## Tracking an expiry rather than a bool means a second overlapping pulse can
## only extend the slow, never cut a longer one short.
var _slow_expires_at: int = 0

func _ready() -> void:
	base_speed = move_speed
	if LevelManager.path.size() > 0:
		target = LevelManager.path[path_index]

func _process(_delta: float) -> void:
	if target == null:
		return

	if global_position.distance_to(target.global_position) <= 0.1:
		path_index += 1

		if path_index == LevelManager.path.size():
			GameEvents.enemy_destroyed.emit()
			queue_free()
			return

		target = LevelManager.path[path_index]

func _physics_process(_delta: float) -> void:
	if target == null:
		return
	var speed: float = base_speed * 0.5 if Time.get_ticks_msec() < _slow_expires_at else base_speed
	var direction: Vector2 = (target.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

## Slows the enemy to half its base speed for `duration` seconds. Safe to
## call while already slowed — only extends the effect, never shortens it.
func apply_slow(duration: float) -> void:
	_slow_expires_at = max(_slow_expires_at, Time.get_ticks_msec() + int(duration * 1000.0))

func take_damage(dmg: int) -> void:
	health.take_damage(dmg)
