extends Node
class_name Health
## Sits as a child of an enemy body. Pays out the kill bounty and despawns
## the enemy once hit points run out.

@export var hit_points: int = 2
@export var currency_worth: int = 50

var is_destroyed: bool = false

func take_damage(dmg: int) -> void:
	hit_points -= dmg

	if hit_points <= 0 and not is_destroyed:
		is_destroyed = true
		GameEvents.enemy_destroyed.emit()
		LevelManager.increase_currency(currency_worth)
		get_parent().queue_free()
