extends Node2D
class_name Tender
## Non-combat car: extra coal and water storage. Its negative weight offsets
## other cars', effectively raising the train's weight_threshold before it
## starts slowing down (see TrainConvoy.total_weight()).

@export var weight: float = -2.0

func set_convoy_transform(world_position: Vector2, direction: Vector2) -> void:
	global_position = world_position
	if not direction.is_zero_approx():
		rotation = direction.angle() - PI * 0.5
