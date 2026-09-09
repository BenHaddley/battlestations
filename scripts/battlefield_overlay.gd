extends Node2D
## Quiet gameplay guides painted over the courtyard: spider lanes, entrances,
## and the station danger line. They clarify movement without competing with art.

@export var lane_x_positions := PackedFloat32Array([-262.0, -196.5, -131.0, -65.5, 0.0, 65.5, 131.0, 196.5, 262.0])
@export var top_y: float = -401.0
@export var bottom_y: float = 380.0

func _draw() -> void:
	# Lane guides are orientation, not decoration: kept thin and faint so the
	# railway and the train stay the strongest marks on the board.
	for lane_x in lane_x_positions:
		draw_dashed_line(Vector2(lane_x, top_y), Vector2(lane_x, bottom_y), Color(0.82, 0.25, 0.18, 0.07), 2.5, 26.0)
		draw_circle(Vector2(lane_x, top_y), 10.0, Color(0.95, 0.67, 0.25, 0.30))
		draw_arc(Vector2(lane_x, top_y), 14.0, 0.0, TAU, 24, Color(0.12, 0.1, 0.08, 0.45), 2.0)
	draw_rect(Rect2(-295.0, bottom_y - 12.0, 590.0, 24.0), Color(0.7, 0.08, 0.04, 0.10))
	draw_dashed_line(Vector2(-295.0, bottom_y), Vector2(295.0, bottom_y), Color(1.0, 0.42, 0.2, 0.45), 3.0, 13.0)
