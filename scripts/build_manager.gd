extends Node
## Autoload. Holds the tower catalog and which entry the shop panel has selected.

@export var towers: Array[TowerData] = []

var selected_tower: int = 0

func get_selected_tower() -> TowerData:
	return towers[selected_tower]

func set_selected_tower(index: int) -> void:
	selected_tower = index
