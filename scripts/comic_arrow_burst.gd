extends Node2D
## Deliberately uneven radial arrows matching the hand-inked board-game effects.

func _draw() -> void:
	for index in range(4):
		var angle := index * PI * 0.5 + 0.08 * (-1.0 if index % 2 == 0 else 1.0)
		var direction := Vector2.RIGHT.rotated(angle)
		var side := direction.rotated(PI * 0.5)
		var start := direction * 34.0
		var bend := direction * 58.0 + side * (7.0 if index % 2 == 0 else -6.0)
		var tip := direction * 91.0
		draw_polyline(PackedVector2Array([start, bend, tip]), Color(1, 1, 0.9, 0.95), 6.0, true)
		draw_polyline(PackedVector2Array([tip - direction * 18.0 + side * 11.0, tip, tip - direction * 18.0 - side * 11.0]), Color(1, 1, 0.9, 0.95), 6.0, true)

func play(world_position: Vector2) -> void:
	global_position = world_position
	scale = Vector2(0.65, 0.65)
	z_index = 55
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.42)
	tween.tween_property(self, "modulate:a", 0.0, 0.42)
	tween.chain().tween_callback(queue_free)
