extends Control
## Overlay drawn on top of an ordinary PanelContainer/StyleBoxFlat panel — the
## flat colour fill stays on the panel underneath; this adds the thick,
## deliberately uneven ink-and-paper border a vector rounded-rect border
## can't. Add as a child of the panel with full-rect anchors so it always
## matches the panel's actual computed size.

@export var outline_color: Color = Color(0.07, 0.05, 0.03, 1)
@export var accent_color: Color = Color(0.48, 0.12, 0.07, 1)
@export var outline_width: float = 7.0
@export var accent_width: float = 3.0
@export var jitter: float = 3.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var random := RandomNumberGenerator.new()
	random.seed = hash(get_path())
	draw_polyline(_jittered_rect(random, 3.0), outline_color, outline_width, true)
	draw_polyline(_jittered_rect(random, 9.0), accent_color, accent_width, true)

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
