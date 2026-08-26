extends Control
## Two intentionally uneven marker strokes beneath the challenges heading.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var upper := PackedVector2Array([
		Vector2(20, 5), Vector2(54, 2), Vector2(91, 7),
		Vector2(132, 4), Vector2(size.x - 18, 8),
	])
	var lower := PackedVector2Array([
		Vector2(38, 13), Vector2(72, 10), Vector2(111, 15),
		Vector2(size.x - 39, 11),
	])
	draw_polyline(upper, Color(0.08, 0.045, 0.025, 0.95), 4.5, true)
	draw_polyline(lower, Color(0.08, 0.045, 0.025, 0.78), 2.5, true)
