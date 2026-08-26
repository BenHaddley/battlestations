extends Node2D
## A fast, crooked white ink stroke that makes gunfire read like a comic panel.

var points := PackedVector2Array()

func configure(from: Vector2, to: Vector2) -> void:
	global_position = Vector2.ZERO
	var perpendicular := (to - from).normalized().orthogonal()
	points = PackedVector2Array([
		from,
		from.lerp(to, 0.32) + perpendicular * 5.0,
		from.lerp(to, 0.68) - perpendicular * 4.0,
		to,
	])
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)

func _draw() -> void:
	if points.size() < 2:
		return
	draw_polyline(points, Color(0.04, 0.025, 0.02, 0.8), 8.0, true)
	draw_polyline(points, Color(1.0, 0.96, 0.78, 1.0), 3.5, true)
