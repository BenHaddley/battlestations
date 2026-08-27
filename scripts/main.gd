extends Node2D
## Scene glue: generates several bounded railway routes and turns shop
## drag/drop requests into cars attached to whichever train the drop lands
## near.

const TrainConvoyScene := preload("res://scenes/TrainConvoy.tscn")
const NEW_BOARD_CAR_SCALE := Vector2(0.54, 0.54)

@onready var spawner: EnemySpawner = $EnemySpawner
@onready var track: TrackRenderer = $Track
@onready var trains: Node2D = $Trains
@onready var menu: Menu = $CanvasLayer/Menu

## One TrainConvoy instance per generated route, in generation order.
var convoys: Array[Node2D] = []

@export_range(2, 4) var starting_trains: int = 2
@export_range(0, 6) var starting_cars: int = 1
@export_range(1, 8) var max_generation_attempts: int = 6

## The infowiki's Steam Engine card (#001): "can be spawned in one of 25
## unique paint jobs at random" — these are exactly those 25 liveries,
## drawn without replacement each run so two engines on the board can never
## share a color.
const ENGINE_LIVERIES: Array[Texture2D] = [
	preload("res://assets/sprites/engines/Steam Engine 1.png"),
	preload("res://assets/sprites/engines/Steam Engine 2.png"),
	preload("res://assets/sprites/engines/Steam Engine 3.png"),
	preload("res://assets/sprites/engines/Steam Engine 4.png"),
	preload("res://assets/sprites/engines/Steam Engine 5.png"),
	preload("res://assets/sprites/engines/Steam Engine 6.png"),
	preload("res://assets/sprites/engines/Steam Engine 7.png"),
	preload("res://assets/sprites/engines/Steam Engine 8.png"),
	preload("res://assets/sprites/engines/Steam Engine 9.png"),
	preload("res://assets/sprites/engines/Steam Engine 10.png"),
	preload("res://assets/sprites/engines/Steam Engine 11.png"),
	preload("res://assets/sprites/engines/Steam Engine 12.png"),
	preload("res://assets/sprites/engines/Steam Engine 13.png"),
	preload("res://assets/sprites/engines/Steam Engine 14.png"),
	preload("res://assets/sprites/engines/Steam Engine 15.png"),
	preload("res://assets/sprites/engines/Steam Engine 16.png"),
	preload("res://assets/sprites/engines/Steam Engine 17.png"),
	preload("res://assets/sprites/engines/Steam Engine 18.png"),
	preload("res://assets/sprites/engines/Steam Engine 19.png"),
	preload("res://assets/sprites/engines/Steam Engine 20.png"),
	preload("res://assets/sprites/engines/Steam Engine 21.png"),
	preload("res://assets/sprites/engines/Steam Engine 22.png"),
	preload("res://assets/sprites/engines/Steam Engine 23.png"),
	preload("res://assets/sprites/engines/Steam Engine 24.png"),
	preload("res://assets/sprites/engines/Steam Engine 25.png"),
]

var _car_palette_cursor := 0
var upgrade_panel: UnitUpgradePanel
var level_complete_overlay: LevelCompleteOverlay
var train_control_panel: TrainControlPanel
var selected_convoy: TrainConvoy

func _ready() -> void:
	get_tree().root.physics_object_picking = true
	if CampaignManager.is_challenge_active():
		starting_trains = int(CampaignManager.challenge_value("trains", starting_trains))
		starting_cars = int(CampaignManager.challenge_value("cars", starting_cars))
	var level: LevelData = CampaignManager.current_level()
	if level:
		LevelManager.reset_currency(level.starting_currency)
		spawner.wave_target = level.wave_count
	_generate_and_spawn_trains()
	menu.configure(spawner, $Station, convoys)
	for convoy in convoys:
		menu.train_drag_started.connect(convoy.set_drag_active.bind(true))
		menu.train_drag_ended.connect(convoy.set_drag_active.bind(false))
	menu.train_drop_requested.connect(_on_train_drop_requested)
	menu.remove_requested.connect(_on_remove_requested)
	_seed_tabletop()
	upgrade_panel = UnitUpgradePanel.new()
	$CanvasLayer.add_child(upgrade_panel)
	upgrade_panel.sell_requested.connect(_on_upgrade_sell_requested)
	level_complete_overlay = LevelCompleteOverlay.new()
	$CanvasLayer.add_child(level_complete_overlay)
	level_complete_overlay.continue_pressed.connect(CampaignManager.advance_to_next_level)
	CampaignManager.level_completed.connect(level_complete_overlay.show_for)
	train_control_panel = TrainControlPanel.new()
	$CanvasLayer.add_child(train_control_panel)
	train_control_panel.anchor_left = 0.5
	train_control_panel.anchor_right = 0.5
	train_control_panel.anchor_top = 1.0
	train_control_panel.anchor_bottom = 1.0
	train_control_panel.offset_left = -250.0
	train_control_panel.offset_right = 250.0
	train_control_panel.offset_top = -104.0
	train_control_panel.offset_bottom = -4.0
	train_control_panel.control_changed.connect(_on_train_control_changed)
	train_control_panel.deselect_requested.connect(_clear_train_selection)

