extends Node2D
## Scene glue: generates several bounded railway routes and turns shop
## drag/drop requests into cars attached to whichever train the drop lands
## near.

const TrainConvoyScene := preload("res://scenes/TrainConvoy.tscn")
const GameOverOverlayScene := preload("res://scenes/ui/GameOverOverlay.tscn")
const SpiderAssaultControllerScript := preload("res://scripts/spider_assault_controller.gd")
const NEW_BOARD_CAR_SCALE := Vector2(0.54, 0.54)
const PlacementGhostScript := preload("res://scripts/car_placement_ghost.gd")
const RailBuilderScript := preload("res://scripts/rail_builder.gd")
const RangePreviewScript := preload("res://scripts/range_preview.gd")

@onready var spawner: EnemySpawner = $EnemySpawner
@onready var track: TrackRenderer = $Track
@onready var trains: Node2D = $Trains
@onready var menu: Menu = $CanvasLayer/Menu

## One TrainConvoy instance per generated route, in generation order.
var convoys: Array[Node2D] = []
## The live railway rings. TrackRenderer owns them because STATIONS rail
## building can revise a ring after the level starts.
var track_routes: Array[PackedVector2Array]:
	get:
		return track.routes
## Convoys whose route was revised while their consist straddled track the
## new ring no longer covers; retried every frame until the rebind is safe.
var pending_rebinds: Dictionary = {}
var rail_builder: RailBuilder
var range_preview: RangePreview
var _motion_probe_elapsed := 0.0
var _motion_probe_frames := 0
var _motion_probe_origin := Vector2.ZERO
var _motion_probe_done := false

@export_range(2, 4) var starting_trains: int = 2
@export_range(0, 6) var starting_cars: int = 1
@export_range(1, 8) var max_generation_attempts: int = 6

