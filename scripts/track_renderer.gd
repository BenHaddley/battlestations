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
@export var tile_scale: float = 0.09
@export var path_step: float = 65.5
## Nine columns by twelve rows, registered to the square courtyard in
## the_new_map.png. Values are rail-centre positions rather than tile edges.
@export var track_bounds: Rect2 = Rect2(-262.0, -377.0, 524.0, 720.5)
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

## The ten artist reference sheets are preserved as an authored route library.
## Indices correspond to image.png, 2.png ... 10.png in
## assets/_reference/.../track image references. CampaignManager chooses a
## difficulty-ordered subset; callers can still use every supplied design.
const REFERENCE_LAYOUT_NAMES := [
	"image.png", "2.png", "3.png", "4.png", "5.png",
	"6.png", "7.png", "8.png", "9.png", "10.png"
]

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
	# Random placement is allowed to fail, game startup is not. Two compact
	# loops in opposite board quadrants provide a deterministic safety layout
	# whenever the randomized packing cannot satisfy the requested train count.
	if routes.size() < mini(route_count, 2):
		routes = _fallback_routes(route_count)

	_render_all()
	return routes

## Builds one deterministic campaign layout from the artist's red-line track
## sketches. Coordinates are integer cells on the live 9x12 board, so rails
## remain perfectly registered even though the source marks are freehand.
func generate_campaign_layout(layout_index: int) -> Array[PackedVector2Array]:
	for child in get_children():
		child.queue_free()
	_build_grid()
	var layouts := _reference_cell_layouts()
	if layout_index < 0 or layout_index >= layouts.size():
		push_warning("Unknown campaign track layout %d; using procedural rails." % layout_index)
		return generate_layout(2)
	routes = []
	for cell_route in layouts[layout_index]:
		var world_route := PackedVector2Array()
		for cell in cell_route:
			if cell.x < 0 or cell.x >= columns.size() or cell.y < 0 or cell.y >= rows.size():
				push_error("%s contains out-of-board rail cell %s." % [REFERENCE_LAYOUT_NAMES[layout_index], cell])
				continue
			world_route.append(Vector2(columns[cell.x], rows[cell.y]))
		if world_route.size() >= 4:
			routes.append(world_route)
	_render_all()
	return routes

## A single compact crossing loop for Last Train Standing. The center cell is
## intentionally visited twice, once horizontally and once vertically, so the
## renderer layers two straight rail tiles into a proper tabletop crossing.
## It occupies only the bottom three battlefield rows and leaves the upper
## board entirely to the approaching spiders.
func generate_bottom_figure_eight() -> Array[PackedVector2Array]:
	for child in get_children():
		child.queue_free()
	_build_grid()
	var cells: Array[Vector2i] = [
		Vector2i(4, 9),
		Vector2i(3, 9), Vector2i(2, 9), Vector2i(1, 9),
		Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10),
		Vector2i(4, 9),
		Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8),
		Vector2i(7, 9), Vector2i(7, 10), Vector2i(6, 10), Vector2i(5, 10),
		Vector2i(5, 9),
	]
	var figure_eight := PackedVector2Array()
	for cell in cells:
		figure_eight.append(Vector2(columns[cell.x], rows[cell.y]))
	routes = [figure_eight]
	_render_all()
	return routes

