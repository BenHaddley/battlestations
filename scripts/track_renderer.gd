extends Node2D
class_name TrackRenderer
## Generates several short, bounded railway routes per run instead of one
## path spanning the whole board. Each route is built from a reusable grid
## module (straight, bend, U-shape, loop, compact circuit), rotated and
## placed into its own horizontal band so routes read as distinct little
## railway systems rather than one continuous snake.

@export var rail_texture: Texture2D
@export var curve_texture: Texture2D
@export var tile_scale: float = 0.105
@export var path_step: float = 90.0
@export var track_bounds: Rect2 = Rect2(-330.0, -270.0, 660.0, 810.0)
## Minimum tiles a placed route must have to comfortably hold an engine plus
## a few cars (car_spacing 170 / path_step 90 ≈ 2 tiles per car).
@export var minimum_route_tiles: int = 6

## Local, grid-unit shapes. Every consecutive pair is exactly one cardinal
## step apart so the existing straight/curve rendering keeps working
## unmodified regardless of which module or rotation produced the point.
const MODULES := {
	"short_straight": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"long_straight": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)],
	"l_bend": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],
	"u_shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0)],
	"rectangle_loop": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 1)],
	"compact_circuit": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2)],
}

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
	var band_height: int = maxi(1, rows.size() / route_count)
	for band_index in range(route_count):
		var band_start: int = band_index * band_height
		var band_end: int = rows.size() if band_index == route_count - 1 else (band_index + 1) * band_height
		var route := _place_route(band_start, band_end, occupied)
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

## Tries a handful of random module/rotation/position combinations within
## the given row band, skipping any that would collide with already-placed
## track. Returns an empty array if none fit — the caller (generate_layout,
## and ultimately Main's retry loop) treats a short route list as valid too,
## as long as enough usable routes remain.
func _place_route(band_start: int, band_end: int, occupied: Dictionary) -> PackedVector2Array:
	var module_names := MODULES.keys()
	var band_height := band_end - band_start
	for attempt in range(12):
		var module_name: String = module_names[randi() % module_names.size()]
		var shape: Array = _transform_module(MODULES[module_name], randi_range(0, 3), randf() >= 0.5)
		var max_dx := 0
		var max_dy := 0
		for cell in shape:
			max_dx = maxi(max_dx, cell.x)
			max_dy = maxi(max_dy, cell.y)
		if max_dy >= band_height or max_dx >= columns.size():
			continue

		var row_origin: int = band_start + randi_range(0, band_height - max_dy - 1)
		var col_origin: int = randi_range(0, columns.size() - 1 - max_dx)
		var placed_cells: Array[Vector2i] = []
		var collides := false
		for cell in shape:
			var world_cell := Vector2i(col_origin + cell.x, row_origin + cell.y)
			if occupied.has(world_cell):
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

## Rotates a module by rotation_quarter * 90° (integer lattice rotation) and
## optionally mirrors it horizontally first, then re-anchors it back to a
## (0,0)-minimum origin so downstream placement math stays simple.
func _transform_module(base_points: Array, rotation_quarter: int, mirror: bool) -> Array:
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

func _render_route(route_points: PackedVector2Array) -> void:
	for index in range(route_points.size()):
		var shadow := Sprite2D.new()
		shadow.texture = rail_texture
		shadow.position = route_points[index] + Vector2(0.0, 7.0)
		shadow.modulate = Color(0.04, 0.035, 0.025, 0.38)
		shadow.z_index = -7
		var tile := Sprite2D.new()
		tile.position = route_points[index]
		tile.z_index = -5

		var previous_direction := Vector2.ZERO
		var next_direction := Vector2.ZERO
		if index > 0:
			previous_direction = (route_points[index - 1] - route_points[index]).normalized()
		if index < route_points.size() - 1:
			next_direction = (route_points[index + 1] - route_points[index]).normalized()

		if previous_direction != Vector2.ZERO and next_direction != Vector2.ZERO and not previous_direction.is_equal_approx(-next_direction):
			tile.texture = curve_texture
			tile.scale = Vector2(0.125, 0.125)
			tile.rotation = _curve_rotation(previous_direction, next_direction)
			shadow.texture = curve_texture
			shadow.scale = tile.scale * 1.08
			shadow.rotation = tile.rotation
		else:
			tile.texture = rail_texture
			# Source art is vertical: keep its width narrow while extending its
			# length slightly beyond the 90-unit path step to eliminate seams.
			tile.scale = Vector2(tile_scale, 0.125)
			var direction := next_direction if next_direction != Vector2.ZERO else previous_direction
			tile.rotation = PI * 0.5 if absf(direction.x) > 0.5 else 0.0
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
## the union of several short routes, not any single one, is what has to
## cover the board.
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

## Every route must be internally connected (each consecutive pair of points
## exactly one grid step apart) so a train can never stall mid-route — this
## is guaranteed by construction from the modules above, but a run-once
## check here catches any future module definition mistake immediately
## instead of surfacing as a silent stuck train in play.
func routes_are_traversable() -> bool:
	for route in routes:
		if route.size() < 2:
			return false
		for index in range(route.size() - 1):
			if route[index].distance_to(route[index + 1]) > path_step + 1.0:
				return false
	return true
