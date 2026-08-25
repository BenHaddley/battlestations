extends Node2D
class_name TurretSlomo
## Crowd-control turret. Deals no damage — pulses its TargetingArea on a
## timer and halves the speed of everything caught inside for a fixed time.

@onready var targeting_area: Area2D = $TargetingArea
@onready var train_chassis: Sprite2D = $Sprite2D

@export_group("Attributes")
@export var targeting_range: float = 5.0
@export var aps: float = 0.25 ## pulses per second
@export var freeze_time: float = 1.0
@export var patrol_speed: float = 80.0

var time_until_fire: float = 0.0
var patrol_enabled: bool = false
var patrol_path: PackedVector2Array
var patrol_index: int = 0
var patrol_step: int = 1

func _process(delta: float) -> void:
	_patrol_track(delta)
	time_until_fire += delta
	if time_until_fire >= 1.0 / aps:
		_freeze_enemies()
		time_until_fire = 0.0

func _freeze_enemies() -> void:
	for body in targeting_area.get_overlapping_bodies():
		if body.has_method("apply_slow"):
			body.apply_slow(freeze_time)
	var pulse := Sprite2D.new()
	pulse.texture = preload("res://assets/sprites/effects/Puff.png")
	pulse.global_position = global_position
	pulse.scale = Vector2(0.06, 0.06)
	pulse.modulate = Color(0.4, 0.95, 1.0, 0.48)
	pulse.z_index = 40
	get_tree().current_scene.add_child(pulse)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(pulse, "scale", Vector2(0.36, 0.36), 0.5)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(pulse.queue_free)

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
		# Locomotive art faces down (toward its cowcatcher) in the source image.
		train_chassis.rotation = direction.angle() - PI * 0.5
