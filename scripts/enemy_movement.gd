extends CharacterBody2D
class_name EnemyMovement
## Walks a spider straight down its assigned courtyard lane. Reaching the
## bottom is a leak (no base-health system exists yet) — see wiki.

@export var move_speed: float = 1.0
@export var alternate_texture: Texture2D

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

## Absolute ms timestamp (Time.get_ticks_msec()) the current slow expires at.
## Tracking an expiry rather than a bool means a second overlapping pulse can
## only extend the slow, never cut a longer one short.
var _slow_expires_at: int = 0

func _ready() -> void:
	add_to_group("spiders")
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
	# Define pacing as travel time rather than fragile world-units/second. A
	# larger replacement board can move the spawn or station while preserving
	# the intended 20–30 second unslowed journey.
	if journey_duration_seconds > 0.0:
		base_speed = absf(leak_y - global_position.y) / journey_duration_seconds * speed_multiplier
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
	if global_position.y >= leak_y:
		GameEvents.enemy_destroyed.emit()
		GameEvents.enemy_leaked.emit()
		queue_free()
		return
	_special_clock += delta
	_update_special_state()
	var speed: float = base_speed
	if Time.get_ticks_msec() < _slow_expires_at:
		speed *= 0.5
	if Time.get_ticks_msec() < _rally_expires_at:
		speed *= 1.25
	if ability == "charge" and fmod(_special_clock, 5.0) > 3.8:
		speed *= 2.1
	if ability == "enrage" and health.hit_points <= health.max_hit_points / 2:
		speed *= 1.55
	if ability == "jump" and _jumping:
		speed *= 1.8
	velocity = Vector2.DOWN * speed
	move_and_slide()
	queue_redraw()
	animation_time += delta
	if alternate_texture and animation_time >= 0.16:
		spider_sprite.texture = alternate_texture if spider_sprite.texture == primary_texture else primary_texture
		animation_time = 0.0

## Slows the enemy to half its base speed for `duration` seconds. Safe to
## call while already slowed — only extends the effect, never shortens it.
func apply_slow(duration: float) -> void:
	_slow_expires_at = max(_slow_expires_at, Time.get_ticks_msec() + int(duration * 1000.0))

func take_damage(dmg: int) -> void:
	if ability == "armor":
		_armored_hit_counter += 1
		if _armored_hit_counter % 3 == 0:
			_play_block_effect()
			return
	if ability == "jump" and _jumping:
		_play_block_effect()
		return
	spider_sprite.modulate = Color(1.0, 0.32, 0.2, 1.0)
	var tween := create_tween()
	tween.tween_property(spider_sprite, "modulate", Color.WHITE, 0.12)
	health.take_damage(dmg)

func _draw() -> void:
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
