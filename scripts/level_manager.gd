extends Node
## Autoload. Owns the rail path and the currency wallet — Godot equivalent
## of Unity's LevelManager.main singleton.

@export var starting_currency: int = 300

var path: Array[Node2D] = []
var currency: int = 0

func _ready() -> void:
	currency = starting_currency

func increase_currency(amount: int) -> void:
	currency += amount

func spend_currency(amount: int) -> bool:
	if amount <= currency:
		currency -= amount
		return true
	push_warning("You do not have enough to purchase this item")
	return false
