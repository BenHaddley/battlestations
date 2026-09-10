extends Node2D
class_name TrainConvoy
## A locomotive and its attached cars sample their actual travelled rail path.
## Open networks use RailNavigator; closed paths remain available for fixtures.
##
## Weight follows the infowiki Steam Engine card (#001): a hard
## carry_capacity budget (1000 units by default), not a soft speed penalty.
## A car that would push the train over capacity simply can't be attached
## (attach_car returns false) — every attached train always runs at full
## speed. A Tender coupled directly behind the engine (followers[0]) adds
## its card's +500 capacity bonus; anywhere else in the train it's just
## another 50-weight car with no effect. A Brake Van caps the train (no
## further cars can attach), grants every other car its attack-speed bonus,
## and — per its card's third paragraph — trims accel/coast time.

@export_group("Movement")
@export var balance: GameBalance = preload("res://resources/game_balance.tres")
@export var cruise_speed: float = 46.0
@export var max_speed: float = 82.0
@export var minimum_speed: float = 14.0
@export var acceleration: float = 28.0
@export var deceleration: float = 34.0
@export var reverse_acceleration: float = 28.0
@export var occupancy_distance: float = 64.0
@export var occupancy_debug: bool = false

@export_group("Capacity")
@export var carry_capacity: float = 1000.0 ## Steam Engine card: "Carry Capacity of 1000 Units of Weight."
@export var tender_capacity_bonus: float = 500.0 ## Tender card: +500 if coupled directly behind the engine.
## Cars render at roughly 112.5 world units. This leaves a visible coupling gap
## on straights and enough clearance while two cars straddle a square corner.
@export var car_spacing: float = 94.0
@export var attachment_radius: float = 76.0
@export var smoke_texture: Texture2D

@onready var engine: Sprite2D = $Engine

## Normalize visible engine artwork to the same one-tile car footprint.
const ENGINE_TOKEN_SIZE := 56.0

var navigator: RailNavigator
var building_hidden := false
var buffer_pause := 0.0
var impact_stop := 0.0

var path: PackedVector2Array
var path_index: int = 0
var followers: Array[Node2D] = []
var segment_starts: PackedFloat32Array = PackedFloat32Array()
var route_length := 0.0
var route_distance := 0.0
## Index into TrackRenderer.routes this train drives, so a rail edit that
## revises that route can find every convoy it has to rebind.
var route_index: int = -1
var smoke_timer: float = 0.0
var current_speed: float = 0.0 ## Signed. Positive is route-forward, negative reverse.
var requested_direction: int = 0 ## Reverser: -1 REV, 0 N, +1 FWD.
var throttle_notch: int = 1 ## 0 BRAKE, 1 COAST, 2–5 increasing manual power.
var cruise_direction: int = 1
var capped: bool = false
var drag_active: bool = false
var selected: bool = false
var movement_blocked: bool = false
var _brake_time_multiplier: float = 1.0
var manual_axis: int = 0
var manual_hold_time: float = 0.0
const REVERSE_HOLD_SECONDS := 1.15
## Units within this distance of a spider's centre are in contact with it.
const IMPACT_RADIUS := 48.0

var unit_health: UnitHealth
## A wrecked engine stays on the rails as rubble: its cars keep fighting
## where they stand, but nothing moves until a new locomotive is dropped on
## the wreck to recover the train.
var wrecked: bool = false
var impact_damage: int = 20
var impact_cooldown_seconds: float = 2.0
var impact_minimum_speed_fraction: float = 0.6
var impact_recoil_distance: float = 8.0
var impact_speed_retained: float = 0.35
var impacts_landed: int = 0

