extends CharacterBody2D
class_name EnemyMovement
## Walks a spider along LevelManager.path waypoint-by-waypoint. Reaching the
## last waypoint is a leak (no base-health system exists yet) — see wiki.

@export var move_speed: float = 1.0
@export var health: Health

var target: Node2D = null
var path_index: int = 0
var base_speed: float

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
	var direction: Vector2 = (target.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

func update_speed(new_speed: float) -> void:
	move_speed = new_speed

func reset_speed() -> void:
	move_speed = base_speed

func take_damage(dmg: int) -> void:
	if health:
		health.take_damage(dmg)
