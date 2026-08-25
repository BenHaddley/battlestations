extends CharacterBody2D
class_name EnemyMovement
## Walks a spider straight down its assigned courtyard lane. Reaching the
## bottom is a leak (no base-health system exists yet) — see wiki.

@export var move_speed: float = 1.0

@onready var health: Health = $Health

var base_speed: float
var leak_y: float = 720.0
var lane_configured: bool = false

## Absolute ms timestamp (Time.get_ticks_msec()) the current slow expires at.
## Tracking an expiry rather than a bool means a second overlapping pulse can
## only extend the slow, never cut a longer one short.
var _slow_expires_at: int = 0

func _ready() -> void:
	base_speed = move_speed

func configure_lane(destination_y: float) -> void:
	leak_y = destination_y
	lane_configured = true

func _physics_process(_delta: float) -> void:
	if not lane_configured:
		return
	if global_position.y >= leak_y:
		GameEvents.enemy_destroyed.emit()
		GameEvents.enemy_leaked.emit()
		queue_free()
		return
	var speed: float = base_speed * 0.5 if Time.get_ticks_msec() < _slow_expires_at else base_speed
	velocity = Vector2.DOWN * speed
	move_and_slide()

## Slows the enemy to half its base speed for `duration` seconds. Safe to
## call while already slowed — only extends the effect, never shortens it.
func apply_slow(duration: float) -> void:
	_slow_expires_at = max(_slow_expires_at, Time.get_ticks_msec() + int(duration * 1000.0))

func take_damage(dmg: int) -> void:
	health.take_damage(dmg)
