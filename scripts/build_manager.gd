extends Node
## Autoload. Holds the tower catalog and which entry the shop panel has selected.

## Autoload scripts have no scene to wire exports in from the Inspector, so
## the starter roster is preloaded here directly. Extend this array as more
## TowerData resources are added under resources/.
## Every entry here has a corresponding card in the recovered infowiki
## (assets/infowiki/, transcribed in wiki/infowiki-cards.md) — Slomo and the
## earlier standalone Chaingun car had no card and were removed; Minigun's
## card names it "Chaingunner Car," so that's what ships under.
@export var towers: Array[TowerData] = [
	preload("res://resources/basic_turret.tres"),
	preload("res://resources/minigun_turret.tres"),
	preload("res://resources/ballast_turret.tres"),
	preload("res://resources/passenger_coach.tres"),
	preload("res://resources/coal_cannon_turret.tres"),
	preload("res://resources/brake_van.tres"),
	preload("res://resources/tender_car.tres"),
]

var selected_tower: int = 0

func get_selected_tower() -> TowerData:
	if selected_tower < 0 or selected_tower >= towers.size():
		push_warning("No valid tower is selected")
		return null
	return towers[selected_tower]

func set_selected_tower(index: int, warn_on_failure: bool = true) -> void:
	if index < 0 or index >= towers.size():
		if warn_on_failure:
			push_warning("Tower selection index %d is out of range" % index)
		return
	selected_tower = index
