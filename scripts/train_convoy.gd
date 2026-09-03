extends Node2D
class_name TrainConvoy
## The always-present locomotive leads one train. Every consist member is
## sampled at a fixed distance along one closed route, so reversing cannot
## make the engine retrace into its own cars.
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

## Turret art occupies a 1500px square at 0.085 scale (127.5 world units).
## Engine liveries exist as both 750px and 1500px sources, so derive their
## scale from the texture instead of inheriting the old 750px-only value.
const ENGINE_TOKEN_SIZE := 68.0

var path: PackedVector2Array
var path_index: int = 0
var followers: Array[Node2D] = []
var segment_starts: PackedFloat32Array = PackedFloat32Array()
var route_length := 0.0
var route_distance := 0.0
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

func _ready() -> void:
	if balance == null:
		return
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
		var source_size := texture.get_size()
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

func _process(delta: float) -> void:
	if path.size() < 2:
		return
	_update_speed(delta)
	_advance_safely(current_speed * delta)
	smoke_timer -= delta
	if smoke_timer <= 0.0 and absf(current_speed) > 2.0:
		_emit_smoke()
		smoke_timer = 0.32
	queue_redraw()

func _update_speed(delta: float) -> void:
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

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func _build_route_metrics() -> void:
	segment_starts = PackedFloat32Array()
	route_length = 0.0
	for index in range(path.size()):
		segment_starts.append(route_length)
		route_length += path[index].distance_to(path[(index + 1) % path.size()])

func _sample_route(distance_on_route: float) -> Dictionary:
	if route_length <= 0.0:
		return {"position": global_position, "direction": Vector2.DOWN, "index": 0}
	var wrapped := fposmod(distance_on_route, route_length)
	for index in range(path.size()):
		var start_distance: float = segment_starts[index]
		var next_distance := route_length if index == path.size() - 1 else float(segment_starts[index + 1])
		if wrapped <= next_distance or index == path.size() - 1:
			var start := path[index]
			var finish := path[(index + 1) % path.size()]
			var segment_length := maxf(next_distance - start_distance, 0.001)
			var weight := clampf((wrapped - start_distance) / segment_length, 0.0, 1.0)
			return {"position": start.lerp(finish, weight), "direction": (finish - start).normalized(), "index": index}
	return {"position": path[0], "direction": Vector2.DOWN, "index": 0}

func _advance_safely(signed_distance: float) -> void:
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
	if route_length <= 0.0:
		return false
	var positions: Array[Vector2] = []
	positions.append(_sample_route(engine_distance).position)
	for index in range(follower_count):
		positions.append(_sample_route(engine_distance - car_spacing * (index + 1)).position)
	for first in range(positions.size()):
		for second in range(first + 1, positions.size()):
			if positions[first].distance_to(positions[second]) < occupancy_distance:
				return false
	return true

func _apply_consist_positions() -> void:
	var engine_sample := _sample_route(route_distance)
	global_position = engine_sample.position
	path_index = int(engine_sample.index)
	var engine_direction: Vector2 = engine_sample.direction * cruise_direction
	_face_engine(engine_direction)
	for index in range(followers.size()):
		var car := followers[index]
		if not is_instance_valid(car):
			continue
		var sample := _sample_route(route_distance - car_spacing * (index + 1))
		if not car.visible:
			car.visible = true
			car.process_mode = Node.PROCESS_MODE_INHERIT
		# Cars follow the rail's authored orientation, not the current travel
		# sign. Reversing means backing the consist up; it must not turn every
		# directional turret around and swap its firing side.
		var car_direction: Vector2 = sample.direction
		if car.has_method("set_convoy_transform"):
			car.set_convoy_transform(sample.position, car_direction)
		else:
			car.global_position = sample.position

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
	if requested_count * car_spacing + occupancy_distance >= route_length:
		return false
	if not _positions_valid_at(route_distance, requested_count):
		return false
	followers.append(car)
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
	if capped:
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
	queue_redraw()
	return true

func _draw() -> void:
	var previous := Vector2.ZERO
	if selected:
		draw_circle(Vector2.ZERO, 43.0, Color(0.15, 0.78, 1.0, 0.12))
		draw_arc(Vector2.ZERO, 44.0, 0.04, TAU - 0.08, 30, Color("35d9ff"), 4.0, true)
		draw_arc(Vector2(1.5, -1.0), 48.0, 0.2, TAU - 0.16, 27, Color(0.04, 0.03, 0.02, 0.9), 2.5, true)
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
		draw_line(previous, car_local, Color(0.12, 0.1, 0.07, 0.9), 9.0)
		draw_circle(previous.lerp(car_local, 0.5), 7.0, Color(0.72, 0.48, 0.18, 1.0))
		if drag_active and not capped:
			_draw_attach_target(car_local)
		previous = car_local

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
		engine.rotation = direction.angle() + PI * 0.5
