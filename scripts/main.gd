extends Node2D
## Scene glue: generates a bounded railway and turns shop drag/drop requests
## into mobile trains locked to that route.

@onready var spawner: EnemySpawner = $EnemySpawner
@onready var track: TrackRenderer = $Track
@onready var trains: Node2D = $Trains
@onready var convoy: Node2D = $Trains/TrainConvoy
@onready var menu: Menu = $CanvasLayer/Menu

var generated_track: PackedVector2Array

func _ready() -> void:
	get_tree().root.physics_object_picking = true
	generated_track = track.generate_layout()
	convoy.configure_path(generated_track)
	if not track.covers_lanes(spawner.lane_x_positions, 360.0):
		push_error("Generated railway does not cover every spider lane.")
	menu.configure(spawner, $Station, convoy)
	menu.train_drag_started.connect(convoy.set_drag_active.bind(true))
	menu.train_drag_ended.connect(convoy.set_drag_active.bind(false))
	menu.train_drop_requested.connect(_on_train_drop_requested)

func _on_train_drop_requested(tower_index: int, screen_position: Vector2) -> void:
	if tower_index < 0 or tower_index >= BuildManager.towers.size():
		menu.show_placement_feedback("That train is not configured.", false)
		return

	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	if not convoy.can_attach_at(world_position):
		menu.show_placement_feedback("Drop the car onto the black engine or its connected train.", false)
		return

	var tower: TowerData = BuildManager.towers[tower_index]
	if tower == null or tower.scene == null:
		menu.show_placement_feedback("That train is not configured.", false)
		return
	if not LevelManager.spend_currency(tower.cost):
		menu.show_placement_feedback("Not enough funds for %s." % tower.tower_name, false)
		return

	var train: Node2D = tower.scene.instantiate()
	trains.add_child(train)
	convoy.attach_car(train)
	menu.show_placement_feedback("%s connected to the engine." % tower.tower_name, true)
