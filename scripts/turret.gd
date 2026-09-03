extends Node2D
class_name Turret
## Standard damage turret. Acquires the first spider overlapping its
## TargetingArea, rotates to face it, fires on a timer.

@export var bullet_scene: PackedScene

@onready var turret_rotation_point: Node2D = $RotationPoint
@onready var firing_point: Node2D = $RotationPoint/FiringPoint
@onready var targeting_area: Area2D = $TargetingArea
@onready var train_chassis: Sprite2D = $Base

@export_group("Attributes")
@export var targeting_range: float = 5.0
@export var rotation_speed: float = 5.0
@export var bps: float = 1.0 ## bullets per second

@export_group("Rail Patrol")
@export var patrol_speed: float = 95.0
@export var weight: float = 1.0

@export_group("Directional Prototype")
@export var fixed_direction_enabled := false
@export var fixed_direction_texture: Texture2D
@export var fixed_direction_scale := Vector2(0.17, 0.17)

var attack_speed_multiplier: float = 1.0

var target: Node2D = null
var time_until_fire: float = 0.0
var patrol_enabled: bool = false
var patrol_path: PackedVector2Array
var patrol_index: int = 0
var patrol_step: int = 1
var _recoil_tween: Tween
var fixed_direction_facing := 1
var _convoy_direction := Vector2.DOWN
var _fixed_art: Sprite2D

func _ready() -> void:
	if fixed_direction_texture:
		_fixed_art = Sprite2D.new()
		_fixed_art.name = "FixedDirectionArt"
		_fixed_art.texture = fixed_direction_texture
		_fixed_art.scale = fixed_direction_scale
		add_child(_fixed_art)
	set_fixed_direction_enabled(fixed_direction_enabled)

func _process(delta: float) -> void:
	_patrol_track(delta)
	if not is_instance_valid(target):
		target = _find_target()
		return

	_rotate_towards_target(delta)

	if not _target_in_range():
		target = null
	else:
		time_until_fire += delta
		if time_until_fire >= 1.0 / (bps * attack_speed_multiplier):
			_shoot()
			time_until_fire = 0.0

func configure_track(track_path: PackedVector2Array, start_index: int) -> void:
	patrol_path = track_path.duplicate()
	if patrol_path.is_empty():
		return
	patrol_index = clampi(start_index, 0, patrol_path.size() - 1)
	global_position = patrol_path[patrol_index]
	patrol_step = -1 if patrol_index == patrol_path.size() - 1 else 1
	patrol_enabled = patrol_path.size() > 1
	if patrol_enabled:
		_face_direction(patrol_path[patrol_index + patrol_step] - global_position)

func set_convoy_transform(world_position: Vector2, direction: Vector2) -> void:
	patrol_enabled = false
	global_position = world_position
	if not direction.is_zero_approx():
		_convoy_direction = direction.normalized()
	_face_direction(direction)

func _patrol_track(delta: float) -> void:
	if not patrol_enabled:
		return
	var target_index := patrol_index + patrol_step
	if target_index < 0 or target_index >= patrol_path.size():
		patrol_step *= -1
		target_index = patrol_index + patrol_step
	var target_point := patrol_path[target_index]
	_face_direction(target_point - global_position)
	var travel := patrol_speed * delta
	if global_position.distance_to(target_point) <= travel:
		global_position = target_point
		patrol_index = target_index
	else:
		global_position = global_position.move_toward(target_point, travel)

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

func _shoot() -> void:
	if bullet_scene == null:
		return
	AudioFX.play(_shoot_sound(), _shoot_volume_db())
	_play_recoil(6.0)
	var bullet: Node2D = bullet_scene.instantiate()
	if bullet.get("bullet_damage") != null:
		bullet.set("bullet_damage", maxi(1, int(round(float(bullet.get("bullet_damage")) * float(get_meta("damage_multiplier", 1.0))))))
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = firing_point.global_position
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

func _find_target() -> Node2D:
	if targeting_area == null:
		return null
	var bodies := targeting_area.get_overlapping_bodies()
	if not fixed_direction_enabled:
		return bodies[0] if bodies.size() > 0 else null
	for body in bodies:
		if _is_in_fixed_firing_side(body):
			return body
	return null

func _target_in_range() -> bool:
	return global_position.distance_to(target.global_position) <= targeting_range and (not fixed_direction_enabled or _is_in_fixed_firing_side(target))

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

func _fixed_fire_direction() -> Vector2:
	# The static artwork's unflipped barrel points screen-right while its car
	# chassis points down. In Godot's Y-down coordinates, train-relative right
	# is a negative quarter-turn from the direction of travel.
	return _convoy_direction.rotated(float(fixed_direction_facing) * -PI * 0.5).normalized()

func _is_in_fixed_firing_side(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate):
		return false
	var to_candidate := global_position.direction_to(candidate.global_position)
	return to_candidate.dot(_fixed_fire_direction()) > 0.15
