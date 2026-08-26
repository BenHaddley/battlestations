extends Control
## A deliberately uneven tabletop frame around the playable courtyard. The
## centre remains transparent so world sprites and input continue unchanged.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var outer := PackedVector2Array([
		Vector2(3, 8), Vector2(size.x - 7, 4),
		Vector2(size.x - 3, size.y - 8), Vector2(7, size.y - 3),
		Vector2(3, 8),
	])
	var inner := PackedVector2Array([
		Vector2(13, 18), Vector2(size.x - 17, 15),
		Vector2(size.x - 14, size.y - 19), Vector2(17, size.y - 14),
		Vector2(13, 18),
	])
	draw_polyline(outer, Color(0.045, 0.035, 0.02), 14.0, true)
	draw_polyline(outer, Color(0.19, 0.31, 0.16), 8.0, true)
	draw_polyline(inner, Color(0.58, 0.35, 0.18), 5.0, true)
	draw_polyline(inner, Color(0.055, 0.04, 0.025), 2.5, true)

