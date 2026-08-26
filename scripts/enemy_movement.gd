extends CharacterBody2D
class_name EnemyMovement
## Walks a spider straight down its assigned courtyard lane. Reaching the
## bottom is a leak (no base-health system exists yet) — see wiki.

@export var move_speed: float = 1.0
@export var alternate_texture: Texture2D

@onready var health: Health = $Health
@onready var spider_sprite: Sprite2D = $Sprite2D

var health_dots: SpiderHealthDots
var base_speed: float
var leak_y: float = 720.0
var lane_configured: bool = false
var primary_texture: Texture2D
var animation_time: float = 0.0
var base_sprite_scale: Vector2

## Absolute ms timestamp (Time.get_ticks_msec()) the current slow expires at.
## Tracking an expiry rather than a bool means a second overlapping pulse can
## only extend the slow, never cut a longer one short.
var _slow_expires_at: int = 0

func _ready() -> void:
	base_speed = move_speed
	base_sprite_scale = spider_sprite.scale
	primary_texture = spider_sprite.texture
	health_dots = SpiderHealthDots.new()
	spider_sprite.add_child(health_dots)
	health_dots.stage_changed.connect(_on_health_stage_changed)
	health.hit_points_changed.connect(health_dots.set_hit_points)
	health_dots.set_hit_points(health.hit_points, health.max_hit_points)

func configure_lane(destination_y: float, journey_duration_seconds: float = 25.0) -> void:
	leak_y = destination_y
	# Define pacing as travel time rather than fragile world-units/second. A
	# larger replacement board can move the spawn or station while preserving
	# the intended 20–30 second unslowed journey.
	if journey_duration_seconds > 0.0:
		base_speed = absf(leak_y - global_position.y) / journey_duration_seconds
	lane_configured = true

func _on_health_stage_changed(_previous_dots: int, current_dots: int) -> void:
	if current_dots <= 0:
		return
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

func _physics_process(delta: float) -> void:
	if not lane_configured:
		return
	if global_position.y >= leak_y:
		GameEvents.enemy_destroyed.emit()
		GameEvents.enemy_leaked.emit()
		queue_free()
		return
	var speed: float = base_speed * 0.5 if Time.get_ticks_msec() < _slow_expires_at else base_speed
	velocity = Vector2.DOWN * speed
	move_and_slide()
	animation_time += delta
	if alternate_texture and animation_time >= 0.16:
		spider_sprite.texture = alternate_texture if spider_sprite.texture == primary_texture else primary_texture
		animation_time = 0.0

## Slows the enemy to half its base speed for `duration` seconds. Safe to
## call while already slowed — only extends the effect, never shortens it.
func apply_slow(duration: float) -> void:
	_slow_expires_at = max(_slow_expires_at, Time.get_ticks_msec() + int(duration * 1000.0))

func take_damage(dmg: int) -> void:
	spider_sprite.modulate = Color(1.0, 0.32, 0.2, 1.0)
	var tween := create_tween()
	tween.tween_property(spider_sprite, "modulate", Color.WHITE, 0.12)
	health.take_damage(dmg)

func play_destroyed_effect(bounty: int) -> void:
	var puff := Sprite2D.new()
	puff.texture = preload("res://assets/sprites/effects/Puff.png")
	puff.global_position = global_position
	puff.scale = Vector2(0.08, 0.08)
	puff.z_index = 60
	get_tree().current_scene.add_child(puff)
	var reward := Label.new()
	reward.text = "+$%d" % bounty
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
