extends Node2D
class_name UnitHealth
## Hit points for a train unit (engine or car). Lives as a child of the unit
## but draws in screen orientation, so the health bar and bite marker never
## rotate with the chassis. Damage arrives in fractional DPS ticks from
## biting spiders and in whole hits from ramming, so hit points are floats.

signal damaged(current: float, maximum: float)
signal destroyed(unit: Node2D)

const BREAK_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/effects/BREAK 1.png"),
	preload("res://assets/sprites/effects/BREAK 2.png"),
	preload("res://assets/sprites/effects/BREAK 3.png"),
	preload("res://assets/sprites/effects/BREAK 4.png"),
	preload("res://assets/sprites/effects/BREAK 5.png"),
]
const FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")

var max_hit_points: float = 200.0
var hit_points: float = 200.0
var is_destroyed := false
var unit_label := "UNIT"
## Milliseconds of the most recent bite, so the marker fades on its own.
var _last_bite_ms: int = -100000
var _flash_tween: Tween

## Installs a health node on `unit` (idempotent) and returns it.
static func attach_to(unit: Node2D, maximum: float, label: String = "") -> UnitHealth:
	var existing := unit.get_node_or_null("UnitHealth") as UnitHealth
	if existing:
		existing.configure(maximum, label if not label.is_empty() else existing.unit_label)
		return existing
	var health := UnitHealth.new()
	health.name = "UnitHealth"
	health.configure(maximum, label if not label.is_empty() else String(unit.name))
	unit.add_child(health)
	return health

static func of(unit: Node) -> UnitHealth:
	if unit == null or not is_instance_valid(unit):
		return null
	return unit.get_node_or_null("UnitHealth") as UnitHealth

func _ready() -> void:
	top_level = true
	z_index = 80

func configure(maximum: float, label: String) -> void:
	max_hit_points = maxf(maximum, 1.0)
	hit_points = max_hit_points
	unit_label = label
	is_destroyed = false
	queue_redraw()

func _process(_delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	global_position = parent.global_position
	global_rotation = 0.0
	global_scale = Vector2.ONE
	queue_redraw()

func fraction() -> float:
	return clampf(hit_points / max_hit_points, 0.0, 1.0)

func is_damaged() -> bool:
	return hit_points < max_hit_points - 0.01

## `bite` marks damage from a spider's jaws so the unit being chewed on is
## identifiable at a glance; ramming and future weapons pass false.
func take_damage(amount: float, bite: bool = false) -> void:
	if is_destroyed or amount <= 0.0:
		return
	hit_points = maxf(0.0, hit_points - amount)
	if bite:
		var first_bite := Time.get_ticks_msec() - _last_bite_ms > 1500
		_last_bite_ms = Time.get_ticks_msec()
		if first_bite and get_parent() is Node2D:
			GameEvents.train_unit_bitten.emit(get_parent() as Node2D)
	_flash_parent()
	damaged.emit(hit_points, max_hit_points)
	if hit_points <= 0.0:
		is_destroyed = true
		var unit := get_parent() as Node2D
		if unit:
			play_destruction(unit.global_position, unit.get_tree().current_scene, unit_label)
		destroyed.emit(unit)

func repair_fully() -> void:
	hit_points = max_hit_points
	is_destroyed = false
	damaged.emit(hit_points, max_hit_points)
	queue_redraw()

func _flash_parent() -> void:
	var parent := get_parent() as CanvasItem
	if parent == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	parent.modulate = Color(1.6, 0.55, 0.45, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(parent, "modulate", Color.WHITE, 0.16)

func _draw() -> void:
	if is_destroyed:
		return
	var recently_bitten := Time.get_ticks_msec() - _last_bite_ms < 450
	if not is_damaged() and not recently_bitten:
		return
	# Bar sits just below the unit's footprint, in screen space.
	var width := 44.0
	var bar := Rect2(Vector2(-width * 0.5, 30.0), Vector2(width, 7.0))
	draw_rect(bar.grow(2.0), Color(0.06, 0.04, 0.03, 0.9), true)
	draw_rect(bar, Color(0.24, 0.16, 0.12, 1.0), true)
	var fill := fraction()
	var color := Color(0.35, 0.85, 0.45, 1.0).lerp(Color(0.92, 0.22, 0.16, 1.0), 1.0 - fill)
	draw_rect(Rect2(bar.position, Vector2(width * fill, bar.size.y)), color, true)
	if recently_bitten:
		# Jaws marker: two red fangs above the unit, pulsing while chewed on.
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 70.0)
		var top := Vector2(0.0, -36.0)
		draw_circle(top, 11.0 * pulse, Color(0.1, 0.03, 0.02, 0.85))
		draw_colored_polygon(PackedVector2Array([top + Vector2(-9, -6) * pulse, top + Vector2(-3, -6) * pulse, top + Vector2(-6, 6) * pulse]), Color(1.0, 0.32, 0.26, 1.0))
		draw_colored_polygon(PackedVector2Array([top + Vector2(3, -6) * pulse, top + Vector2(9, -6) * pulse, top + Vector2(6, 6) * pulse]), Color(1.0, 0.32, 0.26, 1.0))
		draw_arc(top, 11.0 * pulse, 0.0, TAU, 20, Color(1.0, 0.42, 0.34, 0.9), 2.0, true)

## Debris burst plus a caption so a lost car or engine is never silent.
static func play_destruction(at: Vector2, parent: Node, label: String) -> void:
	if parent == null:
		return
	var debris := Sprite2D.new()
	debris.texture = BREAK_FRAMES[0]
	debris.global_position = at
	debris.scale = Vector2(0.07, 0.07)
	debris.z_index = 85
	debris.modulate = Color(0.95, 0.85, 0.7, 1.0)
	parent.add_child(debris)
	var tween := debris.create_tween()
	for frame_index in range(1, BREAK_FRAMES.size()):
		tween.tween_interval(0.07)
		tween.tween_callback(func() -> void: debris.texture = BREAK_FRAMES[frame_index])
	tween.parallel().tween_property(debris, "scale", Vector2(0.13, 0.13), 0.42)
	tween.tween_property(debris, "modulate:a", 0.0, 0.25)
	tween.tween_callback(debris.queue_free)
	var caption := Label.new()
	caption.text = "%s DESTROYED" % label.to_upper()
	caption.add_theme_font_override("font", FONT)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color("ffd9c2"))
	caption.add_theme_color_override("font_outline_color", Color("2b0d09"))
	caption.add_theme_constant_override("outline_size", 5)
	caption.global_position = at + Vector2(-70.0, -70.0)
	caption.z_index = 86
	parent.add_child(caption)
	var caption_tween := caption.create_tween().set_parallel(true)
	caption_tween.tween_property(caption, "position:y", caption.position.y - 30.0, 1.1)
	caption_tween.tween_property(caption, "modulate:a", 0.0, 1.1)
	caption_tween.chain().tween_callback(caption.queue_free)
