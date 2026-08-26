extends Node2D
class_name TrackRenderer
## Generates several small, grid-aligned railway loops scattered across the
## board — straight runs and 90-degree corners snapped to a shared grid,
## not sweeping curves. Every loop is closed by construction (its last point
## sits exactly one grid step from its first), so a train can circle it
## forever by simply advancing (path_index + 1) % path.size() — there is no
## reversal because there is no endpoint.

@export var rail_texture: Texture2D
@export var curve_texture: Texture2D
@export var tile_scale: float = 0.105
@export var path_step: float = 90.0
@export var track_bounds: Rect2 = Rect2(-330.0, -270.0, 660.0, 810.0)
## Minimum tiles a placed loop must have to comfortably hold an engine plus
## a few cars (car_spacing 170 / path_step 90 ≈ 2 tiles per car).
@export var minimum_route_tiles: int = 10
## Empty cells left around every placed loop so separate railway networks
## read as distinct pieces with open battlefield between them, rather than
## packing edge-to-edge.
@export var loop_margin: int = 1

var columns: Array[float] = []
var rows: Array[float] = []
var routes: Array[PackedVector2Array] = []

## route_count is a placement target, not a promise — see generate_layout().
func generate_layout(route_count: int = 2) -> Array[PackedVector2Array]:
	randomize()
	for child in get_children():
		child.queue_free()
	_build_grid()

	var occupied: Dictionary = {}
	routes = []
	for route_index in range(maxi(route_count, 1)):
		var route := _place_loop(occupied)
		if not route.is_empty():
			routes.append(route)

	_render_all()
	return routes

func _build_grid() -> void:
	columns = []
	var x := track_bounds.position.x
	while x <= track_bounds.end.x + 0.1:
		columns.append(x)
		x += path_step
	rows = []
	var y := track_bounds.position.y
	while y <= track_bounds.end.y + 0.1:
		rows.append(y)
		y += path_step

## Tries a handful of random size/shape/position combinations, skipping any
## that would collide (including the loop_margin buffer) with already-placed
## track. Returns an empty array if none fit within the attempt budget — the
## caller (and ultimately Main's retry loop) treats a short route list as
## valid too, as long as enough usable loops remain.
func _place_loop(occupied: Dictionary) -> PackedVector2Array:
	for attempt in range(24):
		var shape := _random_loop_shape()
		shape = _transform_shape(shape, randi_range(0, 3), randf() >= 0.5)
		var max_x := 0
		var max_y := 0
		for cell in shape:
			max_x = maxi(max_x, cell.x)
			max_y = maxi(max_y, cell.y)
		if max_x >= columns.size() - 1 or max_y >= rows.size() - 1:
			continue

		var col_origin: int = randi_range(0, columns.size() - 1 - max_x)
		var row_origin: int = randi_range(0, rows.size() - 1 - max_y)
		var placed_cells: Array[Vector2i] = []
		var collides := false
		for cell in shape:
			var world_cell := Vector2i(col_origin + cell.x, row_origin + cell.y)
			if _blocked(world_cell, occupied):
				collides = true
				break
			placed_cells.append(world_cell)
		if collides or placed_cells.size() < minimum_route_tiles:
			continue

		for cell in placed_cells:
			occupied[cell] = true
		var world_points := PackedVector2Array()
		for cell in placed_cells:
			world_points.append(Vector2(columns[cell.x], rows[cell.y]))
		return world_points
	return PackedVector2Array()

func _blocked(cell: Vector2i, occupied: Dictionary) -> bool:
	for dx in range(-loop_margin, loop_margin + 1):
		for dy in range(-loop_margin, loop_margin + 1):
			if occupied.has(Vector2i(cell.x + dx, cell.y + dy)):
				return true
	return false

## Picks a random plain rectangle or L-shaped (one corner notched) ring,
## sized in grid cells. Both are closed by construction — see
## _rectangle_ring()/_l_shape_ring().
func _random_loop_shape() -> Array[Vector2i]:
	var w := randi_range(2, 4)
	var h := randi_range(2, 3)
	if randf() < 0.4 and w >= 3 and h >= 3:
		var notch_w := randi_range(1, w - 2)
		var notch_h := randi_range(1, h - 2)
		return _l_shape_ring(w, h, notch_w, notch_h)
	return _rectangle_ring(w, h)

