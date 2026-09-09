extends CharacterBody2D
class_name EnemyMovement
## Walks a spider straight down its assigned courtyard lane. At the station
## it stops, stays targetable, and attacks until the train destroys it.

@export var move_speed: float = 1.0
@export var alternate_texture: Texture2D

@export_group("Station Attack")
@export var station_attack_damage: int = 1
@export var station_attack_interval: float = 2.25
@export var station_attack_windup: float = 0.55

@export_group("Hit Feedback")
@export var hit_flash_color := Color(1.65, 1.55, 0.82, 1.0)
@export var hit_flash_duration: float = 0.09
@export var hit_squash := Vector2(1.06, 0.92)

@export_group("Train Interaction")
## A train unit this far ahead in the spider's corridor makes it look for a
## clear lane to the left or right.
@export var lookahead_distance: float = 130.0
## Closer than this the unit is physically in the way: bite it if no detour
## exists.
@export var contact_distance: float = 56.0
@export var unit_half_width: float = 34.0
## How many lanes to each side are searched for a way round (the earlier
## "three blocks" idea, measured in courtyard lanes).
@export var detour_lane_search: int = 3
@export var lane_x_positions := PackedFloat32Array([-262.0, -196.5, -131.0, -65.5, 0.0, 65.5, 131.0, 196.5, 262.0])

const DOT_STAGE_TEXTURES: Array[Array] = [
	[preload("res://assets/sprites/spiders/Spider walk 1.png"), preload("res://assets/sprites/spiders/Spider walk 2.png")],
	[preload("res://assets/sprites/spiders/Spider walk 2-1.png"), preload("res://assets/sprites/spiders/Spider walk 2-2.png")],
	[preload("res://assets/sprites/spiders/Spider walk 3-1.png"), preload("res://assets/sprites/spiders/Spider walk 3-2.png")],
	[preload("res://assets/sprites/spiders/Spider walk 4-1.png"), preload("res://assets/sprites/spiders/Spider walk 4-2.png")],
	[preload("res://assets/sprites/spiders/Spider walk 5-1.png"), preload("res://assets/sprites/spiders/Spider walk 5-2.png")],
	[preload("res://assets/sprites/spiders/Spider walk 6-1.png"), preload("res://assets/sprites/spiders/Spider walk 6-2.png")],
]

@onready var health: Health = $Health
@onready var spider_sprite: Sprite2D = $Sprite2D

var health_dots: SpiderHealthDots
var base_speed: float
var leak_y: float = 720.0
var lane_configured: bool = false
var primary_texture: Texture2D
var animation_time: float = 0.0
var base_sprite_scale: Vector2
var archetype_id := "generic"
var ability := "dots"
var speed_multiplier := 1.0
var death_texture: Texture2D
var rage_texture_a: Texture2D
var rage_texture_b: Texture2D
var _special_clock := 0.0
var _rally_expires_at := 0
var _armored_hit_counter := 0
var _jumping := false
var _hatched := false
var attacking_station := false
var _station_attack_timer := 0.0
var _hit_feedback_tween: Tween
var route_target := Vector2.ZERO
var has_route_target := false
var assault_speed_multiplier := 1.0

var bite_damage_per_second := 25.0
var bite_tick_seconds := 0.25
## Unit currently being chewed on, or null while walking.
var biting_target: Node2D = null
var bites_landed := 0
var _bite_timer := 0.0
var _sidestepping := false
var _sidestep_target_x := 0.0
var _sidestep_time := 0.0
## unit instance id -> ms timestamp before which that unit cannot strike again
var _impact_cooldowns: Dictionary = {}

## Absolute ms timestamp (Time.get_ticks_msec()) the current slow expires at.
## Tracking an expiry rather than a bool means a second overlapping pulse can
## only extend the slow, never cut a longer one short.
var _slow_expires_at: int = 0

