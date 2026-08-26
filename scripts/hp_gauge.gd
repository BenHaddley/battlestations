extends Control
class_name HpGauge
## Smooth vector health track. The label and heart remain separate controls,
## so no UI artwork is stretched as the panel changes size.

var displayed_fraction: float = 1.0
var target_fraction: float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_fraction(value: float) -> void:
	target_fraction = clampf(value, 0.0, 1.0)
	set_process(true)

func _process(delta: float) -> void:
	displayed_fraction = move_toward(displayed_fraction, target_fraction, delta * 0.85)
	queue_redraw()
	if is_equal_approx(displayed_fraction, target_fraction):
		set_process(false)

func _draw() -> void:
	var track := Rect2(7.0, 5.0, size.x - 14.0, size.y - 10.0)
	draw_style_box(_track_box(), track)
	var inner := track.grow(-7.0)
	draw_rect(inner, Color(0.12, 0.09, 0.065, 1.0), true)
	var fill_height := inner.size.y * displayed_fraction
	if fill_height <= 1.0:
		return
	var fill := Rect2(inner.position.x + 2.0, inner.end.y - fill_height, inner.size.x - 4.0, fill_height)
	draw_rect(fill, Color(0.82, 0.16, 0.12, 1.0), true)
	draw_line(fill.position + Vector2(3, 1), Vector2(fill.end.x - 3, fill.position.y + 1), Color(1.0, 0.43, 0.25, 0.8), 2.0)
	draw_line(Vector2(fill.position.x + 3, fill.position.y), Vector2(fill.position.x + 3, fill.end.y), Color(1.0, 0.34, 0.22, 0.35), 2.0)

func _track_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.032)
	style.border_color = Color(0.02, 0.018, 0.012)
	style.set_border_width_all(5)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 8
	return style
