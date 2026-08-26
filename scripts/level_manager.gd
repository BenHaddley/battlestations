extends Node
## Autoload. Owns the rail path and the currency wallet — Godot equivalent
## of Unity's LevelManager.main singleton. Currency is Delta, per the
## infowiki's Passenger Coach card (#003) — the first card to actually name it.

## Scaled up alongside the infowiki's car costs (roughly 3x the old tens-scale
## prices), so a run still opens able to afford 2-3 basic cars.
@export var starting_currency: int = 450

var path: Array[Node2D] = []
var currency: int = 0

func _ready() -> void:
	currency = starting_currency

## CampaignManager calls this between levels — autoload state survives a
## scene reload, so the wallet needs an explicit reset to the new level's
## starting_currency rather than relying on _ready() (which only fires once
## per game process).
func reset_currency(amount: int) -> void:
	starting_currency = amount
	currency = amount

func increase_currency(amount: int) -> void:
	currency += amount

func spend_currency(amount: int) -> bool:
	if amount <= currency:
		currency -= amount
		return true
	push_warning("You do not have enough to purchase this item")
	return false
