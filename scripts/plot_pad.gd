extends Node2D
class_name PlotPad
## Draws a build pad: a dashed mounting ring with a crosshair, distinct from
## the track tiles so a legal plot never reads as part of the railway
## itself. Glows on hover and disappears once a defense is built on it.

@export var radius: float = 40.0
@export var base_color: Color = Color(0.3, 0.75, 0.55, 0.28)
@export var ring_color: Color = Color(0.35, 0.85, 0.65, 0.85)
@export var hover_color: Color = Color(0.92, 0.65, 0.25, 1.0)

@onready var label: Label = $BuildLabel

var is_hovering: bool = false

func _ready() -> void:
	label.visible = false
	queue_redraw()

func set_hovering(state: bool) -> void:
	is_hovering = state
	label.visible = state
	queue_redraw()

func set_occupied(state: bool) -> void:
	visible = not state

func _draw() -> void:
	var ring: Color = hover_color if is_hovering else ring_color
	draw_circle(Vector2.ZERO, radius, hover_color * Color(1, 1, 1, 0.18) if is_hovering else base_color)

	var dash_count := 14
	for i in range(dash_count):
		var a0: float = TAU * float(i) / dash_count
		var a1: float = a0 + (TAU / dash_count) * 0.6
		draw_arc(Vector2.ZERO, radius, a0, a1, 6, ring, 3.0, true)

	var arm: float = radius * 0.32
	draw_line(Vector2(-arm, 0), Vector2(arm, 0), ring, 3.0)
	draw_line(Vector2(0, -arm), Vector2(0, arm), ring, 3.0)
