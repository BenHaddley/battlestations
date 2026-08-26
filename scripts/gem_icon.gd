extends Control
## Hand-drawn cyan gem, faceted rather than a clean vector diamond.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var body := PackedVector2Array([
		Vector2(size.x * 0.5, size.y * 0.04),
		Vector2(size.x * 0.94, size.y * 0.38),
		Vector2(size.x * 0.68, size.y * 0.97),
		Vector2(size.x * 0.32, size.y * 0.95),
		Vector2(size.x * 0.05, size.y * 0.4),
	])
	draw_colored_polygon(body, Color(0.28, 0.86, 0.92, 1))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.04, 0.05, 0.06, 1), 3.0, true)
	draw_line(Vector2(size.x * 0.3, size.y * 0.4), Vector2(size.x * 0.66, size.y * 0.42), Color(0.85, 1, 1, 0.75), 2.0, true)
	draw_line(Vector2(size.x * 0.5, size.y * 0.08), Vector2(size.x * 0.44, size.y * 0.4), Color(0.06, 0.07, 0.08, 0.5), 1.5, true)
