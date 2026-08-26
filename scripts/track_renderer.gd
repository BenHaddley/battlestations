extends Node2D
class_name TrackRenderer
## Generates closed concentric oval railways. Every route is a continuous
## loop, so its train circles forever instead of reversing at a terminus.

@export var rail_texture: Texture2D
@export var curve_texture: Texture2D
@export var tile_scale: float = 0.125
@export var path_step: float = 82.0
@export var track_bounds: Rect2 = Rect2(-330.0, -270.0, 660.0, 810.0)
@export var loop_inset: float = 22.0
@export var loop_gap: float = 92.0

var routes: Array[PackedVector2Array] = []

func generate_layout(route_count: int = 2) -> Array[PackedVector2Array]:
	for child in get_children():
		child.queue_free()
	routes = []
	var center := track_bounds.get_center()
	for loop_index in range(maxi(route_count, 1)):
		var radius := track_bounds.size * 0.5 - Vector2.ONE * (loop_inset + loop_gap * loop_index)
		if radius.x < 105.0 or radius.y < 105.0:
			break
		var route := _make_oval(center, radius, loop_index)
		if route.size() >= 8:
			routes.append(route)
	_render_all()
	return routes

func _make_oval(center: Vector2, radius: Vector2, loop_index: int) -> PackedVector2Array:
	var h := pow(radius.x - radius.y, 2.0) / pow(radius.x + radius.y, 2.0)
	var circumference := PI * (radius.x + radius.y) * (1.0 + 3.0 * h / (10.0 + sqrt(4.0 - 3.0 * h)))
	var point_count := maxi(12, ceili(circumference / path_step))
	var start_angle := -PI * 0.5 + (PI if loop_index % 2 else 0.0)
	var route := PackedVector2Array()
	for index in range(point_count):
		var angle := start_angle + TAU * float(index) / float(point_count)
		route.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return route

func _render_all() -> void:
	for route in routes:
		_render_route(route)

func _render_route(route: PackedVector2Array) -> void:
	for index in range(route.size()):
		var point := route[index]
		var next_point := route[(index + 1) % route.size()]
		var direction := (next_point - point).normalized()
		var segment_length := point.distance_to(next_point)
		var tile := Sprite2D.new()
		tile.texture = rail_texture
		tile.position = point.lerp(next_point, 0.5)
		tile.rotation = direction.angle() + PI * 0.5
		tile.scale = Vector2(tile_scale, maxf(0.105, segment_length / rail_texture.get_height()))
		tile.z_index = -5
		var shadow := Sprite2D.new()
		shadow.texture = rail_texture
		shadow.position = tile.position + Vector2(0.0, 7.0)
		shadow.rotation = tile.rotation
		shadow.scale = tile.scale * Vector2(1.12, 1.04)
		shadow.modulate = Color(0.04, 0.035, 0.025, 0.38)
		shadow.z_index = -7
		add_child(shadow)
		add_child(tile)

func covers_lanes(lane_x_positions: PackedFloat32Array, weapon_range: float) -> bool:
	for lane_x in lane_x_positions:
		var covered := false
		for route in routes:
			for point in route:
				if absf(point.x - lane_x) <= weapon_range:
					covered = true
					break
			if covered:
				break
		if not covered:
			return false
	return true

func routes_are_traversable() -> bool:
	for route in routes:
		if route.size() < 8:
			return false
		for index in range(route.size()):
			var next_index := (index + 1) % route.size()
			if route[index].distance_to(route[next_index]) > path_step * 1.35:
				return false
	return true