func _ready() -> void:
	add_to_group("train_units")
	var engine_hit_points := 300.0 if balance == null else float(balance.engine_health)
	unit_health = UnitHealth.attach_to(self, engine_hit_points, "ENGINE")
	unit_health.destroyed.connect(_on_engine_destroyed)
	if balance == null:
		return
	impact_damage = balance.impact_damage
	impact_cooldown_seconds = balance.impact_cooldown_seconds
	impact_minimum_speed_fraction = balance.impact_minimum_speed_fraction
	impact_recoil_distance = balance.impact_recoil_distance
	impact_speed_retained = balance.impact_speed_retained
	cruise_speed = balance.cruise_speed
	max_speed = balance.maximum_speed
	minimum_speed = balance.minimum_speed
	acceleration = balance.acceleration
	deceleration = balance.deceleration
	reverse_acceleration = balance.reverse_acceleration
	carry_capacity = balance.carry_capacity
	tender_capacity_bonus = balance.tender_capacity_bonus
	car_spacing = balance.car_spacing
	occupancy_distance = balance.minimum_consist_clearance
	attachment_radius = balance.attachment_radius

func set_engine_livery(texture: Texture2D) -> void:
	if texture:
		engine.texture = texture
		engine.modulate = Color.WHITE
		var source_size := Vector2(texture.get_image().get_used_rect().size)
		var source_extent := maxf(source_size.x, source_size.y)
		if source_extent > 0.0:
			var normalized_scale := ENGINE_TOKEN_SIZE / source_extent
			engine.scale = Vector2(normalized_scale, normalized_scale)

func configure_path(track_path: PackedVector2Array) -> void:
	path = track_path.duplicate()
	if path.size() < 2:
		return
	_build_route_metrics()
	path_index = 0
	route_distance = 0.0
	current_speed = cruise_speed
	_apply_consist_positions()

func configure_network(renderer: TrackRenderer) -> void:
	navigator = RailNavigator.new()
	navigator.setup(renderer, path, route_distance, followers.size() * car_spacing)
	route_distance = navigator.distance

func force_stop() -> void:
	current_speed = 0.0
	impact_stop = 0.15

func set_building_hidden(hidden: bool) -> void:
	building_hidden = hidden
	visible = not hidden
	for car in followers:
		if is_instance_valid(car): car.visible = not hidden
	if hidden:
		current_speed = 0.0
		release_driver_controls()

func _grabbed() -> bool:
	for spider in get_tree().get_nodes_in_group("spiders"):
		if spider.is_queued_for_deletion(): continue
		var victim = spider.get("biting_target")
		if is_instance_valid(victim) and (victim == self or victim in followers): return true
	return false

func _process(delta: float) -> void:
	if path.size() < 2:
		return
	if wrecked or building_hidden or _grabbed():
		current_speed = 0.0
		queue_redraw()
		return
	_update_speed(delta)
	_advance_safely(current_speed * delta)
	_apply_impacts()
	smoke_timer -= delta
	if smoke_timer <= 0.0 and absf(current_speed) > 2.0:
		_emit_smoke()
		smoke_timer = 0.32
	queue_redraw()

## Ramming is incidental: a unit moving at a real pace deals one Gunner
## bullet's worth to each spider it overlaps, then the train recoils a
## little. The per-spider cooldown lives on the spider, so parking on one
## never turns into a damage engine.
func _apply_impacts() -> void:
	if absf(current_speed) < cruise_speed * impact_minimum_speed_fraction:
		return
	var units: Array[Node2D] = [self]
	for car in followers:
		if is_instance_valid(car) and car.visible:
			units.append(car)
	var struck := false
	for spider in get_tree().get_nodes_in_group("spiders"):
		var body := spider as Node2D
		if body == null or not body.has_method("take_impact"):
			continue
		for unit in units:
			if unit.global_position.distance_to(body.global_position) <= IMPACT_RADIUS:
				if body.take_impact(unit, impact_damage, impact_cooldown_seconds):
					struck = true
					impacts_landed += 1
				break
	if struck:
		_recoil()

func _recoil() -> void:
	var direction := signf(current_speed) if not is_zero_approx(current_speed) else float(cruise_direction)
	current_speed *= impact_speed_retained
	_advance_safely(-impact_recoil_distance * direction)
	# The jolt is drawn, not simulated: cars stay on their route samples.
	var rest := engine.position
	var tween := create_tween()
	tween.tween_property(engine, "position", rest + Vector2(0.0, 5.0).rotated(engine.rotation), 0.05)
	tween.tween_property(engine, "position", rest, 0.12)

