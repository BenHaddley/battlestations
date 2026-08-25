extends Node2D
class_name TurretSlomo
## Crowd-control turret. Deals no damage — pulses its TargetingArea on a
## timer and halves the speed of everything caught inside for a fixed time.

@onready var targeting_area: Area2D = $TargetingArea

@export_group("Attributes")
@export var targeting_range: float = 5.0
@export var aps: float = 0.25 ## pulses per second
@export var freeze_time: float = 1.0

var time_until_fire: float = 0.0

func _process(delta: float) -> void:
	time_until_fire += delta
	if time_until_fire >= 1.0 / aps:
		_freeze_enemies()
		time_until_fire = 0.0

func _freeze_enemies() -> void:
	for body in targeting_area.get_overlapping_bodies():
		if body.has_method("apply_slow"):
			body.apply_slow(freeze_time)