## Updated artist-supplied engine liveries. Car colors remain unchanged.
const ENGINE_LIVERIES: Array[Texture2D] = [
	preload("res://assets/sprites/engines/revised/001_Blue.png"),
	preload("res://assets/sprites/engines/revised/002_Red.png"),
	preload("res://assets/sprites/engines/revised/003_Green.png"),
	preload("res://assets/sprites/engines/revised/004_Yellow.png"),
	preload("res://assets/sprites/engines/revised/005_Orange.png"),
	preload("res://assets/sprites/engines/revised/006_Purple.png"),
	preload("res://assets/sprites/engines/revised/007_Pink.png"),
	preload("res://assets/sprites/engines/revised/008_Navy.png"),
	preload("res://assets/sprites/engines/revised/009_Rose.png"),
	preload("res://assets/sprites/engines/revised/010_Forest.png"),
	preload("res://assets/sprites/engines/revised/011_Monochrome.png"),
	preload("res://assets/sprites/engines/revised/012_Teal.png"),
	preload("res://assets/sprites/engines/revised/013_Viridian.png"),
	preload("res://assets/sprites/engines/revised/014_Maroon.png"),
	preload("res://assets/sprites/engines/revised/015_Blorange.png"),
	preload("res://assets/sprites/engines/revised/016_Bumblebee.png"),
	preload("res://assets/sprites/engines/revised/017_Diet.png"),
	preload("res://assets/sprites/engines/revised/018_Lavender.png"),
	preload("res://assets/sprites/engines/revised/019_Surge.png"),
	preload("res://assets/sprites/engines/revised/020_Cherry Blossom.png"),
	preload("res://assets/sprites/engines/revised/021_Baby Blue.png"),
	preload("res://assets/sprites/engines/revised/022_Brick.png"),
	preload("res://assets/sprites/engines/revised/023_High Contrast.png"),
	preload("res://assets/sprites/engines/revised/024_Blue Coat.png"),
	preload("res://assets/sprites/engines/revised/025_Red Coat.png"),
	preload("res://assets/sprites/engines/revised/026_Green Coat.png"),
	preload("res://assets/sprites/engines/revised/027_Yellow Coat.png"),
	preload("res://assets/sprites/engines/revised/028_Purple Coat.png"),
	preload("res://assets/sprites/engines/revised/029_Orange Coat.png"),
	preload("res://assets/sprites/engines/revised/030_Ivory.png"),
	preload("res://assets/sprites/engines/revised/031_Khaki.png"),
	preload("res://assets/sprites/engines/revised/032_Midnight.png"),
	preload("res://assets/sprites/engines/revised/033_Burgundy.png"),
	preload("res://assets/sprites/engines/revised/034_Moss.png"),
	preload("res://assets/sprites/engines/revised/035_Coffee.png"),
	preload("res://assets/sprites/engines/revised/036_Neopolitan.png"),
	preload("res://assets/sprites/engines/revised/037_Mint Chip.png"),
	preload("res://assets/sprites/engines/revised/038_Candy Corn.png"),
	preload("res://assets/sprites/engines/revised/039_Blueberry.png"),
	preload("res://assets/sprites/engines/revised/040_Strawberry.png"),
	preload("res://assets/sprites/engines/revised/041_Sour Apple.png"),
	preload("res://assets/sprites/engines/revised/042_Lemon.png"),
	preload("res://assets/sprites/engines/revised/043_Tangerine.png"),
	preload("res://assets/sprites/engines/revised/044_Grape.png"),
	preload("res://assets/sprites/engines/revised/045_True Blue.png"),
	preload("res://assets/sprites/engines/revised/046_True Red.png"),
	preload("res://assets/sprites/engines/revised/047_True Green.png"),
	preload("res://assets/sprites/engines/revised/048_True Yellow.png"),
	preload("res://assets/sprites/engines/revised/049_True Purple.png"),
	preload("res://assets/sprites/engines/revised/050_True Orange.png"),
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
	for convoy in convoys:
		convoy.configure_network(track)
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
	train_control_panel.offset_left = -200.0
	train_control_panel.offset_right = 200.0
	train_control_panel.offset_top = 4.0
	train_control_panel.offset_bottom = 48.0
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
	rail_builder = RailBuilderScript.new()
	rail_builder.name = "RailBuilder"
	add_child(rail_builder)
	rail_builder.configure(self, track, menu)
	rail_builder.rail_built.connect(func(_cell: Vector2i, _route: int) -> void: _record_track_discoveries.call_deferred())
	track.route_changed.connect(_on_route_changed)
	range_preview = RangePreviewScript.new()
	range_preview.name = "RangePreview"
	add_child(range_preview)
	# One console line per level so a browser smoke test can confirm the
	# starting railway and train exist without a screenshot.
	var starter_cars := 0
	for convoy in convoys:
		starter_cars += int(convoy.car_count())
	_record_track_discoveries()
	print("LEVEL READY: %s | %d routes | %d trains | %d cars | %d rail cells" % [level.level_name if level else "?", track.routes.size(), convoys.size(), starter_cars, track.graph.size()])

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
		track.routes = routes
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
		convoy.route_index = route_index
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
		DiscoveryTracker.discover("engine:steam")

func _process(delta: float) -> void:
	_report_train_motion(delta)
	if menu.dragging_tower >= 0:
		_on_train_drag_updated(menu.dragging_tower, get_viewport().get_mouse_position(), menu.drag_facing)
	var axis := 0
	if train_driving_enabled():
		var forward_held := Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
		var reverse_held := Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)
		axis = int(forward_held) - int(reverse_held)
	for convoy_node in convoys:
		var convoy := convoy_node as TrainConvoy
		if is_instance_valid(convoy):
			convoy.set_building_hidden(menu.building_track)
			_apply_keyboard_axis(convoy, axis if convoy == selected_convoy and not menu.building_track else 0, delta)
	_retry_pending_rebinds()
	_refresh_range_preview()

## The attack radius is shown for the car under the pointer and for the car
## whose information card is open; utility cars draw nothing.
func _refresh_range_preview() -> void:
	if range_preview == null:
		return
	if upgrade_panel != null and upgrade_panel.visible and is_instance_valid(upgrade_panel.unit):
		range_preview.follow(upgrade_panel.unit)
		return
	if not board_interaction_enabled():
		range_preview.follow(null)
		return
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
	range_preview.follow(car_near(world_position, 44.0))

