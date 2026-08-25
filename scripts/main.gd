extends Node2D
## Scene glue: enables click picking and lays the track visuals along
## whatever lanes EnemySpawner is actually configured to spawn into, so the
## rails can never drift out of sync with where enemies really walk.

func _ready() -> void:
	# Area2D.input_event (Plot's click handling) never fires without this —
	# physics object picking is off by default on the root viewport.
	get_tree().root.physics_object_picking = true

	var spawner: EnemySpawner = $EnemySpawner
	$Track.build(spawner.lane_x_positions, spawner.spawn_y, spawner.leak_y)
	$CanvasLayer/Menu.configure(spawner, $Station)