func _on_engine_destroyed(_unit: Node2D) -> void:
	wrecked = true
	current_speed = 0.0
	release_driver_controls()
	engine.modulate = Color(0.32, 0.28, 0.26, 1.0)
	GameEvents.engine_wrecked.emit(self)
	queue_redraw()

## A new locomotive dropped on the wreck puts the train back into service
## with full engine health; the surviving cars are exactly where they were.
func recover_engine() -> void:
	wrecked = false
	engine.modulate = Color.WHITE
	unit_health.repair_fully()
	current_speed = cruise_speed * cruise_direction
	queue_redraw()

func _update_speed(delta: float) -> void:
	if buffer_pause > 0.0 or impact_stop > 0.0:
		buffer_pause = maxf(0.0, buffer_pause - delta)
		impact_stop = maxf(0.0, impact_stop - delta)
		current_speed = 0.0
		return
	if PhaseManager.is_station():
		if not selected or manual_axis == 0 or building_hidden:
			current_speed = 0.0
			return
		current_speed = move_toward(current_speed, max_speed * manual_axis, acceleration * delta)
		cruise_direction = manual_axis
		return
	var target_speed := cruise_speed * cruise_direction
	if manual_axis > 0:
		target_speed = max_speed
	elif manual_axis < 0:
		# Down first gives useful low-speed positioning. Holding it is the
		# deliberate gesture that takes the engine through a reversal.
		target_speed = minimum_speed if manual_hold_time < REVERSE_HOLD_SECONDS else -cruise_speed
	elif throttle_notch == 0:
		# Legacy callers asking for BRAKE get very slow movement, never parking.
		target_speed = minimum_speed * cruise_direction
	elif requested_direction != 0 and throttle_notch >= 2:
		var power_fraction := float(throttle_notch - 1) / 4.0
		target_speed = lerpf(cruise_speed, max_speed, power_fraction) * requested_direction
	var current_sign := signi(current_speed)
	var target_sign := signi(target_speed)
	var rate := acceleration
	if current_sign != 0 and current_sign != target_sign:
		# Opposite command first brakes to zero. Direction cannot flip instantly.
		target_speed = 0.0
		rate = deceleration / maxf(_brake_time_multiplier, 0.05)
	elif absf(target_speed) < absf(current_speed):
		rate = deceleration / maxf(_brake_time_multiplier, 0.05)
	elif target_sign < 0:
		rate = reverse_acceleration
	current_speed = move_toward(current_speed, target_speed, rate * delta)
	if target_sign != 0 and signi(current_speed) == target_sign:
		cruise_direction = target_sign

func set_manual_axis(axis: int, delta: float = 0.0) -> void:
	manual_axis = clampi(axis, -1, 1)
	if manual_axis < 0:
		manual_hold_time += maxf(delta, 0.0)
	else:
		manual_hold_time = 0.0
	requested_direction = manual_axis
	throttle_notch = 5 if manual_axis > 0 else (0 if manual_axis < 0 else 1)

## Compatibility helper for older callers and tests. New UI should use
## set_driver_controls() so direction and power remain separate intentions.
func set_manual_command(command: int) -> void:
	var normalized := clampi(command, -1, 1)
	set_driver_controls(normalized, 5 if normalized != 0 else 1)

func set_driver_controls(direction: int, notch: int) -> void:
	requested_direction = clampi(direction, -1, 1)
	throttle_notch = clampi(notch, 0, 5)

func release_driver_controls() -> void:
	manual_axis = 0
	manual_hold_time = 0.0
	set_driver_controls(0, 1)

func place_at_route_distance(distance_on_route: float) -> bool:
	if route_length <= 0.0 or not _positions_valid_at(distance_on_route, followers.size()):
		return false
	route_distance = fposmod(distance_on_route, route_length)
	_apply_consist_positions()
	return true

