extends Node2D
## Scene glue: generates a bounded railway and turns shop drag/drop requests
## into mobile trains locked to that route.

@onready var spawner: EnemySpawner = $EnemySpawner
@onready var track: TrackRenderer = $Track
@onready var trains: Node2D = $Trains
@onready var convoy: Node2D = $Trains/TrainConvoy
@onready var menu: Menu = $CanvasLayer/Menu
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var generated_track: PackedVector2Array

@export_range(0, 6) var starting_cars: int = 3

func _ready() -> void:
	get_tree().root.physics_object_picking = true
	_play_music_looped()
	generated_track = track.generate_layout()
	convoy.configure_path(generated_track)
	if not track.covers_lanes(spawner.lane_x_positions, 360.0):
		push_error("Generated railway does not cover every spider lane.")
	menu.configure(spawner, $Station, convoy)
	menu.train_drag_started.connect(convoy.set_drag_active.bind(true))
	menu.train_drag_ended.connect(convoy.set_drag_active.bind(false))
	menu.train_drop_requested.connect(_on_train_drop_requested)
	spawner.wave_cleared.connect(_on_wave_cleared)
	_seed_tabletop()

## Open on a game already in motion. The illustrated reference reads as a
## tabletop mid-turn, so the first frame should not be one lonely locomotive
## on an empty board. These starter cars are free; bought cars still use the
## normal drag/drop and currency rules.
func _seed_tabletop() -> void:
	for index in range(mini(starting_cars, BuildManager.towers.size() * 2)):
		var tower: TowerData = BuildManager.towers[index % BuildManager.towers.size()]
		if tower == null or tower.scene == null:
			continue
		var train: Node2D = tower.scene.instantiate()
		trains.add_child(train)
		_apply_car_palette(train, index)
		convoy.attach_car(train)
	get_tree().create_timer(0.65).timeout.connect(spawner.start_next_wave)

func _on_wave_cleared(_wave_number: int) -> void:
	if not menu.station_lost:
		get_tree().create_timer(2.5).timeout.connect(spawner.start_next_wave)

## MP3 streams don't loop by default — the loop flag lives on the stream
## resource itself, so it has to be set before play() rather than as a
## one-time .import setting.
func _play_music_looped() -> void:
	var stream: AudioStreamMP3 = music_player.stream as AudioStreamMP3
	if stream:
		stream.loop = true
	music_player.play()

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
	_apply_car_palette(train, convoy.car_count())
	convoy.attach_car(train)
	menu.show_placement_feedback("%s connected to the engine." % tower.tower_name, true)

func _apply_car_palette(car: Node2D, palette_index: int) -> void:
	var palette := [
		Color(1.0, 0.48, 0.42),
		Color(0.45, 0.68, 1.0),
		Color(1.0, 0.82, 0.28),
		Color(0.72, 0.48, 1.0),
		Color(0.48, 0.9, 0.58),
	]
	var sprite: Sprite2D = car.get_node_or_null("Base")
	if sprite == null:
		sprite = car.get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color.WHITE.lerp(palette[palette_index % palette.size()], 0.38)
