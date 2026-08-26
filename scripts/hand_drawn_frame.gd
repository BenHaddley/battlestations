extends Control
## Overlay drawn on top of an ordinary PanelContainer/StyleBoxFlat panel — the
## flat colour fill stays on the panel underneath; this adds the thick,
## deliberately uneven ink-and-paper border a vector rounded-rect border
## can't, plus a scatter of paper grain across the interior so the flat fill
## doesn't read as a clean digital surface. Add as a child of the panel with
## full-rect anchors so it always matches the panel's actual computed size.

@export var outline_color: Color = Color(0.07, 0.05, 0.03, 1)
@export var accent_color: Color = Color(0.48, 0.12, 0.07, 1)
@export var outline_width: float = 7.0
@export var accent_width: float = 3.0
@export var jitter: float = 3.5
@export var grain: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var random := RandomNumberGenerator.new()
	random.seed = hash(get_path())
	if grain:
		_draw_grain(random)
	draw_polyline(_jittered_rect(random, 3.0), outline_color, outline_width, true)
	draw_polyline(_jittered_rect(random, 9.0), accent_color, accent_width, true)

## Scattered ink specks and a couple of faint dry-brush streaks — the same
## paper-grain idea comic_card.gd already uses on shop buttons, at panel
## scale, so the interior fill doesn't undercut the hand-drawn border.
func _draw_grain(random: RandomNumberGenerator) -> void:
	var ink := Color(outline_color.r, outline_color.g, outline_color.b, 0.05)
	var paper := Color(1.0, 0.98, 0.9, 0.05)
	var speck_count: int = clampi(int(size.x * size.y / 900.0), 12, 140)
	for _i in range(speck_count):
		var point := Vector2(random.randf_range(10.0, size.x - 10.0), random.randf_range(10.0, size.y - 10.0))
		draw_circle(point, random.randf_range(0.6, 1.6), ink if random.randf() < 0.6 else paper)
	var streak_count: int = maxi(2, int(size.y / 140.0))
	for _i in range(streak_count):
		var y := random.randf_range(14.0, size.y - 14.0)
		var x0 := random.randf_range(8.0, size.x * 0.3)
		var x1 := random.randf_range(size.x * 0.6, size.x - 8.0)
		draw_line(Vector2(x0, y), Vector2(x1, y + random.randf_range(-3.0, 3.0)), paper, random.randf_range(2.0, 5.0))

func _jittered_rect(random: RandomNumberGenerator, inset: float) -> PackedVector2Array:
	var rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(corner + Vector2(random.randf_range(-jitter, jitter), random.randf_range(-jitter, jitter)))
	points.append(points[0])
	return points
