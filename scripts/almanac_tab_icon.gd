extends Control
## Small scalable tab pictograms, drawn as native UI so they remain crisp.
var category := 0
var color := Color("b7ab91")

func _draw() -> void:
	var c := size * 0.5
	match category:
		0:
			draw_circle(c, 7, color)
			draw_circle(c + Vector2(0, -8), 4, color)
			for side in [-1, 1]:
				for y in [-5, 1, 7]:
					draw_polyline(PackedVector2Array([c + Vector2(side * 5, y), c + Vector2(side * 11, y - 4), c + Vector2(side * 13, y + 3)]), color, 2, true)
		1:
			draw_rect(Rect2(c - Vector2(12, 7), Vector2(24, 14)), color, false, 2)
			for x in [-8, 0, 8]:
				draw_rect(Rect2(c + Vector2(x - 2, -4), Vector2(4, 4)), color)
			for x in [-8, 8]:
				draw_circle(c + Vector2(x, 10), 3, color)
		2:
			draw_line(c + Vector2(-10, 8), c + Vector2(11, 8), color, 4, true)
			draw_arc(c + Vector2(-2, 3), 6, PI, TAU, 15, color, 3, true)
			draw_line(c + Vector2(-1, 0), c + Vector2(10, -10), color, 6, true)
		3:
			for y in [-10, -4, 3, 10]:
				draw_line(c + Vector2(-12, y), c + Vector2(12, y), color, 3, true)
			for x in [-7, 7]:
				draw_line(c + Vector2(x, -14), c + Vector2(x, 14), color, 2, true)
