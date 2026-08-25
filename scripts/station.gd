extends Node2D
class_name Station
## The thing being defended. Takes a hit for every spider that reaches the
## end of a lane; the run ends once it runs out of health.

signal health_changed(current: int, max_health: int)
signal defeated

@export var max_health: int = 20

var current_health: int

func _ready() -> void:
	current_health = max_health
	GameEvents.enemy_leaked.connect(_on_enemy_leaked)
	health_changed.emit(current_health, max_health)

func _on_enemy_leaked() -> void:
	if current_health <= 0:
		return
	current_health = max(0, current_health - 1)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		defeated.emit()
