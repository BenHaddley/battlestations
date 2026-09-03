extends Node2D
## Scene glue: generates several bounded railway routes and turns shop
## drag/drop requests into cars attached to whichever train the drop lands
## near.

const TrainConvoyScene := preload("res://scenes/TrainConvoy.tscn")
const GameOverOverlayScene := preload("res://scenes/ui/GameOverOverlay.tscn")
const SpiderAssaultControllerScript := preload("res://scripts/spider_assault_controller.gd")
const NEW_BOARD_CAR_SCALE := Vector2(0.54, 0.54)
const PlacementGhostScript := preload("res://scripts/car_placement_ghost.gd")

@onready var spawner: EnemySpawner = $EnemySpawner
@onready var track: TrackRenderer = $Track
@onready var trains: Node2D = $Trains
@onready var menu: Menu = $CanvasLayer/Menu

## One TrainConvoy instance per generated route, in generation order.
var convoys: Array[Node2D] = []
var track_routes: Array[PackedVector2Array] = []

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
var game_over_overlay: GameOverOverlay
var spider_assault_controller: SpiderAssaultController
var car_placement_ghost: Node2D

func _ready() -> void:
	Engine.time_scale = AppSettings.default_game_speed
	AchievementTracker.begin_run()
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
	menu.train_drag_updated.connect(_on_train_drag_updated)
	menu.train_drag_ended.connect(_hide_car_placement_ghost)
	menu.engine_drop_requested.connect(_on_engine_drop_requested)
	menu.remove_requested.connect(_on_remove_requested)
	_seed_tabletop()
	upgrade_panel = UnitUpgradePanel.new()
	$CanvasLayer.add_child(upgrade_panel)
	upgrade_panel.sell_requested.connect(_on_upgrade_sell_requested)
	level_complete_overlay = LevelCompleteOverlay.new()
	$CanvasLayer.add_child(level_complete_overlay)
	level_complete_overlay.continue_pressed.connect(CampaignManager.advance_to_next_level)
	CampaignManager.level_completed.connect(level_complete_overlay.show_for)
	game_over_overlay = GameOverOverlayScene.instantiate()
	$CanvasLayer.add_child(game_over_overlay)
	$Station.defeated.connect(_on_station_defeated)
	train_control_panel = TrainControlPanel.new()
	$CanvasLayer.add_child(train_control_panel)
	train_control_panel.anchor_left = 0.5
	train_control_panel.anchor_right = 0.5
	train_control_panel.anchor_top = 0.0
	train_control_panel.anchor_bottom = 0.0
	train_control_panel.offset_left = -146.0
	train_control_panel.offset_right = 146.0
	train_control_panel.offset_top = 6.0
	train_control_panel.offset_bottom = 44.0
	train_control_panel.control_changed.connect(_on_train_control_changed)
	train_control_panel.deselect_requested.connect(_clear_train_selection)
	if CampaignManager.is_spider_assault():
		spider_assault_controller = SpiderAssaultControllerScript.new()
		spider_assault_controller.name = "SpiderAssaultController"
		$CanvasLayer.add_child(spider_assault_controller)
		spider_assault_controller.configure(self, spawner, $Station, convoys)
	car_placement_ghost = PlacementGhostScript.new()
	car_placement_ghost.name = "CarPlacementGhost"
	car_placement_ghost.visible = false
	add_child(car_placement_ghost)

## Regenerates the railway until it passes validation (every lane reachable,
## every route internally connected, at least two usable routes) or the
## attempt budget runs out — see track_renderer.gd's module placement and
## covers_lanes()/routes_are_traversable(). Falling back to whatever the
## last attempt produced beats a hard failure; the push_error still makes a
## bad board loudly visible in testing rather than silently shipping one.
func _generate_and_spawn_trains() -> void:
	var routes: Array[PackedVector2Array] = []
	var level := CampaignManager.current_level()
	var special_track := String(CampaignManager.challenge_value("special_track", ""))
	var uses_campaign_track := level != null and level.track_layout_index >= 0
	if special_track == "bottom_figure_eight":
		routes = track.generate_bottom_figure_eight()
	elif uses_campaign_track:
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
	track_routes = routes
	for child in trains.get_children():
		child.queue_free()
	convoys = []
	var livery_indices := range(ENGINE_LIVERIES.size())
	livery_indices.shuffle()
	var initial_engine_count := mini(starting_trains, routes.size()) if CampaignManager.is_challenge_active() else mini(1, routes.size())
	# Boiler Room's second authored loop is the station-side/bottom rail. Starting
	# there gives a new player time to learn before spiders cross the whole board.
	# Other missions and multi-train challenges retain their authored route order.
	var first_route_index := 1 if not CampaignManager.is_challenge_active() and CampaignManager.current_level_index == 0 and routes.size() > 1 else 0
	for engine_slot in range(initial_engine_count):
		var route_index := first_route_index if initial_engine_count == 1 else engine_slot
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
		if CampaignManager.is_spider_assault():
			_install_assault_blocker(convoy, 36.0)
		convoys.append(convoy)