func _ready() -> void:
	add_to_group("spiders")
	var balance: GameBalance = load("res://resources/game_balance.tres")
	if balance:
		bite_damage_per_second = balance.bite_damage_per_second
		bite_tick_seconds = balance.bite_tick_seconds
	base_speed = move_speed
	base_sprite_scale = spider_sprite.scale
	primary_texture = spider_sprite.texture
	health_dots = SpiderHealthDots.new()
	spider_sprite.add_child(health_dots)
	health_dots.stage_changed.connect(_on_health_stage_changed)
	health.hit_points_changed.connect(health_dots.set_hit_points)
	health_dots.set_hit_points(health.hit_points, health.max_hit_points)

func configure_archetype(profile: Dictionary, wave: int, campaign_level: int) -> void:
	archetype_id = String(profile.get("id", "generic"))
	ability = String(profile.get("ability", ""))
	primary_texture = profile.walk_a
	alternate_texture = profile.walk_b
	death_texture = profile.get("death")
	rage_texture_a = profile.get("rage_a")
	rage_texture_b = profile.get("rage_b")
	spider_sprite.texture = primary_texture
	base_sprite_scale = Vector2.ONE * float(profile.get("scale", 0.095))
	spider_sprite.scale = base_sprite_scale
	speed_multiplier = float(profile.get("speed", 1.0))
	var difficulty_bonus := campaign_level + maxi(wave - 1, 0) / 2
	health.configure_hit_points(int(profile.get("hp", 5)) + difficulty_bonus)
	health.set_bounty(int(profile.get("bounty", 45)) + campaign_level * 8)
	# The complete one-to-six-dot artwork is now available, so the procedural
	# dot overlay remains only as the stage signal source and is not rendered.
	health_dots.visible = false

func configure_lane(destination_y: float, journey_duration_seconds: float = 25.0) -> void:
	leak_y = destination_y
	configure_route(Vector2(global_position.x, destination_y), journey_duration_seconds)

## Shared point-target movement used by Spider Assault entrances. Standard
## campaign lanes call this with a point directly below the spawn location.
func configure_route(destination: Vector2, journey_duration_seconds: float = 25.0) -> void:
	route_target = destination
	has_route_target = true
	leak_y = destination.y
	# Define pacing as travel time rather than fragile world-units/second. A
	# larger replacement board can move the spawn or station while preserving
	# the intended 20–30 second unslowed journey.
	if journey_duration_seconds > 0.0:
		base_speed = global_position.distance_to(route_target) / journey_duration_seconds * speed_multiplier
	lane_configured = true

func configure_difficulty(hit_points: int) -> void:
	health.configure_hit_points(hit_points, false)
	health_dots.initialize_hit_points(hit_points)
	if ability == "dots":
		_set_dot_stage(_dot_count_for_hp(hit_points))

func configure_bounty(value: int) -> void:
	health.set_bounty(value)

func _on_health_stage_changed(_previous_dots: int, current_dots: int) -> void:
	if current_dots <= 0:
		return
	if ability == "dots":
		_set_dot_stage(current_dots)
	# A quick squash and paper puff makes each two-hit downgrade read as an
	# actual transformation into the next dotted spider, not a HUD update.
	spider_sprite.scale = base_sprite_scale * 0.8
	var tween := create_tween().set_parallel(true)
	tween.tween_property(spider_sprite, "scale", base_sprite_scale * 1.08, 0.1)
	tween.chain().tween_property(spider_sprite, "scale", base_sprite_scale, 0.1)
	var puff := Sprite2D.new()
	puff.texture = preload("res://assets/sprites/effects/Puff.png")
	puff.scale = Vector2(0.035, 0.035)
	puff.modulate = Color(1.0, 0.9, 0.72, 0.8)
	puff.z_index = -1
	add_child(puff)
	var puff_tween := create_tween().set_parallel(true)
	puff_tween.tween_property(puff, "scale", Vector2(0.075, 0.075), 0.22)
	puff_tween.tween_property(puff, "modulate:a", 0.0, 0.22)
	puff_tween.chain().tween_callback(puff.queue_free)

