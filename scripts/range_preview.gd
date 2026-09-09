extends Node2D
class_name RangePreview
## Attack-radius ring that follows a coupled car while it is hovered or
## selected. Reads the car's live targeting_range every frame, so upgrades
## that extend reach are reflected immediately, and stays hidden for cars
## that have no weapon.

const RANGE_COLOR := Color(1.0, 0.86, 0.42, 0.8)

var unit: Node2D
var _radius := 0.0

func _ready() -> void:
	z_index = 44
	visible = false

func follow(target: Node2D) -> void:
	unit = target
	_refresh()

func radius() -> float:
	return _radius

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(unit) or not unit.visible:
		unit = null
		_radius = 0.0
		visible = false
		return
	var range_value = unit.get("targeting_range")
	_radius = float(range_value) if range_value != null else 0.0
	visible = _radius > 0.0
	global_position = unit.global_position
	queue_redraw()

func _draw() -> void:
	if _radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.86, 0.42, 0.06))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, Color(0.06, 0.04, 0.02, 0.5), 5.0, true)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, RANGE_COLOR, 2.5, true)
