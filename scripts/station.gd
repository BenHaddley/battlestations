extends Node2D
class_name Station
## The thing being defended. Spiders that reach it remain on the board and
## attack periodically until killed; the run ends once HP reaches zero.

signal health_changed(current: int, max_health: int)
signal defeated

@export var max_health: int = 60

var current_health: int
var resting_position: Vector2

func _ready() -> void:
	current_health = max_health
	resting_position = position
	GameEvents.station_attacked.connect(take_damage)
	health_changed.emit(current_health, max_health)

func take_damage(amount: int = 1) -> void:
	if current_health <= 0:
		return
	AudioFX.play_cue(&"station_hit")
	current_health = max(0, current_health - maxi(amount, 0))
	var tween := create_tween()
	for offset in [Vector2(10, 0), Vector2(-9, 0), Vector2(6, 0), Vector2.ZERO]:
		tween.tween_property(self, "position", resting_position + offset, 0.045)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		defeated.emit()