func _dot_count_for_hp(hp: int) -> int:
	if hp >= 14: return 6
	if hp >= 12: return 5
	if hp >= 10: return 4
	if hp >= 8: return 3
	if hp >= 6: return 2
	return 1

func _set_dot_stage(dot_count: int) -> void:
	var textures: Array = DOT_STAGE_TEXTURES[clampi(dot_count, 1, 6) - 1]
	primary_texture = textures[0]
	alternate_texture = textures[1]
	spider_sprite.texture = primary_texture

func _physics_process(delta: float) -> void:
	if not lane_configured:
		return
	if attacking_station:
		velocity = Vector2.ZERO
		_station_attack_timer -= delta
		if _station_attack_timer <= 0.0:
			_attack_station()
		_animate_walk(delta)
		return
	if (has_route_target and global_position.distance_to(route_target) <= 10.0) or (not has_route_target and global_position.y >= leak_y):
		global_position = route_target if has_route_target else Vector2(global_position.x, leak_y)
		attacking_station = true
		_station_attack_timer = station_attack_windup
		velocity = Vector2.ZERO
		queue_redraw()
		return
	_special_clock += delta
	_update_special_state()
	var speed: float = base_speed * assault_speed_multiplier
	if Time.get_ticks_msec() < _slow_expires_at:
		speed *= 0.5
	if Time.get_ticks_msec() < _rally_expires_at:
		speed *= 1.25
	if ability == "charge" and fmod(_special_clock, 5.0) > 3.8:
		speed *= 2.1
	if ability == "enrage" and health.hit_points <= health.max_hit_points / 2:
		speed *= 1.55
	if ability == "jump":
		# Jump Spiders advance only during the visible hop window. Grounded time
		# is a deliberate pause, not ordinary walking at base speed.
		speed = speed * 1.8 if _jumping else 0.0
	var travel_direction := global_position.direction_to(route_target) if has_route_target else Vector2.DOWN
	if travel_direction.is_zero_approx():
		travel_direction = Vector2.DOWN
	if _update_train_interaction(delta, travel_direction, speed):
		return
	velocity = travel_direction * speed
	move_and_slide()
	queue_redraw()
	_animate_walk(delta)

## Trains are obstacles. A spider first tries to step into a clear lane to
## its left or right; only when no lane within reach is clear and the unit
## is physically in its way does it stop and bite. Returns true when it
## handled this frame's movement.
func _update_train_interaction(delta: float, travel_direction: Vector2, speed: float) -> bool:
	if _sidestepping:
		_sidestep_time += delta
		var dx := _sidestep_target_x - global_position.x
		if absf(dx) <= 2.5:
			global_position.x = _sidestep_target_x
			_finish_sidestep()
		elif _sidestep_time > 3.0:
			_finish_sidestep()
		else:
			var vertical := signf(travel_direction.y) if absf(travel_direction.y) > 0.01 else 1.0
			velocity = Vector2(signf(dx) * 1.1, vertical).normalized() * maxf(speed, 1.0)
			move_and_slide()
			queue_redraw()
			_animate_walk(delta)
			return true
	var obstacle := _blocking_unit(travel_direction)
	if is_instance_valid(biting_target):
		var still_blocked: bool = not obstacle.is_empty() and obstacle.unit == biting_target and float(obstacle.forward) <= contact_distance
		if still_blocked:
			_bite(delta)
			return true
		_stop_biting()
	if obstacle.is_empty():
		return false
	var detour_x := _find_detour_lane(travel_direction, Vector2(obstacle.unit.global_position))
	if not is_nan(detour_x):
		_sidestepping = true
		_sidestep_target_x = detour_x
		_sidestep_time = 0.0
		return false
	if float(obstacle.forward) <= contact_distance:
		biting_target = obstacle.unit
		_bite_timer = minf(_bite_timer, bite_tick_seconds)
		_bite(delta)
		return true
	return false

