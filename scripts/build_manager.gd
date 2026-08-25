extends Node
## Autoload. Holds the tower catalog and which entry the shop panel has selected.

## Autoload scripts have no scene to wire exports in from the Inspector, so
## the starter roster is preloaded here directly. Extend this array as more
## TowerData resources are added under resources/.
@export var towers: Array[TowerData] = [
	preload("res://resources/basic_turret.tres"),
	preload("res://resources/slomo_turret.tres"),
]

var selected_tower: int = 0

func get_selected_tower() -> TowerData:
	if selected_tower < 0 or selected_tower >= towers.size():
		push_warning("No valid tower is selected")
		return null
	return towers[selected_tower]

func set_selected_tower(index: int) -> void:
	if index < 0 or index >= towers.size():
		push_warning("Tower selection index %d is out of range" % index)
		return
	selected_tower = index
