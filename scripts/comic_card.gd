extends Button
## Adds stable ink flecks, dry-brush streaks, and an imperfect inner keyline to
## ordinary functional buttons. Children still draw above this texture.

func _ready() -> void:
	mouse_entered.connect(func() -> void: rotation += 0.012)
	mouse_exited.connect(func() -> void: rotation -= 0.012)
	queue_redraw()

func _draw() -> void:
	var seed_value: int = hash(name)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var ink := Color(0.08, 0.07, 0.035, 0.12)
	var paper := Color(1.0, 0.97, 0.66, 0.16)
	for index in range(22):
		var point := Vector2(random.randf_range(8.0, size.x - 8.0), random.randf_range(7.0, size.y - 7.0))
		draw_circle(point, random.randf_range(0.7, 1.8), ink if index % 3 else paper)
	for index in range(4):
		var y := random.randf_range(10.0, size.y - 10.0)
		draw_line(Vector2(8.0, y), Vector2(size.x - 8.0, y + random.randf_range(-2.5, 2.5)), paper, random.randf_range(1.0, 2.2))
	var outline := PackedVector2Array([
		Vector2(5.0, 7.0), Vector2(size.x - 6.0, 5.0),
		Vector2(size.x - 4.0, size.y - 7.0), Vector2(6.0, size.y - 5.0),
		Vector2(5.0, 7.0),
	])
	draw_polyline(outline, Color(0.025, 0.035, 0.025, 0.7), 2.5, true)
