extends Node2D
class_name Turret
## Standard damage turret. Acquires the first spider overlapping its
## TargetingArea, rotates to face it, fires on a timer.

@export var bullet_scene: PackedScene

@onready var turret_rotation_point: Node2D = $RotationPoint
@onready var firing_point: Node2D = $RotationPoint/FiringPoint
@onready var train_chassis: Sprite2D = $Base

@export_group("Attributes")
@export var targeting_range: float = 5.0
@export var rotation_speed: float = 5.0
@export var bps: float = 1.0 ## bullets per second
@export var base_projectile_damage: int = 20

@export_group("Rail Patrol")
@export var weight: float = 1.0

@export_group("Directional Prototype")
@export var fixed_direction_enabled := false
@export var fixed_direction_texture: Texture2D
@export var fixed_direction_scale := Vector2(0.17, 0.17)
# Keep acquisition narrower than the combined projectile/spider collision
# radius. A wider corridor makes the gun repeatedly fire convincing-looking
# tracers beside a spider without the physical projectile ever touching it.
@export_range(4.0, 80.0, 1.0) var fixed_line_half_width := 18.0
@export var show_fixed_targeting_line := true

var attack_speed_multiplier: float = 1.0

var target: Node2D = null
var time_until_fire: float = 0.0
var _recoil_tween: Tween
var fixed_direction_facing := 1
var _convoy_direction := Vector2.DOWN
@onready var _fixed_art: Sprite2D = get_node_or_null("FixedDirectionArt") as Sprite2D

func _ready() -> void:
	if fixed_direction_texture and _fixed_art == null:
		_fixed_art = Sprite2D.new()
		_fixed_art.name = "FixedDirectionArt"
		_fixed_art.texture = fixed_direction_texture
		_fixed_art.scale = fixed_direction_scale
		add_child(_fixed_art)
	elif _fixed_art:
		_fixed_art.texture = fixed_direction_texture
		_fixed_art.scale = fixed_direction_scale
	set_fixed_direction_enabled(fixed_direction_enabled)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		target = _find_target()
		# A fixed-direction lane is narrow and its cadence timer can otherwise
		# land well after a spider has already walked through it. Firing the
		# instant something enters the lane guarantees every crossing is
		# actually shot at, instead of only whichever ones happen to overlap
		# the next scheduled burst.
		if is_instance_valid(target) and fixed_direction_enabled:
			_shoot()
			time_until_fire = 0.0
		return

	_rotate_towards_target(delta)

	if not _target_in_range():
		target = null
	else:
		time_until_fire += delta
		if time_until_fire >= 1.0 / (bps * attack_speed_multiplier):
			_shoot()
			time_until_fire = 0.0

func set_convoy_transform(world_position: Vector2, direction: Vector2) -> void:
	global_position = world_position
	if not direction.is_zero_approx():
		_convoy_direction = direction.normalized()
	_face_direction(direction)

func _face_direction(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		# Chassis art faces down in its source image.
		var travel_rotation := direction.angle() - PI * 0.5
		train_chassis.rotation = travel_rotation
		# The base is almost symmetrical, so align the gun with the chassis while
		# idle to make the cart's travel direction visually unambiguous.
		if fixed_direction_enabled:
			var fire_direction := _fixed_fire_direction()
			turret_rotation_point.rotation = fire_direction.angle() + PI * 0.5
			if _fixed_art:
				_fixed_art.rotation = direction.angle() - PI * 0.5
				_fixed_art.flip_h = fixed_direction_facing < 0
		elif not is_instance_valid(target):
			# Gun art faces up, unlike the chassis art which faces down.
			turret_rotation_point.rotation = direction.angle() + PI * 0.5
		queue_redraw()

## Keep train support separate from any per-car modifier so removing a
## Brake Van restores exactly the car's own damage.
func damage_multiplier() -> float:
	return float(get_meta("damage_multiplier", 1.0)) * float(get_meta("train_damage_multiplier", 1.0))

func _shoot() -> void:
	if bullet_scene == null:
		return
	AudioFX.play(_shoot_sound(), _shoot_volume_db())
	_play_recoil(6.0)
	var bullet: Node2D = bullet_scene.instantiate()
	if bullet.get("bullet_damage") != null:
		bullet.set("bullet_damage", maxi(1, int(round(float(base_projectile_damage) * damage_multiplier()))))
	if bullet is CoalCannonball:
		bullet.direct_damage = maxi(1, roundi(bullet.direct_damage * damage_multiplier()))
		bullet.splash_damage = maxi(1, roundi(bullet.splash_damage * damage_multiplier()))
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = firing_point.global_position
	if fixed_direction_enabled and bullet.has_method("set_direction"):
		bullet.set_direction(_fixed_fire_direction())
	else:
		bullet.set_target(target)
	var tracer := preload("res://scripts/comic_tracer.gd").new()
	get_tree().current_scene.add_child(tracer)
	tracer.configure(firing_point.global_position, target.global_position)
	var flash := Sprite2D.new()
	flash.texture = preload("res://assets/sprites/effects/hit effect.png")
	flash.global_position = firing_point.global_position
	flash.scale = Vector2(0.035, 0.035)
	flash.modulate = Color(1.0, 0.72, 0.2, 0.9)
	flash.z_index = 65
	get_tree().current_scene.add_child(flash)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(0.075, 0.075), 0.12)
	tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(flash.queue_free)