var selected_number: int = 0

func set_selected(value: bool, number: int = 0) -> void:
	selected = value
	selected_number = number if value else 0
	queue_redraw()

func _build_route_metrics() -> void:
	var metrics := _metrics_for(path)
	segment_starts = metrics.starts
	route_length = metrics.length

static func _metrics_for(ring: PackedVector2Array) -> Dictionary:
	var starts := PackedFloat32Array()
	var length := 0.0
	for index in range(ring.size()):
		starts.append(length)
		length += ring[index].distance_to(ring[(index + 1) % ring.size()])
	return {"starts": starts, "length": length}

func _sample_route(distance_on_route: float) -> Dictionary:
	if navigator: return navigator.sample(distance_on_route)
	if route_length <= 0.0:
		return {"position": global_position, "direction": Vector2.DOWN, "index": 0}
	return _sample_on(path, segment_starts, route_length, distance_on_route)

static func _sample_on(ring: PackedVector2Array, starts: PackedFloat32Array, length: float, distance_on_route: float) -> Dictionary:
	var wrapped := fposmod(distance_on_route, length)
	for index in range(ring.size()):
		var start_distance: float = starts[index]
		var next_distance := length if index == ring.size() - 1 else float(starts[index + 1])
		if wrapped <= next_distance or index == ring.size() - 1:
			var start := ring[index]
			var finish := ring[(index + 1) % ring.size()]
			var segment_length := maxf(next_distance - start_distance, 0.001)
			var weight := clampf((wrapped - start_distance) / segment_length, 0.0, 1.0)
			return {"position": start.lerp(finish, weight), "direction": (finish - start).normalized(), "index": index}
	return {"position": ring[0], "direction": Vector2.DOWN, "index": 0}

## Distance along `ring` of the closest point to `point`, or -1.0 when the
## point is further than `tolerance` from every segment.
static func _project_onto(ring: PackedVector2Array, starts: PackedFloat32Array, point: Vector2, tolerance: float) -> float:
	var best := -1.0
	var best_gap := tolerance
	for index in range(ring.size()):
		var start := ring[index]
		var finish := ring[(index + 1) % ring.size()]
		var segment := finish - start
		var weight := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
		var candidate := start + segment * weight
		var gap := candidate.distance_to(point)
		if gap <= best_gap:
			best_gap = gap
			best = float(starts[index]) + segment.length() * weight
	return best

## Adopts a revised ring for the same railway. Succeeds only when the engine
## and every car already sit on geometry the two rings share, in the same
## order and facing, so nothing teleports and the consist can never end up
## straddling a stretch the new route no longer includes. Callers retry
## later when this returns false.
func rebind_route(new_path: PackedVector2Array) -> bool:
	if navigator: return true
	if new_path.size() < 4:
		return false
	var metrics := _metrics_for(new_path)
	var new_length: float = metrics.length
	if (followers.size() + 1) * car_spacing + occupancy_distance >= new_length:
		return false
	var engine_distance := _project_onto(new_path, metrics.starts, global_position, 2.0)
	if engine_distance < 0.0:
		return false
	var current := _sample_route(route_distance)
	var revised := _sample_on(new_path, metrics.starts, new_length, engine_distance)
	if Vector2(current.direction).dot(Vector2(revised.direction)) < 0.9:
		return false
	for index in range(followers.size()):
		var car := followers[index]
		if not is_instance_valid(car):
			continue
		var expected: Vector2 = _sample_on(new_path, metrics.starts, new_length, engine_distance - car_spacing * (index + 1)).position
		if expected.distance_to(car.global_position) > 3.0:
			return false
	if not _positions_valid_on(new_path, metrics.starts, new_length, engine_distance, followers.size()):
		return false
	path = new_path.duplicate()
	_build_route_metrics()
	route_distance = fposmod(engine_distance, route_length)
	_apply_consist_positions()
	return true

## True when the engine or any coupled car is within `radius` of `point`.
func occupies_point(point: Vector2, radius: float) -> bool:
	if global_position.distance_to(point) <= radius:
		return true
	for car in followers:
		if is_instance_valid(car) and car.global_position.distance_to(point) <= radius:
			return true
	return false

