extends Control
## Small hand-drawn heart, used instead of a Unicode ♥ glyph — the HUD font
## has no glyph for U+2665 and falls back to a visible tofu box.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var body := PackedVector2Array([
		Vector2(w * 0.5, h * 0.92),
		Vector2(w * 0.06, h * 0.42),
		Vector2(w * 0.08, h * 0.12),
		Vector2(w * 0.3, h * 0.02),
		Vector2(w * 0.5, h * 0.22),
		Vector2(w * 0.7, h * 0.02),
		Vector2(w * 0.92, h * 0.12),
		Vector2(w * 0.94, h * 0.42),
	])
	draw_colored_polygon(body, Color(0.85, 0.18, 0.16, 1))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.05, 0.04, 0.03, 1), 2.0, true)
