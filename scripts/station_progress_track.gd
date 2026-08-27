extends Control
class_name StationProgressTrack
## Hand-drawn route strip for StationProgressPanel. The locomotive's x
## position is interpolated from progress, so it travels instead of merely
## changing which checkpoint is highlighted.

@export_range(2, 12, 1) var checkpoint_count := 7:
	set(value):
		checkpoint_count = maxi(2, value)
		queue_redraw()

var progress := 0.0
var _display_progress := 0.0
var _progress_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, 38.0)

func set_progress(value: float, animate := true) -> void:
	var next_progress := clampf(value, 0.0, 1.0)
	if is_equal_approx(next_progress, progress):
		return
	progress = next_progress
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
	if not animate:
		_display_progress = progress
		queue_redraw()
		return
	_progress_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_progress_tween.tween_method(_set_display_progress, _display_progress, progress, 0.48)

func _set_display_progress(value: float) -> void:
	_display_progress = value
	queue_redraw()

func _draw() -> void:
	var left := 18.0
	var right := size.x - 18.0
	var track_y := size.y * 0.60
	# Crooked ink line and its slightly offset paper highlight.
	draw_polyline(PackedVector2Array([
		Vector2(left, track_y + 1.0),
		Vector2(size.x * 0.34, track_y - 1.5),
		Vector2(size.x * 0.68, track_y + 1.0),
		Vector2(right, track_y - 1.0),
	]), Color("17100d"), 4.5)
	draw_line(Vector2(left, track_y - 3.0), Vector2(right, track_y - 3.0), Color(1.0, 0.92, 0.7, 0.6), 1.0)

	for index in range(checkpoint_count):
		var fraction := float(index) / float(checkpoint_count - 1)
		var point := Vector2(lerpf(left, right, fraction), track_y)
		var passed := fraction <= _display_progress + 0.001
		draw_circle(point + Vector2(1.0, 1.0), 7.8, Color(0.03, 0.025, 0.02, 0.8))
		draw_circle(point, 6.8, Color("2878c9") if passed else Color("b7d9e2"))
		draw_arc(point, 7.2, 0.0, TAU, 18, Color("17100d"), 2.2)
		if index > 0 and index < checkpoint_count - 1:
			_draw_checkpoint(point)

	_draw_flag(Vector2(left, track_y), false)
	_draw_flag(Vector2(right, track_y), true)
	_draw_locomotive(Vector2(lerpf(left, right, _display_progress), track_y + 5.0))

func _draw_checkpoint(at: Vector2) -> void:
	draw_line(at + Vector2(0.0, -8.0), at + Vector2(0.0, -16.0), Color("17100d"), 2.0)
	draw_circle(at + Vector2(0.0, -18.0), 2.4, Color("8b241d"))

func _draw_flag(at: Vector2, flipped: bool) -> void:
	var direction := -1.0 if flipped else 1.0
	draw_line(at + Vector2(0.0, -7.0), at + Vector2(0.0, -29.0), Color("17100d"), 2.8)
	var flag := PackedVector2Array([
		at + Vector2(0.0, -29.0),
		at + Vector2(12.0 * direction, -25.0),
		at + Vector2(0.0, -19.0),
	])
	draw_colored_polygon(flag, Color("bd3027"))
	draw_polyline(flag, Color("17100d"), 2.0)

func _draw_locomotive(at: Vector2) -> void:
	# Steam puffs remain separate vector marks above a chunky black engine.
	for puff in [Vector2(-8.0, -13.0), Vector2(-3.0, -19.0), Vector2(4.0, -23.0)]:
		draw_circle(at + puff, 3.8, Color("fff9e8"))
		draw_arc(at + puff, 3.9, 0.0, TAU, 12, Color("17100d"), 1.2)
	draw_rect(Rect2(at + Vector2(-12.0, -9.0), Vector2(24.0, 12.0)), Color("17100d"), true)
	draw_rect(Rect2(at + Vector2(2.0, -16.0), Vector2(7.0, 8.0)), Color("17100d"), true)
	draw_rect(Rect2(at + Vector2(-8.0, -13.0), Vector2(8.0, 5.0)), Color("17100d"), true)
	draw_circle(at + Vector2(-7.0, 4.0), 4.0, Color("17100d"))
	draw_circle(at + Vector2(8.0, 4.0), 4.0, Color("17100d"))