func _advance_safely(signed_distance: float) -> void:
	if navigator:
		movement_blocked = not navigator.advance(signed_distance, followers.size(), car_spacing, occupancy_distance)
		route_distance = navigator.distance
		if navigator.buffer_hit:
			cruise_direction *= -1
			buffer_pause = 0.65
			current_speed = 0.0
		elif movement_blocked:
			current_speed = 0.0
		_apply_consist_positions()
		return
	movement_blocked = false
	var remaining := absf(signed_distance)
	var direction_sign := signf(signed_distance)
	while remaining > 0.001:
		var step_distance := minf(remaining, 6.0)
		var candidate := route_distance + step_distance * direction_sign
		if not _positions_valid_at(candidate, followers.size()):
			current_speed = 0.0
			movement_blocked = true
			break
		route_distance = fposmod(candidate, route_length)
		remaining -= step_distance
	_apply_consist_positions()

func _positions_valid_at(engine_distance: float, follower_count: int) -> bool:
	if navigator: return navigator.valid(engine_distance, follower_count, car_spacing, occupancy_distance)
	if route_length <= 0.0:
		return false
	return _positions_valid_on(path, segment_starts, route_length, engine_distance, follower_count)

func _positions_valid_on(ring: PackedVector2Array, starts: PackedFloat32Array, length: float, engine_distance: float, follower_count: int) -> bool:
	if length <= 0.0:
		return false
	var positions: Array[Vector2] = []
	positions.append(_sample_on(ring, starts, length, engine_distance).position)
	for index in range(follower_count):
		positions.append(_sample_on(ring, starts, length, engine_distance - car_spacing * (index + 1)).position)
	for first in range(positions.size()):
		# Neighbours in the consist are held exactly car_spacing apart along the
		# rail, so their straight-line gap is a property of the corner they are
		# rounding, not a collision movement could avoid — rejecting it would
		# stop the train dead and it could never start again. Only vehicles
		# further apart in the consist can genuinely close on each other, which
		# is what this guard is for: a tail wrapping round a short loop.
		for second in range(first + 2, positions.size()):
			if positions[first].distance_to(positions[second]) < occupancy_distance:
				return false
	return true

func _apply_consist_positions() -> void:
	var engine_sample := _sample_route(route_distance)
	global_position = engine_sample.position
	path_index = int(engine_sample.index)
	var engine_direction: Vector2 = _smooth_direction(route_distance)
	_face_engine(engine_direction)
	for index in range(followers.size()):
		var car := followers[index]
		if not is_instance_valid(car):
			continue
		var sample := _sample_route(route_distance - car_spacing * (index + 1))
		if not car.visible and not building_hidden:
			car.visible = true
			car.process_mode = Node.PROCESS_MODE_INHERIT
		# Cars follow the rail's authored orientation, not the current travel
		# sign. Reversing means backing the consist up; it must not turn every
		# directional turret around and swap its firing side.
		var car_direction: Vector2 = _smooth_direction(route_distance - car_spacing * (index + 1))
		if car.has_method("set_convoy_transform"):
			car.set_convoy_transform(sample.position, car_direction)
		else:
			car.global_position = sample.position

func _smooth_direction(at: float) -> Vector2:
	var before: Vector2 = _sample_route(at - 15.0).position
	var after: Vector2 = _sample_route(at + 15.0).position
	return (after - before).normalized() if not before.is_equal_approx(after) else Vector2(_sample_route(at).direction)

func total_weight() -> float:
	var sum := 0.0
	for car in followers:
		if is_instance_valid(car):
			var w = car.get("weight")
			sum += w if w != null else 1.0
	return sum

## The Tender's capacity bonus only applies when it's coupled directly
## behind the engine (followers[0]) — anywhere else in the train it's just
## another car, per its card's second paragraph.
func effective_capacity() -> float:
	if not followers.is_empty() and is_instance_valid(followers[0]) and followers[0].get("is_tender") == true:
		return carry_capacity + tender_capacity_bonus
	return carry_capacity

