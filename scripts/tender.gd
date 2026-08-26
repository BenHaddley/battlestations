extends Node2D
class_name Tender
## Non-combat car, per its infowiki card (#012): coupled directly behind the
## engine, it grants +500 max pull capacity. Anywhere else in the train, the
## bonus does not apply. TrainConvoy checks adjacency (followers[0]) itself —
## this script just carries its own weight like any other car.

@export var weight: float = 50.0

var is_tender: bool = true

func set_convoy_transform(world_position: Vector2, direction: Vector2) -> void:
	global_position = world_position
	if not direction.is_zero_approx():
		rotation = direction.angle() - PI * 0.5
