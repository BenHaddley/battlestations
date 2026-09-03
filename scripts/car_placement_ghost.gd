extends Node2D
## Track-snapped placement preview. It shows the exact next-car transform and,
## for fixed guns, an arrow matching the side their targeting code will use.

const ART_SCALE := Vector2(0.0918, 0.0918) # scene 0.17 × placed root 0.54
const VALID_COLOR := Color(0.30, 1.0, 0.70, 0.92)

var _art: Sprite2D
var _fire_direction := Vector2.RIGHT
var _directional := false

func _ready() -> void:
	z_index = 190
	_art = Sprite2D.new()
	_art.modulate = Color(1.0, 1.0, 1.0, 0.82)
	add_child(_art)

func configure(texture: Texture2D, world_position: Vector2, travel_direction: Vector2, facing: int, directional: bool) -> void:
	global_position = world_position
	_art.texture = texture
	_art.scale = ART_SCALE
	_art.rotation = travel_direction.angle() - PI * 0.5
	_art.flip_h = facing < 0
	_directional = directional
	_fire_direction = travel_direction.rotated(float(-1 if facing >= 0 else 1) * PI * 0.5).normalized()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 58.0, Color(0.05, 0.20, 0.14, 0.24))
	draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 48, VALID_COLOR, 5.0, true)
	if not _directional:
		return
	var start := _fire_direction * 34.0
	var finish := _fire_direction * 92.0
	draw_line(start, finish, VALID_COLOR, 8.0, true)
	var side := _fire_direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		finish + _fire_direction * 12.0,
		finish - _fire_direction * 10.0 + side * 11.0,
		finish - _fire_direction * 10.0 - side * 11.0,
	]), VALID_COLOR)