func attach_car(car: Node2D) -> bool:
	if capped:
		return false
	var declared_weight = car.get("weight")
	var car_weight: float = declared_weight if declared_weight != null else 1.0
	if total_weight() + car_weight > effective_capacity():
		return false
	var requested_count := followers.size() + 1
	# A closed loop has finite physical capacity. Reject a consist whose tail
	# would wrap around onto its own engine or another car.
	if navigator:
		if not navigator.ensure_tail(requested_count * car_spacing): return false
		route_distance = navigator.distance
	elif requested_count * car_spacing + occupancy_distance >= route_length:
		return false
	if not _positions_valid_at(route_distance, requested_count):
		return false
	followers.append(car)
	car.set_meta("convoy", self)
	_apply_consist_positions()
	if car.get("is_train_cap") == true:
		capped = true
		_apply_brake_buff(car)
	return true

func _apply_brake_buff(brake_van: Node2D) -> void:
	var bonus = brake_van.get("attack_speed_bonus")
	if bonus == null:
		bonus = 1.2
	for car in followers:
		if is_instance_valid(car) and car != brake_van and car.get("attack_speed_multiplier") != null:
			car.set("attack_speed_multiplier", bonus)
	var time_bonus = brake_van.get("brake_time_multiplier")
	_brake_time_multiplier = time_bonus if time_bonus != null else 0.85

func _reset_attack_speed_buffs() -> void:
	for car in followers:
		if is_instance_valid(car) and car.get("attack_speed_multiplier") != null:
			car.set("attack_speed_multiplier", 1.0)
	_brake_time_multiplier = 1.0

func can_attach_at(world_position: Vector2) -> bool:
	if capped or wrecked:
		return false
	if world_position.distance_to(global_position) <= attachment_radius:
		return true
	for car in followers:
		if is_instance_valid(car) and car.visible and world_position.distance_to(car.global_position) <= attachment_radius:
			return true
	return false

## Exact transform the next car will receive if it is attached now. Placement
## previews use this rather than guessing from the cursor or nearest rail tile.
func next_car_preview_transform() -> Dictionary:
	if route_length <= 0.0:
		return {}
	var sample := _sample_route(route_distance - car_spacing * (followers.size() + 1))
	return {
		"position": sample.position,
		"direction": sample.direction,
	}

func set_drag_active(active: bool) -> void:
	drag_active = active
	var tint := Color(1.0, 0.85, 0.35, 1.0) if active else Color.WHITE
	engine.modulate = tint
	for car in followers:
		if is_instance_valid(car) and car.visible:
			car.modulate = tint
	queue_redraw()

func car_count() -> int:
	return followers.size()

