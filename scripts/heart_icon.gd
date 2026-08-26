extends Control
## Small hand-drawn heart, used instead of a Unicode ♥ glyph — the HUD font
## has no glyph for U+2665 and falls back to a visible tofu box.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var section := Rect2(2.0, 2.0, w - 4.0, h - 4.0)
	draw_rect(section, Color(0.78, 0.68, 0.49, 1.0), true)
	draw_polyline(PackedVector2Array([
		Vector2(3, 5), Vector2(w - 5, 3), Vector2(w - 3, h - 5),
		Vector2(5, h - 3), Vector2(3, 5),
	]), Color(0.055, 0.04, 0.025, 1.0), 3.0, true)
	var body := PackedVector2Array([
		Vector2(w * 0.5, h * 0.86),
		Vector2(w * 0.18, h * 0.49),
		Vector2(w * 0.19, h * 0.25),
		Vector2(w * 0.34, h * 0.17),
		Vector2(w * 0.5, h * 0.32),
		Vector2(w * 0.66, h * 0.17),
		Vector2(w * 0.81, h * 0.25),
		Vector2(w * 0.82, h * 0.49),
	])
	draw_colored_polygon(body, Color(0.85, 0.18, 0.16, 1))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.05, 0.04, 0.03, 1), 2.0, true)