func _finish_sidestep() -> void:
	_sidestepping = false
	route_target.x = global_position.x

func _stop_biting() -> void:
	biting_target = null
	_bite_timer = 0.0

## Nearest live train unit inside this spider's corridor and within
## lookahead. Wrecked engines and destroyed cars are rubble, not obstacles.
func _blocking_unit(travel_direction: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_forward := INF
	for node in get_tree().get_nodes_in_group("train_units"):
		var unit := node as Node2D
		if unit == null or not is_instance_valid(unit) or not unit.visible or unit.is_queued_for_deletion():
			continue
		var health := UnitHealth.of(unit)
		if health != null and health.is_destroyed:
			continue
		var offset := unit.global_position - global_position
		var forward := offset.dot(travel_direction)
		var lateral := absf(offset.dot(travel_direction.orthogonal()))
		if forward > 0.0 and forward <= lookahead_distance and lateral <= unit_half_width and forward < best_forward:
			best_forward = forward
			best = {"unit": unit, "forward": forward, "lateral": lateral}
	return best

## Nearest lane to the left or right whose corridor ahead is free of train
## units, searching one lane at a time up to detour_lane_search away. The
## side away from the obstacle is tried first at each distance.
func _find_detour_lane(travel_direction: Vector2, obstacle_position: Vector2) -> float:
	if lane_x_positions.is_empty():
		return NAN
	var current_index := 0
	var closest := INF
	for index in range(lane_x_positions.size()):
		var gap := absf(lane_x_positions[index] - global_position.x)
		if gap < closest:
			closest = gap
			current_index = index
	var first_side := -1 if obstacle_position.x > global_position.x else 1
	for step in range(1, detour_lane_search + 1):
		for side in [first_side, -first_side]:
			var index: int = current_index + int(side) * step
			if index < 0 or index >= lane_x_positions.size():
				continue
			if _lane_clear(lane_x_positions[index], travel_direction):
				return lane_x_positions[index]
	return NAN

func _lane_clear(lane_x: float, travel_direction: Vector2) -> bool:
	var probe := Vector2(lane_x, global_position.y)
	for node in get_tree().get_nodes_in_group("train_units"):
		var unit := node as Node2D
		if unit == null or not is_instance_valid(unit) or not unit.visible:
			continue
		var health := UnitHealth.of(unit)
		if health != null and health.is_destroyed:
			continue
		var offset := unit.global_position - probe
		var forward := offset.dot(travel_direction)
		var lateral := absf(offset.dot(travel_direction.orthogonal()))
		if forward > -unit_half_width and forward <= lookahead_distance + 40.0 and lateral <= unit_half_width:
			return false
	return true

func _bite(delta: float) -> void:
	velocity = Vector2.ZERO
	_bite_timer -= delta
	if _bite_timer > 0.0:
		_animate_walk(delta)
		return
	_bite_timer = bite_tick_seconds
	bites_landed += 1
	var health := UnitHealth.of(biting_target)
	if health != null:
		health.take_damage(bite_damage_per_second * bite_tick_seconds, true)
	var rest := spider_sprite.position
	var lunge := global_position.direction_to(biting_target.global_position) * 9.0 if is_instance_valid(biting_target) else Vector2(0, 9)
	var tween := create_tween()
	tween.tween_property(spider_sprite, "position", rest + lunge, 0.07)
	tween.tween_property(spider_sprite, "position", rest, 0.1)
	queue_redraw()

func is_biting() -> bool:
	return is_instance_valid(biting_target)

## Called by a moving train unit that overlaps this spider. Returns true when
## the strike landed so the train can recoil; the same unit cannot strike
## again until its cooldown has passed.
func take_impact(unit: Node2D, damage: int, cooldown_seconds: float) -> bool:
	if attacking_station or health.is_destroyed:
		return false
	var key := unit.get_instance_id()
	var now := Time.get_ticks_msec()
	if int(_impact_cooldowns.get(key, 0)) > now:
		return false
	_impact_cooldowns[key] = now + int(cooldown_seconds * 1000.0)
	take_damage(damage)
	return true

func _animate_walk(delta: float) -> void:
	animation_time += delta
	if alternate_texture and animation_time >= 0.16:
		spider_sprite.texture = alternate_texture if spider_sprite.texture == primary_texture else primary_texture
		animation_time = 0.0

## Slows the enemy to half its base speed for `duration` seconds. Safe to
## call while already slowed — only extends the effect, never shortens it.
func apply_slow(duration: float) -> void:
	_slow_expires_at = max(_slow_expires_at, Time.get_ticks_msec() + int(duration * 1000.0))

## Pushes a spider away from its destination without changing its route.
## Coal Cannon uses one board tile (90 units) by default.
func apply_knockback(distance: float) -> void:
	if distance <= 0.0 or not lane_configured or attacking_station:
		return
	var toward_destination := global_position.direction_to(route_target) if has_route_target else Vector2.DOWN
	global_position -= toward_destination * distance
	velocity = Vector2.ZERO
	queue_redraw()

func take_damage(dmg: int) -> void:
	if ability == "armor":
		_armored_hit_counter += 1
		if _armored_hit_counter % 3 == 0:
			_play_block_effect()
			return
	if ability == "jump" and _jumping:
		_play_block_effect()
		return
	health.take_damage(dmg)
	if not health.is_destroyed:
		_play_hit_feedback()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if not get_meta("player_deployed", false):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var readout := Label.new()
		readout.text = "%s. HP %d of %d." % [archetype_id.capitalize(), health.hit_points, health.max_hit_points]
		readout.global_position = global_position + Vector2(-65, -70)
		readout.add_theme_color_override("font_color", Color("fff0b5"))
		readout.add_theme_color_override("font_outline_color", Color("24130d"))
		readout.add_theme_constant_override("outline_size", 5)
		readout.add_theme_font_size_override("font_size", 17)
		readout.z_index = 90
		get_tree().current_scene.add_child(readout)
		var tween := readout.create_tween().set_parallel(true)
		tween.tween_property(readout, "position:y", readout.position.y - 24.0, 1.0)
		tween.tween_property(readout, "modulate:a", 0.0, 1.0)
		tween.chain().tween_callback(readout.queue_free)

func _attack_station() -> void:
	GameEvents.station_attacked.emit(station_attack_damage)
	_station_attack_timer = maxf(station_attack_interval, 0.15)
	var rest := spider_sprite.position
	var tween := create_tween()
	tween.tween_property(spider_sprite, "position", rest + Vector2(0, 9), 0.08)
	tween.tween_property(spider_sprite, "position", rest, 0.12)

func _play_hit_feedback() -> void:
	if _hit_feedback_tween and _hit_feedback_tween.is_valid():
		_hit_feedback_tween.kill()
	var rest_scale := base_sprite_scale * (1.18 if _jumping else 1.0)
	spider_sprite.modulate = hit_flash_color
	spider_sprite.scale = rest_scale * hit_squash
	_hit_feedback_tween = create_tween().set_parallel(true)
	_hit_feedback_tween.tween_property(spider_sprite, "modulate", Color.WHITE, hit_flash_duration)
	_hit_feedback_tween.tween_property(spider_sprite, "scale", rest_scale, hit_flash_duration)

func _draw() -> void:
	if attacking_station:
		draw_arc(Vector2.ZERO, 48.0, -2.6, -0.55, 12, Color(0.9, 0.18, 0.1, 0.65), 3.0)
	if is_instance_valid(biting_target):
		var toward := to_local(biting_target.global_position).normalized()
		var base := toward * 34.0
		draw_line(base - toward.orthogonal() * 10.0, base + toward * 16.0, Color(1.0, 0.32, 0.26, 0.9), 3.0, true)
		draw_line(base + toward.orthogonal() * 10.0, base + toward * 16.0, Color(1.0, 0.32, 0.26, 0.9), 3.0, true)
	if ability == "rally":
		draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 28, Color(0.45, 0.9, 0.35, 0.65), 3.0)
		draw_arc(Vector2.ZERO, 64.0, -0.7, 0.7, 9, Color(1.0, 0.9, 0.25, 0.85), 4.0)
	elif ability == "charge" and fmod(_special_clock, 5.0) > 3.8:
		for offset in [-24.0, 0.0, 24.0]:
			draw_line(Vector2(offset - 14.0, -58.0), Vector2(offset, -92.0), Color(1.0, 0.55, 0.18, 0.75), 4.0)

