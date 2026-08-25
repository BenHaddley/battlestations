extends Node2D
class_name Turret
## Standard damage turret. Acquires the first spider overlapping its
## TargetingArea, rotates to face it, fires on a timer. Upgradable in place.

@export var bullet_scene: PackedScene
@export var upgrade_ui: Control

@onready var turret_rotation_point: Node2D = $RotationPoint
@onready var firing_point: Node2D = $RotationPoint/FiringPoint
@onready var targeting_area: Area2D = $TargetingArea
@onready var train_chassis: Sprite2D = $Base

@export_group("Attributes")
@export var targeting_range: float = 5.0
@export var rotation_speed: float = 5.0
@export var bps: float = 1.0 ## bullets per second
@export var base_upgrade_cost: int = 100

@export_group("Rail Patrol")
@export var patrol_speed: float = 95.0

var bps_base: float
var targeting_range_base: float

var target: Node2D = null
var time_until_fire: float = 0.0
var level: int = 1
var patrol_enabled: bool = false
var patrol_path: PackedVector2Array
var patrol_index: int = 0
var patrol_step: int = 1

func _ready() -> void:
	bps_base = bps
	targeting_range_base = targeting_range

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
		if time_until_fire >= 1.0 / bps:
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
		if not is_instance_valid(target):
			# Gun art faces up, unlike the chassis art which faces down.
			turret_rotation_point.rotation = direction.angle() + PI * 0.5

func _shoot() -> void:
	if bullet_scene == null:
		return
	var bullet: Node2D = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = firing_point.global_position
	bullet.set_target(target)

func _find_target() -> Node2D:
	if targeting_area == null:
		return null
	var bodies := targeting_area.get_overlapping_bodies()
	return bodies[0] if bodies.size() > 0 else null

func _target_in_range() -> bool:
	return global_position.distance_to(target.global_position) <= targeting_range

func _rotate_towards_target(delta: float) -> void:
	var to_target: Vector2 = target.global_position - turret_rotation_point.global_position
	var target_angle: float = to_target.angle() + PI / 2.0
	turret_rotation_point.rotation = rotate_toward(turret_rotation_point.rotation, target_angle, rotation_speed * delta)

func open_upgrade_ui() -> void:
	if upgrade_ui:
		upgrade_ui.visible = true

func close_upgrade_ui() -> void:
	if upgrade_ui:
		upgrade_ui.visible = false
	UIManager.set_hovering_state(false)

func upgrade() -> void:
	if _calculate_cost() > LevelManager.currency:
		return

	LevelManager.spend_currency(_calculate_cost())
	level += 1
	bps = _calculate_bps()
	targeting_range = _calculate_range()

	close_upgrade_ui()

func _calculate_cost() -> int:
	return roundi(base_upgrade_cost * pow(level, 0.8))

func _calculate_bps() -> float:
	return bps_base * pow(level, 0.6)

func _calculate_range() -> float:
	return targeting_range_base * pow(level, 0.4)
