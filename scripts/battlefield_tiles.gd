extends Node2D
## Paints an exact, non-overlapping board grid. The original 110×86 sample
## textures include pieces of neighbouring cells, so scaling them into 90×90
## sprites produced stretched slabs, doubled seams, and a brick-wall pattern.
## Drawing each cell inside its own bounds preserves the paper-board feel
## without letting source-image overscan leak into adjacent squares.

@export var light_tile: Texture2D
@export var dark_tile: Texture2D
@export var bounds: Rect2 = Rect2(-330.0, -270.0, 660.0, 810.0)
@export var cell_size: float = 90.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var columns: int = ceili(bounds.size.x / cell_size)
	var rows: int = ceili(bounds.size.y / cell_size)
	for row in range(rows):
		for col in range(columns):
			var position := bounds.position + Vector2(col * cell_size, row * cell_size)
			var clipped_size := Vector2(
				minf(cell_size, bounds.end.x - position.x),
				minf(cell_size, bounds.end.y - position.y)
			)
			if clipped_size.x <= 0.0 or clipped_size.y <= 0.0:
				continue
			_draw_cell(Rect2(position, clipped_size), row, col)

func _draw_cell(rect: Rect2, row: int, col: int) -> void:
	var is_dark := (row + col) % 2 == 0
	var paper := Color(0.53, 0.54, 0.47, 1.0) if is_dark else Color(0.78, 0.77, 0.67, 1.0)
	draw_rect(rect, paper, true)

	# One shared-width ink seam per cell. Keeping every mark clipped inside the
	# exact rectangle prevents the overlapping borders seen in the old samples.
	var inset := rect.grow(-1.5)
	draw_line(inset.position, Vector2(inset.end.x, inset.position.y), Color(0.11, 0.1, 0.075, 0.7), 2.2)
	draw_line(inset.position, Vector2(inset.position.x, inset.end.y), Color(0.11, 0.1, 0.075, 0.62), 2.2)
	draw_line(Vector2(inset.position.x, inset.end.y), inset.end, Color(0.93, 0.88, 0.72, 0.22), 1.4)
	draw_line(Vector2(inset.end.x, inset.position.y), inset.end, Color(0.04, 0.04, 0.03, 0.5), 2.0)

	# Deterministic paper flecks and dry-brush strokes: enough variation to
	# avoid a sterile CSS checkerboard, but never strong enough to fake paths.
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector2i(row, col))
	for mark in range(7):
		var point := rect.position + Vector2(
			random.randf_range(8.0, maxf(9.0, rect.size.x - 8.0)),
			random.randf_range(8.0, maxf(9.0, rect.size.y - 8.0))
		)
		var ink := Color(0.18, 0.17, 0.13, random.randf_range(0.025, 0.065))
		draw_circle(point, random.randf_range(0.7, 2.1), ink)
	for stroke in range(2):
		var y := rect.position.y + random.randf_range(14.0, maxf(15.0, rect.size.y - 14.0))
		var start := Vector2(rect.position.x + 9.0, y)
		var finish := Vector2(rect.end.x - 9.0, y + random.randf_range(-2.0, 2.0))
		draw_line(start, finish, Color(0.96, 0.91, 0.76, 0.055), random.randf_range(1.0, 2.4))