## Perimeter of a (w x h)-cell rectangle, walked clockwise from the origin.
## Every consecutive pair — including the wrap from the last point back to
## the first — is exactly one grid step apart.
func _rectangle_ring(w: int, h: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	for x in range(0, w):
		pts.append(Vector2i(x, 0))
	for y in range(0, h):
		pts.append(Vector2i(w, y))
	for x in range(w, 0, -1):
		pts.append(Vector2i(x, h))
	for y in range(h, 0, -1):
		pts.append(Vector2i(0, y))
	return pts

## Same rectangle with a (notch_w x notch_h)-cell rectangular bite taken out
## of the top-right corner, producing an L-shaped ring. Still a single
## closed perimeter with every step exactly one grid cell.
func _l_shape_ring(w: int, h: int, notch_w: int, notch_h: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	for x in range(0, w - notch_w):
		pts.append(Vector2i(x, 0))
	for y in range(0, notch_h):
		pts.append(Vector2i(w - notch_w, y))
	for x in range(w - notch_w, w):
		pts.append(Vector2i(x, notch_h))
	for y in range(notch_h, h):
		pts.append(Vector2i(w, y))
	for x in range(w, 0, -1):
		pts.append(Vector2i(x, h))
	for y in range(h, 0, -1):
		pts.append(Vector2i(0, y))
	return pts

## Rotates a shape by rotation_quarter * 90° (integer lattice rotation) and
## optionally mirrors it horizontally first, then re-anchors it back to a
## (0,0)-minimum origin so downstream placement math stays simple.
func _transform_shape(base_points: Array, rotation_quarter: int, mirror: bool) -> Array[Vector2i]:
	var transformed: Array[Vector2i] = []
	for point in base_points:
		var cell: Vector2i = point
		if mirror:
			cell.x = -cell.x
		for _i in range(rotation_quarter):
			cell = Vector2i(-cell.y, cell.x)
		transformed.append(cell)
	var min_x: int = transformed[0].x
	var min_y: int = transformed[0].y
	for cell in transformed:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	var normalized: Array[Vector2i] = []
	for cell in transformed:
		normalized.append(Vector2i(cell.x - min_x, cell.y - min_y))
	return normalized

func _render_all() -> void:
	for route in routes:
		_render_route(route)

## Every route here is a closed ring, so the point "before" index 0 and the
## point "after" the last index both wrap around — there is no open end to
## treat differently.
func _render_route(route_points: PackedVector2Array) -> void:
	var count := route_points.size()
	for index in range(count):
		var point := route_points[index]
		var previous_point := route_points[(index - 1 + count) % count]
		var next_point := route_points[(index + 1) % count]
		var previous_direction := (previous_point - point).normalized()
		var next_direction := (next_point - point).normalized()

		var shadow := Sprite2D.new()
		shadow.texture = rail_texture
		shadow.position = point + Vector2(0.0, 7.0)
		shadow.modulate = Color(0.04, 0.035, 0.025, 0.38)
		shadow.z_index = -7
		var tile := Sprite2D.new()
		tile.position = point
		tile.z_index = -5

		if not previous_direction.is_equal_approx(-next_direction):
			tile.texture = curve_texture
			tile.scale = Vector2(0.125, 0.125)
			tile.rotation = _curve_rotation(previous_direction, next_direction)
			shadow.texture = curve_texture
			shadow.scale = tile.scale * 1.08
			shadow.rotation = tile.rotation
		else:
			tile.texture = rail_texture
			# Source art is vertical: keep its width narrow while extending its
			# length slightly beyond the path step to eliminate seams.
			tile.scale = Vector2(tile_scale, 0.125)
			tile.rotation = PI * 0.5 if absf(next_direction.x) > 0.5 else 0.0
			shadow.scale = Vector2(tile_scale * 1.12, 0.13)
			shadow.rotation = tile.rotation
		add_child(shadow)
		add_child(tile)

func _curve_rotation(a: Vector2, b: Vector2) -> float:
	var has_down := a.y > 0.5 or b.y > 0.5
	var has_up := a.y < -0.5 or b.y < -0.5
	var has_right := a.x > 0.5 or b.x > 0.5
	var has_left := a.x < -0.5 or b.x < -0.5
	if has_down and has_right:
		return 0.0
	if has_down and has_left:
		return PI * 0.5
	if has_up and has_left:
		return PI
	if has_up and has_right:
		return -PI * 0.5
	return 0.0

## True once every lane has at least one route point within weapon_range —
## the union of every placed loop, not any single one, is what has to cover
## the board.
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

## Every route must be a fully connected ring — each consecutive pair of
## points exactly one grid step apart, including the wrap from the last
## point back to the first — so a train can never stall or jump mid-loop.
## Guaranteed by construction above; this is a run-once safety check so a
## future shape-generation mistake surfaces immediately instead of as a
## silent stuck or teleporting train in play.
func routes_are_traversable() -> bool:
	for route in routes:
		if route.size() < 4:
			return false
		for index in range(route.size()):
			var next_index := (index + 1) % route.size()
			if route[index].distance_to(route[next_index]) > path_step + 1.0:
				return false
	return true
