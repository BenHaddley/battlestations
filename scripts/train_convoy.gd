extends Node2D
class_name TrainConvoy
## The always-present locomotive leads one train. Cars sample its movement
## history at increasing distances, producing Snake-like following at turns.

@export var speed: float = 95.0
@export var car_spacing: float = 100.0
@export var attachment_radius: float = 115.0
@export var smoke_texture: Texture2D

@onready var engine: Sprite2D = $Engine

var path: PackedVector2Array
var path_index: int = 0
var path_step: int = 1
var followers: Array[Node2D] = []
var history: Array[Dictionary] = []
var smoke_timer: float = 0.0

func configure_path(track_path: PackedVector2Array) -> void:
	path = track_path.duplicate()
	if path.is_empty():
		return
	path_index = 0
	path_step = 1
	global_position = path[0]
	var direction := path[1] - path[0] if path.size() > 1 else Vector2.DOWN
	_face_engine(direction)
	history = [{"position": global_position, "direction": direction.normalized()}]

func _process(delta: float) -> void:
	if path.size() < 2:
		return
	var remaining := speed * delta
	while remaining > 0.0:
		var target_index := path_index + path_step
		if target_index < 0 or target_index >= path.size():
			path_step *= -1
			target_index = path_index + path_step
		var target_point := path[target_index]
		var distance := global_position.distance_to(target_point)
		var direction := (target_point - global_position).normalized()
		_face_engine(direction)
		if distance <= remaining:
			global_position = target_point
			path_index = target_index
			remaining -= distance
		else:
			global_position += direction * remaining
			remaining = 0.0
	_record_history()
	_update_followers()
	smoke_timer -= delta
	if smoke_timer <= 0.0:
		_emit_smoke()
		smoke_timer = 0.32
	queue_redraw()

func attach_car(car: Node2D) -> void:
	followers.append(car)
	_update_followers()

func can_attach_at(world_position: Vector2) -> bool:
	if world_position.distance_to(global_position) <= attachment_radius:
		return true
	for car in followers:
		if is_instance_valid(car) and world_position.distance_to(car.global_position) <= attachment_radius:
			return true
	return false

func set_drag_active(active: bool) -> void:
	var tint := Color(1.0, 0.85, 0.35, 1.0) if active else Color.WHITE
	engine.modulate = tint
	for car in followers:
		if is_instance_valid(car):
			car.modulate = tint

func car_count() -> int:
	return followers.size()

func _draw() -> void:
	var previous := Vector2.ZERO
	for car in followers:
		if not is_instance_valid(car):
			continue
		var car_local := to_local(car.global_position)
		draw_line(previous, car_local, Color(0.12, 0.1, 0.07, 0.9), 9.0)
		draw_circle(previous.lerp(car_local, 0.5), 7.0, Color(0.72, 0.48, 0.18, 1.0))
		previous = car_local

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
		# Steam-engine artwork faces down in the source image.
		engine.rotation = direction.angle() - PI * 0.5

func _record_history() -> void:
	var direction := Vector2.DOWN
	if not history.is_empty():
		direction = (global_position - history[0].position).normalized()
	if direction.is_zero_approx():
		direction = history[0].direction if not history.is_empty() else Vector2.DOWN
	history.push_front({"position": global_position, "direction": direction})
	var maximum_samples := ceili((followers.size() + 2) * car_spacing / 2.0) + 120
	if history.size() > maximum_samples:
		history.resize(maximum_samples)

func _update_followers() -> void:
	for index in range(followers.size()):
		var car := followers[index]
		if not is_instance_valid(car):
			continue
		var sample := _sample_history(car_spacing * (index + 1))
		if car.has_method("set_convoy_transform"):
			car.set_convoy_transform(sample.position, sample.direction)
		else:
			car.global_position = sample.position

func _sample_history(distance_behind: float) -> Dictionary:
	if history.is_empty():
		return {"position": global_position, "direction": Vector2.DOWN}
	var travelled := 0.0
	for index in range(history.size() - 1):
		var newer: Vector2 = history[index].position
		var older: Vector2 = history[index + 1].position
		var segment := newer.distance_to(older)
		if travelled + segment >= distance_behind and segment > 0.0:
			var weight := (distance_behind - travelled) / segment
			return {
				"position": newer.lerp(older, weight),
				"direction": history[index + 1].direction,
			}
		travelled += segment
	return history[-1]