func car_near(world_position: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var best_distance := radius
	for convoy_node in convoys:
		var convoy := convoy_node as TrainConvoy
		if not is_instance_valid(convoy):
			continue
		for car in convoy.followers:
			if not is_instance_valid(car) or not car.visible:
				continue
			var distance: float = car.global_position.distance_to(world_position)
			if distance < best_distance:
				best_distance = distance
				best = car
	return best

## A revised ring reaches each convoy only once its whole consist sits on
## track both rings share; until then the train keeps its old geometry.
func _on_route_changed(route_index: int, path: PackedVector2Array) -> void:
	_record_track_discoveries.call_deferred()
	for convoy_node in convoys:
		var convoy := convoy_node as TrainConvoy
		if not is_instance_valid(convoy) or convoy.route_index != route_index:
			continue
		if convoy.rebind_route(path):
			pending_rebinds.erase(convoy)
		else:
			pending_rebinds[convoy] = path

func _retry_pending_rebinds() -> void:
	if pending_rebinds.is_empty():
		return
	for convoy in pending_rebinds.keys():
		if not is_instance_valid(convoy):
			pending_rebinds.erase(convoy)
			continue
		var latest: PackedVector2Array = track.routes[convoy.route_index] if convoy.route_index >= 0 and convoy.route_index < track.routes.size() else pending_rebinds[convoy]
		if convoy.rebind_route(latest):
			pending_rebinds.erase(convoy)

## The board is interactive for rail building and unit selection only while
## no card is open and no shop gesture is in progress.
func board_interaction_enabled() -> bool:
	return train_driving_enabled() and menu.dragging_tower == -1 and not menu.removing_mode

func rail_cell_occupied(cell: Vector2i) -> bool:
	var point := track.world_of(cell)
	for convoy_node in convoys:
		var convoy := convoy_node as TrainConvoy
		if not is_instance_valid(convoy): continue
		if convoy.occupies_point(point, track.path_step * 0.7): return true
		if convoy.navigator:
			var at := convoy.navigator.distance - convoy.followers.size() * convoy.car_spacing
			while at <= convoy.navigator.distance:
				if Vector2(convoy.navigator.sample(at).position).distance_to(point) < track.path_step * 0.5: return true
				at += track.path_step * 0.25
	return false

func _apply_keyboard_axis(convoy: TrainConvoy, axis: int, delta: float) -> void:
	if convoy.get_meta("reverse_locked", false) and axis < 0:
		axis = 0
	convoy.set_manual_axis(axis, delta)

## One console line, once per level, saying how far the starting train
## actually travelled. A consist that decides it is blocked reports zero, so
## the browser smoke test can catch a frozen train in the exported build —
## the editor and headless suite both missed exactly that once already.
func _report_train_motion(delta: float) -> void:
	if _motion_probe_done or convoys.is_empty() or PhaseManager.is_station():
		return
	var convoy := convoys[0] as TrainConvoy
	if not is_instance_valid(convoy):
		_motion_probe_done = true
		return
	if _motion_probe_frames == 0:
		_motion_probe_origin = convoy.global_position
	_motion_probe_elapsed += delta
	_motion_probe_frames += 1
	# Frame count as well as elapsed time: a headless browser running on a
	# virtual clock can deliver many frames with negligible delta, and the
	# report must still arrive rather than waiting forever for two seconds.
	if _motion_probe_elapsed < 2.0 and _motion_probe_frames < 150:
		return
	_motion_probe_done = true
	print("TRAIN MOTION: %.1f units over %d frames / %.2fs, blocked=%s" % [convoy.global_position.distance_to(_motion_probe_origin), _motion_probe_frames, _motion_probe_elapsed, convoy.movement_blocked])

## Directional keys drive trains only while the board itself is the active
## surface. Every full-screen card (pause, car information, level complete, game
## over, Duck and Daisy) keeps ordinary keyboard navigation instead.
func train_driving_enabled() -> bool:
	if get_tree().paused or CampaignManager.is_spider_assault():
		return false
	if game_over_overlay != null and game_over_overlay.visible:
		return false
	if upgrade_panel != null and upgrade_panel.visible:
		return false
	if level_complete_overlay != null and level_complete_overlay.visible:
		return false
	if menu.pause_menu != null and menu.pause_menu.visible:
		return false
	var director := get_node_or_null("TutorialDirector") as TutorialDirector
	if director != null and director.overlay != null and director.overlay.visible and not director.overlay.waiting_for_action:
		return false
	return true

## Runs before any Control sees the event. While the board is live, the
## arrow keys are train controls and must not also move interface focus.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not train_driving_enabled():
		return
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action(action):
			get_viewport().gui_release_focus()
			get_viewport().set_input_as_handled()
			return

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
	car_placement_ghost.configure(CarArt.for_tower(tower), preview.position, preview.direction, facing, false)
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
	var wreck := _find_wreck_near(world_position)
	if wreck != null:
		if not LevelManager.spend_currency(Menu.ENGINE_COST):
			menu.show_placement_feedback("Not enough funds for a locomotive.", false)
			return
		wreck.recover_engine()
		AudioFX.play_cue(&"purchase")
		menu.show_placement_feedback("Locomotive recovered — the train is back in service.", true)
		return
	var placement := _nearest_free_rail_placement(world_position)
	if placement.is_empty():
		menu.show_placement_feedback("Place the locomotive on an empty stretch of rail.", false)
		return
	if not LevelManager.spend_currency(Menu.ENGINE_COST):
		menu.show_placement_feedback("Not enough funds for a locomotive.", false)
		return
	var convoy: TrainConvoy = TrainConvoyScene.instantiate()
	trains.add_child(convoy)
	convoy.configure_path(PackedVector2Array([placement.start, placement.finish]))
	convoy.route_index = track.route_index_of(track.cell_of(placement.start))
	convoy.navigator = RailNavigator.new()
	convoy.navigator.setup_edge(track, placement.start, placement.finish, placement.position)
	convoy.route_distance = convoy.navigator.distance
	convoy._apply_consist_positions()
	convoy.set_engine_livery(ENGINE_LIVERIES[convoys.size() % ENGINE_LIVERIES.size()])
	convoys.append(convoy)
	DiscoveryTracker.discover("engine:steam")
	AudioFX.play_cue(&"purchase")
	menu.trains = convoys
	menu.train_drag_started.connect(convoy.set_drag_active.bind(true))
	menu.train_drag_ended.connect(convoy.set_drag_active.bind(false))
	_select_convoy(convoy)
	menu.show_placement_feedback("Engine %d added to the railway." % convoys.size(), true)

func _nearest_free_rail_placement(world_position: Vector2) -> Dictionary:
	var best := {}
	var best_distance := 44.0
	for cell in track.graph:
		for neighbor in track.graph[cell]:
			var start: Vector2 = track.world_of(cell)
			var finish: Vector2 = track.world_of(neighbor)
			var candidate := Geometry2D.get_closest_point_to_segment(world_position, start, finish)
			var gap := candidate.distance_to(world_position)
			if gap < best_distance and _engine_space_is_free(candidate):
				best_distance = gap
				best = {"start": start, "finish": finish, "position": candidate, "route": track.route_index_of(cell), "distance": start.distance_to(candidate)}
	return best

func _find_wreck_near(world_position: Vector2) -> TrainConvoy:
	for convoy_node in convoys:
		var convoy := convoy_node as TrainConvoy
		if is_instance_valid(convoy) and convoy.wrecked and convoy.global_position.distance_to(world_position) <= 64.0:
			return convoy
	return null

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
		if convoy.attach_car(car):
			_register_car(car, tower)
		else:
			car.queue_free()

## Every coupled car is an obstacle spiders steer round or bite, with the
## workbook hit points for its type; losing it closes the gap in the train.
func _register_car(car: Node2D, tower: TowerData) -> void:
	car.add_to_group("train_units")
	var health := UnitHealth.attach_to(car, float(tower.health), tower.tower_name)
	if not health.destroyed.is_connected(_on_car_destroyed):
		health.destroyed.connect(_on_car_destroyed)

func _on_car_destroyed(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	if upgrade_panel and upgrade_panel.unit == unit:
		upgrade_panel.close_panel()
	for convoy_node in convoys:
		var convoy := convoy_node as TrainConvoy
		if is_instance_valid(convoy) and convoy.followers.has(unit):
			var data = unit.get_meta("tower_data", null)
			var label: String = data.tower_name if data is TowerData else "Car"
			convoy.remove_car(unit)
			menu.show_placement_feedback("%s destroyed — the train closed the gap." % label, false)
			GameEvents.train_unit_destroyed.emit(label)
			return

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
			_register_car(car, tower)
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
	_register_car(car, tower)
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
	selected_convoy.set_selected(true, convoys.find(convoy) + 1)
	track.set_route_focus(selected_convoy.route_index)
	train_control_panel.show_for(convoy, convoys.find(convoy) + 1)

func _clear_train_selection() -> void:
	if is_instance_valid(selected_convoy):
		selected_convoy.release_driver_controls()
		selected_convoy.set_selected(false)
	selected_convoy = null
	track.set_route_focus(-1)
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

func _apply_car_palette(car: Node2D, _palette_index: int) -> void:
	for name in ["Base", "Sprite2D", "RotationPoint/Top"]:
		var sprite := car.get_node_or_null(name) as Sprite2D
		if sprite:
			sprite.modulate = Color.WHITE

func _record_track_discoveries() -> void:
	for tile in track.get_children():
		if not tile.is_queued_for_deletion() and tile.has_meta("piece"):
			DiscoveryTracker.discover("track:" + String(tile.get_meta("piece")))