func _update_special_state() -> void:
	if ability == "rally" and fmod(_special_clock, 1.0) < 0.035:
		for spider in get_tree().get_nodes_in_group("spiders"):
			if spider != self and spider is Node2D and global_position.distance_to(spider.global_position) <= 190.0:
				spider.set("_rally_expires_at", Time.get_ticks_msec() + 1300)
	if ability == "enrage" and health.hit_points <= health.max_hit_points / 2 and rage_texture_a:
		primary_texture = rage_texture_a
		alternate_texture = rage_texture_b
	if ability == "jump":
		var should_jump := fmod(_special_clock, 4.5) > 3.55
		if should_jump != _jumping:
			_jumping = should_jump
			var target_scale := base_sprite_scale * (1.18 if _jumping else 1.0)
			create_tween().tween_property(spider_sprite, "scale", target_scale, 0.12)
	if ability == "hatch" and not _hatched and health.hit_points <= health.max_hit_points / 2:
		_hatched = true
		spider_sprite.texture = archetype_break_texture()
		primary_texture = EnemyRoster.PROFILES[1].walk_a
		alternate_texture = EnemyRoster.PROFILES[1].walk_b
		base_sprite_scale = Vector2.ONE * 0.160
		base_speed *= 2.2
		var timer := get_tree().create_timer(0.18)
		timer.timeout.connect(func() -> void: spider_sprite.texture = primary_texture)

