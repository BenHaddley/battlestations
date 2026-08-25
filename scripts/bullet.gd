extends Area2D
class_name Bullet
## Homes toward its locked target, deals damage on contact, self-destructs.

@export var bullet_speed: float = 5.0
@export var bullet_damage: int = 1

var target: Node2D = null

func set_target(t: Node2D) -> void:
	target = t

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var direction: Vector2 = (target.global_position - global_position).normalized()
	global_position += direction * bullet_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(bullet_damage)
	queue_free()
