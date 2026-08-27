extends Node2D

var weight: float = 10.0
var attack_speed_multiplier: float = 1.0

func set_convoy_transform(world_position: Vector2, direction: Vector2) -> void:
	global_position = world_position
	if not direction.is_zero_approx():
		rotation = direction.angle()
