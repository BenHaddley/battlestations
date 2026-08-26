extends Node
class_name Health
## Sits as a child of an enemy body. Pays out the kill bounty and despawns
## the enemy once hit points run out.

signal hit_points_changed(current: int, max_hit_points: int)

@export var hit_points: int = 15
@export var currency_worth: int = 50

var is_destroyed: bool = false
var max_hit_points: int

func _ready() -> void:
	max_hit_points = hit_points

func configure_hit_points(value: int, notify: bool = true) -> void:
	hit_points = maxi(value, 1)
	max_hit_points = hit_points
	if notify:
		hit_points_changed.emit(hit_points, max_hit_points)

func take_damage(dmg: int) -> void:
	hit_points -= dmg
	hit_points_changed.emit(maxi(hit_points, 0), max_hit_points)

	if hit_points <= 0 and not is_destroyed:
		is_destroyed = true
		GameEvents.enemy_destroyed.emit()
		LevelManager.increase_currency(currency_worth)
		AudioFX.play(preload("res://assets/audio/sfx/spider_death.wav"), -3.0)
		if get_parent().has_method("play_destroyed_effect"):
			get_parent().play_destroyed_effect(currency_worth)
		get_parent().queue_free()