## Removes whichever car (if any) is within attachment_radius of
## world_position. Cars in front and behind it snap together automatically
## because their fixed route-distance offsets are recalculated immediately.
func remove_car_near(world_position: Vector2) -> bool:
	var closest_index := -1
	var closest_distance := attachment_radius
	for index in range(followers.size()):
		var car := followers[index]
		if not is_instance_valid(car) or not car.visible:
			continue
		var distance := world_position.distance_to(car.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_index = index
	if closest_index == -1:
		return false
	var car: Node2D = followers[closest_index]
	followers.remove_at(closest_index)
	if car.get("is_train_cap") == true:
		capped = false
		_reset_attack_speed_buffs()
	car.queue_free()
	queue_redraw()
	return true

func remove_car(car: Node2D) -> bool:
	var index := followers.find(car)
	if index < 0:
		return false
	followers.remove_at(index)
	if car.get("is_train_cap") == true:
		capped = false
		_reset_attack_speed_buffs()
	car.queue_free()
	# Close the gap now rather than on the next frame so a destroyed car's
	# neighbours never sit a frame apart from where the route says they are.
	_apply_consist_positions()
	queue_redraw()
	return true

func _draw() -> void:
	var previous := Vector2.ZERO
	_draw_consist_presence()
	if wrecked:
		draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 8, Color(1.0, 0.45, 0.3, 0.8), 3.0, false)
		_draw_caption("WRECKED — DROP A LOCOMOTIVE HERE", Vector2(0.0, -58.0), Color(1.0, 0.82, 0.7, 1.0))
	if selected:
		_draw_route_direction()
		_draw_selection_brackets()
		if not wrecked:
			_draw_engine_card()
	if occupancy_debug:
		var debug_color := Color(1.0, 0.22, 0.18, 0.75) if movement_blocked else Color(0.12, 0.9, 0.95, 0.45)
		draw_arc(Vector2.ZERO, occupancy_distance * 0.5, 0.0, TAU, 24, debug_color, 2.0, true)
	if drag_active and not capped:
		_draw_attach_target(Vector2.ZERO)
	for car in followers:
		if not is_instance_valid(car) or not car.visible:
			continue
		var car_local := to_local(car.global_position)
		if occupancy_debug:
			draw_arc(car_local, occupancy_distance * 0.5, 0.0, TAU, 24, Color(0.12, 0.9, 0.95, 0.45), 2.0, true)
		# Slim couplers: a drawbar and a small pin, not another board piece.
		draw_line(previous, car_local, Color(0.12, 0.1, 0.07, 0.85), 4.5)
		draw_circle(previous.lerp(car_local, 0.5), 3.4, Color(0.72, 0.48, 0.18, 1.0))
		if drag_active and not capped:
			_draw_attach_target(car_local)
		previous = car_local

## A small contact shadow under each vehicle lifts it off the sleepers without
## drawing a second object on the rails. The locomotive gets a slightly wider
## one and a darker ink ring, so it outranks its cars at a glance.
func _draw_consist_presence() -> void:
	var tokens: Array[Vector2] = [Vector2.ZERO]
	for car in followers:
		if is_instance_valid(car) and car.visible:
			tokens.append(to_local(car.global_position))
	# The consist as one object: a quiet spine threaded through every vehicle.
	if tokens.size() > 1:
		draw_polyline(PackedVector2Array(tokens), Color(0.08, 0.06, 0.04, 0.22), 7.0, true)
	for index in range(tokens.size()):
		var token := tokens[index]
		var is_engine := index == 0
		var radius := 22.0 if is_engine else 18.0
		draw_circle(token + Vector2(0.0, 3.0), radius, Color(0.05, 0.04, 0.03, 0.22))
		draw_arc(token, radius, 0.0, TAU, 24, Color(0.07, 0.05, 0.03, 0.6 if is_engine else 0.34), 3.0 if is_engine else 1.8, true)

## Arrows around the ring this train drives — only while it is selected, and
## spaced well apart so they read as a direction rather than as track texture.
func _draw_route_direction() -> void:
	if path.size() < 2 or route_length <= 0.0:
		return
	var spacing := 168.0
	var travelled := spacing * 0.5
	var facing := 1.0 if cruise_direction >= 0 else -1.0
	while travelled < route_length:
		var sample := _sample_route(route_distance + travelled)
		var point: Vector2 = to_local(sample.position)
		var heading: Vector2 = sample.direction * facing
		var side := heading.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			point + heading * 7.0,
			point - heading * 4.0 + side * 4.5,
			point - heading * 4.0 - side * 4.5,
		]), Color(0.24, 0.86, 1.0, 0.5))
		travelled += spacing

## Thin outline plus four corner brackets around the locomotive, instead of a
## filled disc that buried the engine, its coupler and the rail beneath it.
func _draw_selection_brackets() -> void:
	var half := 31.0
	var arm := 10.0
	var cyan := Color(0.21, 0.85, 1.0)
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(cyan.r, cyan.g, cyan.b, 0.28), false, 1.5)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var point := Vector2(corner.x * half, corner.y * half)
		draw_line(point, point - Vector2(corner.x * arm, 0.0), Color(0.04, 0.03, 0.02, 0.8), 5.0, true)
		draw_line(point, point - Vector2(0.0, corner.y * arm), Color(0.04, 0.03, 0.02, 0.8), 5.0, true)
		draw_line(point, point - Vector2(corner.x * arm, 0.0), cyan, 2.6, true)
		draw_line(point, point - Vector2(0.0, corner.y * arm), cyan, 2.6, true)

