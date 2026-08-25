extends Node2D
## Quiet gameplay guides painted over the courtyard: spider lanes, entrances,
## and the station danger line. They clarify movement without competing with art.

@export var lane_x_positions := PackedFloat32Array([-350.0, -235.0, -118.0, 0.0, 118.0, 235.0, 350.0])
@export var top_y: float = -335.0
@export var bottom_y: float = 665.0

func _draw() -> void:
	for lane_x in lane_x_positions:
		draw_dashed_line(Vector2(lane_x, top_y), Vector2(lane_x, bottom_y), Color(0.82, 0.25, 0.18, 0.13), 5.0, 18.0)
		draw_circle(Vector2(lane_x, top_y), 13.0, Color(0.95, 0.67, 0.25, 0.42))
		draw_arc(Vector2(lane_x, top_y), 18.0, 0.0, TAU, 24, Color(0.12, 0.1, 0.08, 0.7), 3.0)
	draw_rect(Rect2(-390.0, bottom_y - 18.0, 780.0, 36.0), Color(0.7, 0.08, 0.04, 0.13))
	draw_dashed_line(Vector2(-390.0, bottom_y), Vector2(390.0, bottom_y), Color(1.0, 0.42, 0.2, 0.62), 5.0, 14.0)
