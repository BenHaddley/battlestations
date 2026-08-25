extends Node2D
## Scene glue: feeds the hand-placed path markers into LevelManager, the
## way the Unity scene wired Transforms into public Inspector fields.

@onready var path_points: Node2D = $Path

func _ready() -> void:
	# Area2D.input_event (Plot's click handling) never fires without this —
	# physics object picking is off by default on the root viewport.
	get_tree().root.physics_object_picking = true

	var points: Array[Node2D] = []
	for child in path_points.get_children():
		points.append(child)
	LevelManager.path = points

	# EnemySpawner.start_point is a cross-tree sibling reference — a NodePath
	# literal in the .tscn doesn't resolve for typed Node exports written by
	# hand rather than the editor's node picker, so it's wired here instead.
	$EnemySpawner.start_point = path_points.get_node("StartPoint")