## Compact card floating clear above the selected engine: which train this is
## and how loaded it is. Kept off the rails so it never competes with them.
func _draw_engine_card() -> void:
	var card_width := 128.0
	var card_height := 32.0
	var box := Rect2(-card_width * 0.5, -50.0 - card_height, card_width, card_height)
	# Stem down toward the locomotive, so the card is clearly about this train.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, box.end.y + 7.0), Vector2(-6.0, box.end.y - 1.0), Vector2(6.0, box.end.y - 1.0),
	]), Color(0.07, 0.06, 0.05, 0.94))
	draw_rect(box, Color(0.07, 0.06, 0.05, 0.94), true)
	draw_rect(box, Color(0.21, 0.85, 1.0, 0.75), false, 2.0)
	var font: Font = CAPTION_FONT
	draw_string(font, box.position + Vector2(9.0, 15.0), "ENGINE %d" % selected_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9fe9ff"))
	var load_text := "%d / %d" % [roundi(total_weight()), roundi(effective_capacity())]
	var load_width := font.get_string_size(load_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(box.end.x - 9.0 - load_width, box.position.y + 15.0), load_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffe9b4"))
	var bar := Rect2(box.position.x + 9.0, box.position.y + 20.0, card_width - 18.0, 6.0)
	draw_rect(bar, Color(0.18, 0.15, 0.12, 1.0), true)
	var load_fraction := clampf(total_weight() / maxf(effective_capacity(), 1.0), 0.0, 1.0)
	var fill_color := Color(0.42, 0.86, 0.55).lerp(Color(0.95, 0.65, 0.25), load_fraction)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * load_fraction, bar.size.y)), fill_color, true)

const CAPTION_FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")

## Screen-oriented text above the engine regardless of which way the
## locomotive is facing (the convoy node itself never rotates).
func _draw_caption(text: String, offset: Vector2, color: Color) -> void:
	var font: Font = CAPTION_FONT
	var font_size := 14
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var box := Rect2(offset - Vector2(width * 0.5 + 7.0, 11.0), Vector2(width + 14.0, 22.0))
	draw_rect(box, Color(0.07, 0.05, 0.04, 0.85), true)
	draw_rect(box, color, false, 2.0)
	draw_string(font, box.position + Vector2(7.0, 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_attach_target(target: Vector2) -> void:
	# Crooked concentric rings read as a physical placement token while still
	# leaving the train artwork visible beneath them.
	draw_circle(target, 54.0, Color(0.25, 0.95, 0.62, 0.14))
	draw_arc(target, 55.0, 0.08, TAU - 0.12, 28, Color(0.08, 0.18, 0.1, 0.92), 8.0, true)
	draw_arc(target + Vector2(2, -1), 48.0, -0.05, TAU - 0.18, 24, Color(0.38, 1.0, 0.7, 0.95), 4.0, true)

func _emit_smoke() -> void:
	if smoke_texture == null:
		return
	var puff := Sprite2D.new()
	puff.texture = smoke_texture
	puff.scale = Vector2(0.055, 0.055)
	puff.position = engine.position + Vector2(0.0, -24.0).rotated(engine.rotation)
	puff.modulate = Color(0.78, 0.75, 0.68, 0.65)
	puff.z_index = -1
	add_child(puff)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "position", puff.position + Vector2(0.0, -45.0), 0.9)
	tween.tween_property(puff, "scale", Vector2(0.1, 0.1), 0.9)
	tween.tween_property(puff, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(puff.queue_free)

func _face_engine(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		# Steam-engine artwork's headlamp/boiler end faces up in the source
		# image, not down — the train was driving tender-first before this.
		engine.rotation = direction.angle() - PI * 0.5