## Regenerates the railway until it passes validation (every lane reachable,
## every route internally connected, at least two usable routes) or the
## attempt budget runs out — see track_renderer.gd's module placement and
## covers_lanes()/routes_are_traversable(). Falling back to whatever the
## last attempt produced beats a hard failure; the push_error still makes a
## bad board loudly visible in testing rather than silently shipping one.
func _generate_and_spawn_trains() -> void:
	var routes: Array[PackedVector2Array] = []
	var level := CampaignManager.current_level()
	var uses_campaign_track := level != null and level.track_layout_index >= 0
	if uses_campaign_track:
		routes = track.generate_campaign_layout(level.track_layout_index)
	else:
		for attempt in range(max_generation_attempts):
			routes = track.generate_layout(starting_trains)
			var valid := routes.size() >= 2 \
				and track.covers_lanes(spawner.lane_x_positions, 360.0) \
				and track.routes_are_traversable()
			if valid:
				break
	if routes.size() < 2:
		if not CampaignManager.is_challenge_active() or routes.is_empty():
			push_error("Track generation could not place at least two usable routes.")
	elif not track.covers_lanes(spawner.lane_x_positions, 360.0):
		push_error("Generated railway does not cover every spider lane.")

	if CampaignManager.is_challenge_active() and routes.size() > starting_trains:
		routes.resize(starting_trains)
	for child in trains.get_children():
		child.queue_free()
	convoys = []
	var livery_indices := range(ENGINE_LIVERIES.size())
	livery_indices.shuffle()
	for route_index in range(routes.size()):
		var convoy: Node2D = TrainConvoyScene.instantiate()
		trains.add_child(convoy)
		convoy.configure_path(routes[route_index])
		if CampaignManager.is_challenge_active():
			var speed_scale := float(CampaignManager.challenge_value("speed", 1.0))
			convoy.cruise_speed *= speed_scale
			convoy.max_speed *= speed_scale
			convoy.current_speed = convoy.cruise_speed
			convoy.set_meta("reverse_locked", not bool(CampaignManager.challenge_value("reverse", true)))
		convoy.set_engine_livery(ENGINE_LIVERIES[livery_indices[route_index % livery_indices.size()]])
		convoys.append(convoy)

## The first train opens with one free basic car so a first-time player has
## something to watch fight immediately; every other starting train opens
## as a bare engine, matching the "engine only" second train a new player
## should feel free to specialize however they like. Combat itself waits
## for the player to press START WAVE (see menu.gd) rather than starting on
## a timer, so there is always a build phase to look around, pick a train,
## and buy or attach cars before the first spider spawns.
func _seed_tabletop() -> void:
	if convoys.is_empty():
		return
	var convoy: Node2D = convoys[0]
	for index in range(mini(starting_cars, BuildManager.towers.size() * 2)):
		var tower: TowerData = BuildManager.towers[index % BuildManager.towers.size()]
		if tower == null or tower.scene == null:
			continue
		var car: Node2D = tower.scene.instantiate()
		car.set_meta("tower_data", tower)
		trains.add_child(car)
		car.scale = NEW_BOARD_CAR_SCALE
		_apply_car_palette(car, _car_palette_cursor)
		_car_palette_cursor += 1
		convoy.attach_car(car)

func _on_train_drop_requested(tower_index: int, screen_position: Vector2) -> void:
	if not CampaignManager.challenge_shop_enabled():
		menu.show_placement_feedback("This job card forbids purchasing new cars.", false)
		return
	if tower_index < 0 or tower_index >= BuildManager.towers.size():
		menu.show_placement_feedback("That train is not configured.", false)
		return

	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var target_convoy: Node2D = _find_attachable_convoy(world_position)
	if target_convoy == null:
		menu.show_placement_feedback("Drop the car near an engine or its connected train.", false)
		return

	var tower: TowerData = BuildManager.towers[tower_index]
	if tower == null or tower.scene == null:
		menu.show_placement_feedback("That train is not configured.", false)
		return
	if not LevelManager.spend_currency(tower.cost):
		menu.show_placement_feedback("Not enough funds for %s." % tower.tower_name, false)
		return

	var car: Node2D = tower.scene.instantiate()
	car.set_meta("tower_data", tower)
	trains.add_child(car)
	car.scale = NEW_BOARD_CAR_SCALE
	_apply_car_palette(car, _car_palette_cursor)
	_car_palette_cursor += 1
	if not target_convoy.attach_car(car):
		LevelManager.increase_currency(tower.cost)
		car.queue_free()
		menu.show_placement_feedback("That train cannot take another car.", false)
		return
	menu.show_placement_feedback("%s connected to the train." % tower.tower_name, true)

