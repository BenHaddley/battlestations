extends Control
## Hand-drawn double-chevron "fast forward" icon that continuously animates
## in place — Godot flattens any imported GIF to its first frame on import,
## so genuine motion here has to be drawn live rather than played back.

@export var ink_color: Color = Color(0.06, 0.32, 0.27, 1)
@export var speed: float = 1.7

var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta * speed
	queue_redraw()

func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var random := RandomNumberGenerator.new()
	random.seed = hash(get_path())
	var w := size.x
	var h := size.y
	var chevron_w := w * 0.3
	var chevron_h := h * 0.6
	var cy := h * 0.5
	for i in range(3):
		var base_x := w * 0.1 + i * chevron_w * 0.8
		var pulse := fmod(_time + i * 0.34, 1.0)
		var alpha := 0.3 + 0.7 * sin(pulse * PI)
		var jx := random.randf_range(-1.5, 1.5)
		var jy := random.randf_range(-1.5, 1.5)
		var top := Vector2(base_x + jx, cy - chevron_h * 0.5 + jy)
		var tip := Vector2(base_x + chevron_w + jx, cy + jy)
		var bottom := Vector2(base_x + jx, cy + chevron_h * 0.5 + jy)
		var poly := PackedVector2Array([top, tip, bottom])
		draw_colored_polygon(poly, Color(ink_color.r, ink_color.g, ink_color.b, alpha))
		draw_polyline(poly + PackedVector2Array([top]), Color(0.04, 0.04, 0.03, alpha), 2.4, true)
