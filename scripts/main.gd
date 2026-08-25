extends Node2D
## Scene glue: feeds the hand-placed path markers into LevelManager, the
## way the Unity scene wired Transforms into public Inspector fields.

@onready var path_points: Node2D = $Path

func _ready() -> void:
	var points: Array[Node2D] = []
	for child in path_points.get_children():
		points.append(child)
	LevelManager.path = points