## Authored from the ten supplied diagrams. A polygon helper expands corner
## vertices into one-cell steps, keeping closed-route validation identical to
## generated tracks. This data is deliberately code-native, not image sampled.
func _reference_cell_layouts() -> Array:
	return [
		# 1, two plain loops. Simplest teaching board.
		[_offset_ring(_rectangle_ring(4, 4), Vector2i(2, 2)),
		 _offset_ring(_rectangle_ring(8, 4), Vector2i(0, 7))],
		# 2, one large U-like circuit.
		[_orthogonal_ring([Vector2i(0, 2), Vector2i(2, 2), Vector2i(2, 7), Vector2i(6, 7), Vector2i(6, 2), Vector2i(8, 2), Vector2i(8, 11), Vector2i(0, 11)])],
		# 3, large outer circuit plus a nested inner circuit.
		[_offset_ring(_rectangle_ring(8, 10), Vector2i(0, 1)),
		 _offset_ring(_rectangle_ring(4, 5), Vector2i(2, 3))],
		# 4, two offset notched circuits.
		[_orthogonal_ring([Vector2i(0, 2), Vector2i(4, 2), Vector2i(4, 3), Vector2i(7, 3), Vector2i(7, 5), Vector2i(4, 5), Vector2i(4, 6), Vector2i(0, 6)]),
		 _orthogonal_ring([Vector2i(1, 7), Vector2i(4, 7), Vector2i(4, 8), Vector2i(7, 8), Vector2i(7, 11), Vector2i(4, 11), Vector2i(4, 10), Vector2i(1, 10)])],
		# 5, three tall narrow circuits with changing profiles.
		[_orthogonal_ring([Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 8), Vector2i(0, 8)]),
		 _orthogonal_ring([Vector2i(3, 0), Vector2i(5, 0), Vector2i(5, 2), Vector2i(6, 2), Vector2i(6, 6), Vector2i(5, 6), Vector2i(5, 11), Vector2i(3, 11)]),
		 _orthogonal_ring([Vector2i(7, 0), Vector2i(8, 0), Vector2i(8, 11), Vector2i(7, 11)])],
		# 6, one broad T-shaped perimeter.
		[_orthogonal_ring([Vector2i(1, 1), Vector2i(7, 1), Vector2i(7, 3), Vector2i(5, 3), Vector2i(5, 10), Vector2i(8, 10), Vector2i(8, 11), Vector2i(0, 11), Vector2i(0, 10), Vector2i(3, 10), Vector2i(3, 3), Vector2i(1, 3)])],
		# 7, four independent corner circuits.
		[_offset_ring(_rectangle_ring(3, 3), Vector2i(0, 0)),
		 _offset_ring(_rectangle_ring(3, 3), Vector2i(5, 0)),
		 _offset_ring(_rectangle_ring(3, 3), Vector2i(0, 8)),
		 _offset_ring(_rectangle_ring(3, 3), Vector2i(5, 8))],
		# 8, dense outer notches surrounding a long comb circuit.
		[_orthogonal_ring([Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 2), Vector2i(6, 2), Vector2i(6, 0), Vector2i(8, 0), Vector2i(8, 11), Vector2i(6, 11), Vector2i(6, 9), Vector2i(2, 9), Vector2i(2, 11), Vector2i(0, 11)]),
		 _orthogonal_ring([Vector2i(2, 3), Vector2i(6, 3), Vector2i(6, 4), Vector2i(3, 4), Vector2i(3, 5), Vector2i(6, 5), Vector2i(6, 6), Vector2i(3, 6), Vector2i(3, 7), Vector2i(6, 7), Vector2i(6, 8), Vector2i(2, 8)])],
		# 9, three progressively wider stacked circuits.
		[_offset_ring(_rectangle_ring(4, 2), Vector2i(2, 1)),
		 _offset_ring(_rectangle_ring(6, 2), Vector2i(1, 4)),
		 _offset_ring(_rectangle_ring(8, 3), Vector2i(0, 8))],
		# 10, two upright side loops and one broad station-side loop.
		[_offset_ring(_rectangle_ring(2, 4), Vector2i(0, 3)),
		 _offset_ring(_rectangle_ring(2, 4), Vector2i(6, 3)),
		 _offset_ring(_rectangle_ring(8, 2), Vector2i(0, 9))],
	]

func _offset_ring(base: Array[Vector2i], origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in base:
		result.append(origin + cell)
	return result

func _orthogonal_ring(vertices: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in range(vertices.size()):
		var cursor := vertices[index]
		var finish := vertices[(index + 1) % vertices.size()]
		var delta := finish - cursor
		if delta.x != 0 and delta.y != 0:
			push_error("Campaign rail vertices must be orthogonal: %s to %s" % [cursor, finish])
			return []
		var step := Vector2i(signi(delta.x), signi(delta.y))
		while cursor != finish:
			result.append(cursor)
			cursor += step
	return result

func _fallback_routes(route_count: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var origins: Array[Vector2i] = [Vector2i(0, 1), Vector2i(4, 5)]
	for route_index in range(mini(route_count, origins.size())):
		var points := PackedVector2Array()
		for cell in _rectangle_ring(3, 3):
			var placed := origins[route_index] + cell
			points.append(Vector2(columns[placed.x], rows[placed.y]))
		result.append(points)
	return result

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
			tile.scale = Vector2(tile_scale, tile_scale)
			tile.rotation = _curve_rotation(previous_direction, next_direction)
			shadow.texture = curve_texture
			shadow.scale = tile.scale * 1.08
			shadow.rotation = tile.rotation
		else:
			tile.texture = rail_texture
			# Source art is vertical: keep its width narrow while extending its
			# length slightly beyond the path step to eliminate seams.
			tile.scale = Vector2(tile_scale, tile_scale)
			tile.rotation = PI * 0.5 if absf(next_direction.x) > 0.5 else 0.0
			shadow.scale = Vector2(tile_scale * 1.12, tile_scale * 1.05)
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
