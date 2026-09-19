extends Node2D
## Visual-only car for reviewing draft artwork on moving sandbox trains.
@export var weight := 0.0

func set_convoy_transform(world_position: Vector2, direction: Vector2) -> void:
	global_position = world_position
	if not direction.is_zero_approx():
		rotation = direction.angle() - PI * 0.5