func _process(delta: float) -> void:
	if menu.dragging_tower >= 0:
		_on_train_drag_updated(menu.dragging_tower, get_viewport().get_mouse_position(), menu.drag_facing)
	var forward_held := Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var reverse_held := Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)
	var axis := int(forward_held) - int(reverse_held)
	if is_instance_valid(selected_convoy):
		_apply_keyboard_axis(selected_convoy, axis, delta)
	else:
		# Keyboard driving should work immediately without making the player
		# find and click a small moving locomotive first. With no explicit
		# selection, the command is shared by every player train.
		for convoy_node in convoys:
			var convoy := convoy_node as TrainConvoy
			if is_instance_valid(convoy):
				_apply_keyboard_axis(convoy, axis, delta)

func _apply_keyboard_axis(convoy: TrainConvoy, axis: int, delta: float) -> void:
	if convoy.get_meta("reverse_locked", false) and axis < 0:
		axis = 0
	convoy.set_manual_axis(axis, delta)

func _on_train_drag_updated(tower_index: int, screen_position: Vector2, facing: int) -> void:
	if car_placement_ghost == null or tower_index < 0 or tower_index >= BuildManager.towers.size():
		return
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var convoy: TrainConvoy = _find_attachable_convoy(world_position)
	if convoy == null:
		_hide_car_placement_ghost()
		menu.set_drag_preview_snapped(false)
		return
	var preview := convoy.next_car_preview_transform()
	if preview.is_empty():
		_hide_car_placement_ghost()
		menu.set_drag_preview_snapped(false)
		return
	var tower: TowerData = BuildManager.towers[tower_index]
	car_placement_ghost.configure(tower.icon, preview.position, preview.direction, facing, tower_index == 0 or tower_index == 1)
	car_placement_ghost.visible = true
	menu.set_drag_preview_snapped(true)

func _hide_car_placement_ghost() -> void:
	if car_placement_ghost:
		car_placement_ghost.visible = false

func _on_engine_drop_requested(screen_position: Vector2) -> void:
	if not CampaignManager.challenge_shop_enabled():
		menu.show_placement_feedback("This job card forbids purchasing engines.", false)
		return
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var placement := _nearest_free_rail_placement(world_position)
	if placement.is_empty():
		menu.show_placement_feedback("Place the locomotive on an empty stretch of rail.", false)
		return
	if not LevelManager.spend_currency(Menu.ENGINE_COST):
		menu.show_placement_feedback("Not enough funds for a locomotive.", false)
		return
	var convoy: TrainConvoy = TrainConvoyScene.instantiate()
	trains.add_child(convoy)
	convoy.configure_path(track_routes[int(placement.route)])
	convoy.set_engine_livery(ENGINE_LIVERIES[convoys.size() % ENGINE_LIVERIES.size()])
	if not convoy.place_at_route_distance(float(placement.distance)):
		LevelManager.increase_currency(Menu.ENGINE_COST)
		convoy.queue_free()
		menu.show_placement_feedback("That rail cannot hold a locomotive here.", false)
		return
	convoys.append(convoy)
	AudioFX.play_cue(&"purchase")
	menu.trains = convoys
	menu.train_drag_started.connect(convoy.set_drag_active.bind(true))
	menu.train_drag_ended.connect(convoy.set_drag_active.bind(false))
	_select_convoy(convoy)
	menu.show_placement_feedback("Engine %d added to the railway." % convoys.size(), true)

