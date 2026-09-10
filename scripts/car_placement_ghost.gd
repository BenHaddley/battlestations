extends Node2D
## Track-snapped placement preview. It shows the exact next-car transform,
## the car's real attack radius when it has one, and, for fixed guns, an
## arrow matching the side their targeting code will use.

const ART_SCALE := Vector2(0.0918, 0.0918) # scene 0.17 × placed root 0.54
const VALID_COLOR := Color(0.30, 1.0, 0.70, 0.92)
const RANGE_COLOR := Color(1.0, 0.86, 0.42, 0.75)

var _art: Sprite2D
var _top: Sprite2D
var _fire_direction := Vector2.RIGHT
var _directional := false
var _range_radius := 0.0

func _ready() -> void:
	z_index = 190
	_art = Sprite2D.new()
	_art.modulate = Color(1.0, 1.0, 1.0, 0.82)
	add_child(_art)
	_top = Sprite2D.new()
	_top.modulate = Color(1.0, 1.0, 1.0, 0.82)
	add_child(_top)

## `art` comes from CarArt.for_tower(): chassis/turret textures and scales
## matching the placed car, plus its attack radius (0 for utility cars).
func configure(art: Dictionary, world_position: Vector2, travel_direction: Vector2, facing: int, directional: bool) -> void:
	global_position = world_position
	var chassis_rotation := travel_direction.angle() - PI * 0.5
	_art.texture = art.get("base")
	_art.scale = Vector2(art.get("base_scale", ART_SCALE))
	_art.rotation = chassis_rotation + float(art.get("base_rotation", 0.0))
	_art.flip_h = facing < 0
	_top.texture = art.get("top")
	_top.visible = _top.texture != null
	_top.scale = Vector2(art.get("top_scale", ART_SCALE))
	# Turret art faces up while chassis art faces down: idle guns point along
	# the direction of travel, exactly as a freshly coupled car does.
	_top.rotation = travel_direction.angle() + PI * 0.5 + float(art.get("top_rotation", 0.0))
	_range_radius = float(art.get("range", 0.0))
	_directional = directional
	_fire_direction = travel_direction.rotated(float(-1 if facing >= 0 else 1) * PI * 0.5).normalized()
	queue_redraw()

func range_radius() -> float:
	return _range_radius

func _draw() -> void:
	if _range_radius > 0.0:
		draw_circle(Vector2.ZERO, _range_radius, Color(1.0, 0.86, 0.42, 0.07))
		draw_arc(Vector2.ZERO, _range_radius, 0.0, TAU, 64, Color(0.06, 0.04, 0.02, 0.55), 5.0, true)
		draw_arc(Vector2.ZERO, _range_radius, 0.0, TAU, 64, RANGE_COLOR, 2.5, true)
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