func _unhandled_input(event: InputEvent) -> void:
	if upgrade_panel == null or upgrade_panel.visible or menu.dragging_tower >= 0 or menu.removing_mode:
		return
	if level_complete_overlay != null and level_complete_overlay.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		var clicked_convoy: TrainConvoy = _find_convoy_engine_near(world_position)
		if clicked_convoy:
			_select_convoy(clicked_convoy)
			get_viewport().set_input_as_handled()
			return
		var best_car: Node2D = null
		var best_convoy: Node2D = null
		var best_distance := 72.0
		for convoy in convoys:
			for car in convoy.followers:
				if not is_instance_valid(car) or not car.visible:
					continue
				var distance: float = car.global_position.distance_to(world_position)
				if distance < best_distance:
					best_distance = distance
					best_car = car
					best_convoy = convoy
		if best_car:
			var data = best_car.get_meta("tower_data", null)
			if data is TowerData:
				upgrade_panel.open_for(best_car, best_convoy, data)
				get_viewport().set_input_as_handled()
		else:
			_clear_train_selection()

func _find_convoy_engine_near(world_position: Vector2) -> TrainConvoy:
	var best: TrainConvoy
	var best_distance := 48.0
	for candidate in convoys:
		if not candidate is TrainConvoy:
			continue
		var distance := candidate.global_position.distance_to(world_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func _select_convoy(convoy: TrainConvoy) -> void:
	if selected_convoy == convoy:
		_clear_train_selection()
		return
	_clear_train_selection()
	selected_convoy = convoy
	selected_convoy.set_selected(true)
	train_control_panel.show_for(convoy, convoys.find(convoy) + 1)

func _clear_train_selection() -> void:
	if is_instance_valid(selected_convoy):
		selected_convoy.release_driver_controls()
		selected_convoy.set_selected(false)
	selected_convoy = null
	if train_control_panel:
		train_control_panel.clear()

func _on_train_control_changed(direction: int, throttle_notch: int) -> void:
	if is_instance_valid(selected_convoy):
		if selected_convoy.get_meta("reverse_locked", false) and (direction < 0 or throttle_notch == 0):
			menu.show_placement_feedback("NO BRAKES keeps the train moving forward.", false)
			direction = 1
			throttle_notch = maxi(throttle_notch, 1)
		selected_convoy.set_driver_controls(direction, throttle_notch)

func _on_upgrade_sell_requested(unit: Node2D, convoy: Node2D, refund: int) -> void:
	if not CampaignManager.challenge_train_edit_enabled():
		menu.show_placement_feedback("The supplied challenge train cannot be changed.", false)
		return
	if is_instance_valid(convoy) and convoy.remove_car(unit):
		LevelManager.increase_currency(refund)
		menu.show_placement_feedback("Unit sold for Δ%d." % refund, true)

func _on_remove_requested(screen_position: Vector2) -> void:
	if not CampaignManager.challenge_train_edit_enabled():
		menu.show_placement_feedback("The supplied challenge train cannot be changed.", false)
		return
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	for convoy in convoys:
		if convoy.remove_car_near(world_position):
			menu.show_placement_feedback("Car removed — the train reconnected around the gap.", true)
			return
	menu.show_placement_feedback("Click directly on a car to remove it.", false)

## Nearest train whose attachment radius covers world_position and which
## isn't capped by a Brake Van — can_attach_at() already returns false for a
## capped train, so a capped train simply never wins here.
func _find_attachable_convoy(world_position: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for convoy in convoys:
		if not is_instance_valid(convoy) or not convoy.can_attach_at(world_position):
			continue
		var distance: float = convoy.global_position.distance_to(world_position)
		if distance < best_distance:
			best_distance = distance
			best = convoy
	return best

const UNTINTED_CARS := ["Minigun", "Ballast", "CoalCannon", "BrakeVan", "PassengerCoach", "Tender"]

func _apply_car_palette(car: Node2D, palette_index: int) -> void:
	# These cars have strong authored identities of their own, so keep
	# their supplied colors intact — only the plain Gunner Car chassis
	# gets tinted per purchase.
	for excluded in UNTINTED_CARS:
		if car.name.contains(excluded):
			return
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