func _nearest_free_rail_placement(world_position: Vector2) -> Dictionary:
	var best := {}
	var best_distance := 44.0
	for route_index in range(track_routes.size()):
		var route := track_routes[route_index]
		var along := 0.0
		for point_index in range(route.size()):
			var start := route[point_index]
			var finish := route[(point_index + 1) % route.size()]
			var segment := finish - start
			var weight := clampf((world_position - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
			var candidate := start + segment * weight
			var pointer_distance := candidate.distance_to(world_position)
			if pointer_distance < best_distance and _engine_space_is_free(candidate):
				best_distance = pointer_distance
				best = {"route": route_index, "distance": along + segment.length() * weight}
			along += segment.length()
	return best

func _engine_space_is_free(candidate: Vector2) -> bool:
	for convoy in convoys:
		if convoy.global_position.distance_to(candidate) < convoy.occupancy_distance * 1.35:
			return false
		for car in convoy.followers:
			if is_instance_valid(car) and car.global_position.distance_to(candidate) < convoy.occupancy_distance * 1.35:
				return false
	return true

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
	if CampaignManager.is_spider_assault():
		_seed_spider_assault_defense()
		return
	var convoy: Node2D = convoys[0]
	for index in range(mini(starting_cars, BuildManager.towers.size() * 2)):
		var tower: TowerData = BuildManager.towers[index % BuildManager.towers.size()]
		if tower == null or tower.scene == null:
			continue
		var car: Node2D = tower.scene.instantiate()
		DiscoveryTracker.discover("tower:%s" % tower.tower_name.to_snake_case())
		car.set_meta("tower_data", tower)
		trains.add_child(car)
		car.scale = NEW_BOARD_CAR_SCALE
		_apply_car_palette(car, _car_palette_cursor)
		_car_palette_cursor += 1
		convoy.attach_car(car)

func _seed_spider_assault_defense() -> void:
	var defense_roster := [0, 1, 2, 4, 0, 1]
	for defense_index in range(defense_roster.size()):
		var tower_index: int = defense_roster[defense_index]
		if tower_index >= BuildManager.towers.size():
			continue
		var tower: TowerData = BuildManager.towers[tower_index]
		if tower == null or tower.scene == null:
			continue
		var car: Node2D = tower.scene.instantiate()
		DiscoveryTracker.discover("tower:%s" % tower.tower_name.to_snake_case())
		car.set_meta("tower_data", tower)
		trains.add_child(car)
		car.scale = NEW_BOARD_CAR_SCALE
		_apply_car_palette(car, defense_index)
		# Four cars guard the first circuit; only two guard the second. Finding and
		# exploiting that weaker route is the scenario's first tactical puzzle.
		var convoy_index := 0 if defense_index < 4 else 1
		var convoy: TrainConvoy = convoys[mini(convoy_index, convoys.size() - 1)]
		if not convoy.attach_car(car):
			car.queue_free()
		else:
			_install_assault_blocker(car, 68.0)

func _install_assault_blocker(host: Node2D, local_radius: float) -> void:
	# Trains and their turret cars are repositioned every physics tick. An
	# AnimatableBody2D keeps its collision transform synchronised with that
	# movement; StaticBody2D is for immobile scenery and let fast-moving train
	# art visibly pass through lane-bound spiders between physics updates.
	var body := AnimatableBody2D.new()
	body.name = "SpiderBlocker"
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = local_radius
	collision.shape = shape
	body.add_child(collision)
	host.add_child(body)

func _on_train_drop_requested(tower_index: int, screen_position: Vector2, facing: int = 1) -> void:
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
	DiscoveryTracker.discover("tower:%s" % tower.tower_name.to_snake_case())
	car.set_meta("tower_data", tower)
	trains.add_child(car)
	if car.has_method("set_fixed_facing"):
		car.set_fixed_facing(facing)
	car.scale = NEW_BOARD_CAR_SCALE
	_apply_car_palette(car, _car_palette_cursor)
	_car_palette_cursor += 1
	if not target_convoy.attach_car(car):
		LevelManager.increase_currency(tower.cost)
		car.queue_free()
		menu.show_placement_feedback("That train cannot take another car.", false)
		return
	AudioFX.play_cue(&"purchase")
	menu.show_placement_feedback("%s connected to the train." % tower.tower_name, true)

func _on_station_defeated() -> void:
	if CampaignManager.is_spider_assault():
		return
	if game_over_overlay == null or game_over_overlay.visible:
		return
	PhaseManager.paused = true
	$MusicPlayer.stream_paused = true
	game_over_overlay.show_failure(CampaignManager.is_challenge_active())

func trigger_failure() -> void:
	if game_over_overlay == null or game_over_overlay.visible:
		return
	PhaseManager.paused = true
	$MusicPlayer.stream_paused = true
	game_over_overlay.show_failure(CampaignManager.is_challenge_active())

func _unhandled_input(event: InputEvent) -> void:
	if CampaignManager.is_spider_assault():
		return
	if game_over_overlay != null and game_over_overlay.visible:
		return
	if upgrade_panel == null or upgrade_panel.visible or menu.dragging_tower >= 0 or menu.removing_mode:
		return
	if level_complete_overlay != null and level_complete_overlay.visible:
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		var target_wave := 10
		if spawner.debug_select_next_wave(target_wave) and spawner.can_start_next_wave():
			spawner.start_next_wave()
			menu.show_placement_feedback("DEBUG: started wave %d." % target_wave, true)
		get_viewport().set_input_as_handled()
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
