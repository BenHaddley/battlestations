extends Area2D
class_name CoalCannonball
## Coal Cannon's projectile: full damage on direct hit, weaker splash to
## every other spider caught within range of the impact.

@export var bullet_speed: float = 5.0
@export var direct_damage: int = 3
@export var splash_damage: int = 1
@export var splash_radius: float = 140.0
@export var knockback_distance: float = 90.0

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
	_spawn_impact_effect()
	AudioFX.play(preload("res://assets/audio/sfx/spider_hit.wav"), -2.0)
	if body.has_method("take_damage"):
		body.take_damage(direct_damage)
	if is_instance_valid(body) and body.has_method("apply_knockback"):
		body.apply_knockback(knockback_distance)
	_splash_damage(global_position, body)
	queue_free()

func _splash_damage(center: Vector2, exclude: Node2D) -> void:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = splash_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 2
	for result in space_state.intersect_shape(query, 32):
		var body: Object = result.collider
		if body != exclude and body.has_method("take_damage"):
			body.take_damage(splash_damage)

func _spawn_impact_effect() -> void:
	var effect := Sprite2D.new()
	effect.texture = preload("res://assets/sprites/effects/hit effect.png")
	effect.global_position = global_position
	effect.scale = Vector2(0.09, 0.09)
	effect.modulate = Color(1.0, 0.55, 0.25, 0.95)
	effect.z_index = 70
	get_tree().current_scene.add_child(effect)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(0.16, 0.16), 0.22)
	tween.tween_property(effect, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(effect.queue_free)