func archetype_break_texture() -> Texture2D:
	for profile in EnemyRoster.PROFILES:
		if String(profile.id) == archetype_id:
			return profile.get("break", primary_texture)
	return primary_texture

func _play_block_effect() -> void:
	var label := Label.new()
	label.text = "BLOCK"
	label.position = position + Vector2(-32, -55)
	label.add_theme_color_override("font_color", Color("ffe07a"))
	label.add_theme_font_size_override("font_size", 16)
	label.z_index = 70
	get_parent().add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.35)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(label.queue_free)

func play_destroyed_effect(bounty: int) -> void:
	if death_texture:
		var death := Sprite2D.new()
		death.texture = death_texture
		death.global_position = global_position
		death.global_rotation = spider_sprite.global_rotation
		death.scale = base_sprite_scale
		death.z_index = 59
		get_tree().current_scene.add_child(death)
		var death_tween := death.create_tween()
		death_tween.tween_property(death, "modulate:a", 0.0, 0.35)
		death_tween.tween_callback(death.queue_free)
	var puff := Sprite2D.new()
	puff.texture = preload("res://assets/sprites/effects/Puff.png")
	puff.global_position = global_position
	puff.scale = Vector2(0.08, 0.08)
	puff.z_index = 60
	get_tree().current_scene.add_child(puff)
	var reward := Label.new()
	reward.text = "+Δ%d" % bounty
	reward.global_position = global_position + Vector2(-28.0, -45.0)
	reward.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32, 1.0))
	reward.add_theme_font_size_override("font_size", 22)
	reward.z_index = 61
	get_tree().current_scene.add_child(reward)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(puff, "scale", Vector2(0.14, 0.14), 0.45)
	tween.tween_property(puff, "modulate:a", 0.0, 0.45)
	tween.tween_property(reward, "position:y", reward.position.y - 38.0, 0.65)
	tween.tween_property(reward, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(puff.queue_free)
	tween.chain().tween_callback(reward.queue_free)
