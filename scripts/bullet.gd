extends Area2D
class_name Bullet
## Supports both legacy homing shots and fixed-direction rail-gun shots.

@export var bullet_speed: float = 5.0
@export var bullet_damage: int = 1

var target: Node2D = null
var travel_direction := Vector2.ZERO
var _straight_lifetime := 0.0

func set_target(t: Node2D) -> void:
	target = t

func set_direction(direction: Vector2) -> void:
	travel_direction = direction.normalized()
	target = null

func _physics_process(delta: float) -> void:
	if not travel_direction.is_zero_approx():
		global_position += travel_direction * bullet_speed * delta
		_straight_lifetime += delta
		var bounds := get_viewport_rect().grow(120.0)
		if _straight_lifetime > 4.0 or not bounds.has_point(global_position):
			queue_free()
		return
	if not is_instance_valid(target):
		queue_free()
		return
	var direction: Vector2 = (target.global_position - global_position).normalized()
	global_position += direction * bullet_speed * delta

func _on_body_entered(body: Node2D) -> void:
	_spawn_hit_effect()
	AudioFX.play(preload("res://assets/audio/sfx/spider_hit.wav"), -4.0)
	if body.has_method("take_damage"):
		body.take_damage(bullet_damage)
	queue_free()

func _spawn_hit_effect() -> void:
	var effect := Sprite2D.new()
	effect.texture = preload("res://assets/sprites/effects/hit effect.png")
	effect.global_position = global_position
	effect.scale = Vector2(0.055, 0.055)
	effect.z_index = 70
	get_tree().current_scene.add_child(effect)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(0.1, 0.1), 0.18)
	tween.tween_property(effect, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(effect.queue_free)