func _play_recoil(distance: float) -> void:
	if turret_rotation_point == null:
		return
	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()
	turret_rotation_point.position = Vector2(0.0, distance)
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(turret_rotation_point, "position", Vector2.ZERO, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _shoot_sound() -> AudioStream:
	return preload("res://assets/audio/sfx/turret_shoot_gunner.wav")

func _shoot_volume_db() -> float:
	return -6.0

## Workbook priority "Close": the nearest live spider inside targeting_range.
## Measured directly rather than through the physics area so the range a
## player sees previewed is exactly the range the gun acquires at — the
## placed car's root scale used to shrink the area to about half its size.
func _find_target() -> Node2D:
	if not fixed_direction_enabled:
		var nearest: Node2D = null
		var nearest_distance := targeting_range * targeting_range
		for candidate in get_tree().get_nodes_in_group("spiders"):
			var spider := candidate as Node2D
			if spider == null or not is_instance_valid(spider) or spider.is_queued_for_deletion():
				continue
			var spider_health := spider.get_node_or_null("Health") as Health
			if spider_health != null and spider_health.is_destroyed:
				continue
			if spider.has_method("protected_by_egg") and spider.protected_by_egg(global_position, targeting_range):
				continue
			var distance := global_position.distance_squared_to(spider.global_position)
			if distance <= nearest_distance:
				nearest_distance = distance
				nearest = spider
		return nearest
	# Fixed guns use every live spider on the board, then reduce that set to a
	# narrow forward corridor. Distance is deliberately not part of selection.
	var nearest: Node2D = null
	var nearest_forward := INF
	for candidate in get_tree().get_nodes_in_group("spiders"):
		var candidate_node := candidate as Node2D
		if candidate_node != null and _is_in_fixed_firing_line(candidate_node):
			var forward: float = (candidate_node.global_position - global_position).dot(_fixed_fire_direction())
			if forward < nearest_forward:
				nearest_forward = forward
				nearest = candidate_node
	return nearest

func _target_in_range() -> bool:
	if target.has_method("protected_by_egg") and target.protected_by_egg(global_position, targeting_range):
		return false
	if fixed_direction_enabled:
		return _is_in_fixed_firing_line(target)
	return global_position.distance_to(target.global_position) <= targeting_range

## Every live spider inside targeting_range, for area weapons.
func _spiders_in_range() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("spiders"):
		var spider := candidate as Node2D
		if spider == null or not is_instance_valid(spider) or spider.is_queued_for_deletion():
			continue
		if global_position.distance_to(spider.global_position) <= targeting_range:
			result.append(spider)
	return result

func _rotate_towards_target(delta: float) -> void:
	if fixed_direction_enabled:
		return
	var to_target: Vector2 = target.global_position - turret_rotation_point.global_position
	var target_angle: float = to_target.angle() + PI / 2.0
	turret_rotation_point.rotation = rotate_toward(turret_rotation_point.rotation, target_angle, rotation_speed * delta)

func set_fixed_facing(facing: int) -> void:
	fixed_direction_facing = -1 if facing < 0 else 1
	_face_direction(_convoy_direction)

func set_fixed_direction_enabled(enabled: bool) -> void:
	fixed_direction_enabled = enabled and fixed_direction_texture != null
	train_chassis.visible = not fixed_direction_enabled
	turret_rotation_point.get_node("Top").visible = not fixed_direction_enabled
	if _fixed_art:
		_fixed_art.visible = fixed_direction_enabled
	_face_direction(_convoy_direction)
	queue_redraw()

func _fixed_fire_direction() -> Vector2:
	# The static artwork's unflipped barrel points screen-right while its car
	# chassis points down. In Godot's Y-down coordinates, train-relative right
	# is a negative quarter-turn from the direction of travel.
	return _convoy_direction.rotated(float(fixed_direction_facing) * -PI * 0.5).normalized()

func _is_in_fixed_firing_line(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate):
		return false
	var offset := candidate.global_position - firing_point.global_position
	var direction := _fixed_fire_direction()
	var forward := offset.dot(direction)
	var sideways := absf(offset.dot(direction.orthogonal()))
	return forward > 0.0 and sideways <= fixed_line_half_width

func _draw() -> void:
	if not fixed_direction_enabled or not show_fixed_targeting_line:
		return
	var direction := _fixed_fire_direction()
	var distance := _distance_to_viewport_edge(direction)
	var global_start := firing_point.global_position
	draw_line(to_local(global_start), to_local(global_start + direction * distance), Color(0.28, 1.0, 0.68, 0.42), 2.0, true)

func _distance_to_viewport_edge(direction: Vector2) -> float:
	var size := get_viewport_rect().size
	var origin := firing_point.global_position
	var distances: Array[float] = []
	if direction.x > 0.001:
		distances.append((size.x - origin.x) / direction.x)
	elif direction.x < -0.001:
		distances.append((0.0 - origin.x) / direction.x)
	if direction.y > 0.001:
		distances.append((size.y - origin.y) / direction.y)
	elif direction.y < -0.001:
		distances.append((0.0 - origin.y) / direction.y)
	var result := 1600.0
	for value in distances:
		if value >= 0.0:
			result = minf(result, value)
	return result
