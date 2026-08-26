extends Node2D
class_name BrakeVan
## Caps the train — TrainConvoy refuses further attachments once one of
## these is coupled — and grants every other car in that train a 20%
## attack-speed boost. Doesn't count toward the train's weight.

@export var weight: float = 0.0
@export var attack_speed_bonus: float = 1.2

var is_train_cap: bool = true

func set_convoy_transform(world_position: Vector2, direction: Vector2) -> void:
	global_position = world_position
	if not direction.is_zero_approx():
		rotation = direction.angle() - PI * 0.5
