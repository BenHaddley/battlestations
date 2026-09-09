extends Node2D
class_name TrackRenderer
## Owns the railway: authored/generated closed loops, the player-built rail
## graph that grows off them during STATIONS, and the tile artwork for both.
##
## Two ideas are kept separate on purpose. `routes` are closed rings a train
## can drive (every consecutive pair exactly one grid step apart, wrapping at
## the end). `graph` is the built rail network: every route cell plus any
## player-built spur, which may dead-end or branch. Trains only ever drive
## routes; spurs exist as construction until they close a detour that a
## route adopts (see place_rail()).

signal network_changed
## A route's geometry changed (a detour was adopted or a rail removed). Main
## rebinds the convoys driving it once their consist sits on shared track.
signal route_changed(route_index: int, path: PackedVector2Array)

@export var rail_texture: Texture2D
@export var curve_texture: Texture2D
@export var end_texture: Texture2D = preload("res://assets/sprites/board/Rail End.png")
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

const ORTHOGONAL: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var columns: Array[float] = []
var rows: Array[float] = []
var routes: Array[PackedVector2Array] = []
## Rail graph: cell -> Array[Vector2i] of connected orthogonal neighbours.
var graph: Dictionary = {}
## Player-built cells (refundable), keyed by cell.
var built_cells: Dictionary = {}
## Bumped every time the graph or a route changes, so anything caching
## geometry (placement previews, pending rebinds) can tell it is stale.
var revision: int = 0

var _tiles_by_cell: Dictionary = {}

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
	_clear_network()
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

	_seed_graph_from_routes()
	_render_all()
	return routes

## Builds one deterministic campaign layout from the artist's red-line track
## sketches. Coordinates are integer cells on the live 9x12 board, so rails
## remain perfectly registered even though the source marks are freehand.
func generate_campaign_layout(layout_index: int) -> Array[PackedVector2Array]:
	_clear_network()
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
	_seed_graph_from_routes()
	_render_all()
	return routes

## A single compact crossing loop for Last Train Standing. The center cell is
## intentionally visited twice, once horizontally and once vertically, so the
## renderer layers two straight rail tiles into a proper tabletop crossing.
## It occupies only the bottom three battlefield rows and leaves the upper
## board entirely to the approaching spiders.
func generate_bottom_figure_eight() -> Array[PackedVector2Array]:
	_clear_network()
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
	_seed_graph_from_routes()
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

# ---------------------------------------------------------------------------
# Grid helpers
# ---------------------------------------------------------------------------

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns.size() and cell.y >= 0 and cell.y < rows.size()

func world_of(cell: Vector2i) -> Vector2:
	return Vector2(columns[cell.x], rows[cell.y])

## Nearest grid cell to a world position. Callers check in_bounds() and
## distance themselves; the pointer can hover between cells.
func cell_of(world: Vector2) -> Vector2i:
	return Vector2i(roundi((world.x - track_bounds.position.x) / path_step), roundi((world.y - track_bounds.position.y) / path_step))

func is_rail(cell: Vector2i) -> bool:
	return graph.has(cell)

func is_built(cell: Vector2i) -> bool:
	return built_cells.has(cell)

func neighbours(cell: Vector2i) -> Array:
	return graph.get(cell, [])

func rail_cells() -> Array:
	return graph.keys()

func route_cells(route_index: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if route_index < 0 or route_index >= routes.size():
		return cells
	for point in routes[route_index]:
		cells.append(cell_of(point))
	return cells

## Index of the first route that drives through this cell, or -1 for a spur.
func route_index_of(cell: Vector2i) -> int:
	for route_index in range(routes.size()):
		if cell in route_cells(route_index):
			return route_index
	return -1

## Empty, in-board cells orthogonally adjacent to an existing rail cell —
## exactly where the STATION hover shows its plus signs.
func expansion_candidates(anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_rail(anchor):
		return result
	for offset in ORTHOGONAL:
		var candidate := anchor + offset
		if in_bounds(candidate) and not is_rail(candidate):
			result.append(candidate)
	return result

# ---------------------------------------------------------------------------
# Rail graph
# ---------------------------------------------------------------------------

func _clear_network() -> void:
	for child in get_children():
		child.queue_free()
	graph = {}
	built_cells = {}
	_tiles_by_cell = {}
	revision += 1

func _seed_graph_from_routes() -> void:
	graph = {}
	built_cells = {}
	for route in routes:
		var count := route.size()
		for index in range(count):
			var a := cell_of(route[index])
			var b := cell_of(route[(index + 1) % count])
			_add_edge(a, b)
	revision += 1

func _add_edge(a: Vector2i, b: Vector2i) -> void:
	if a == b:
		return
	if not graph.has(a):
		graph[a] = []
	if not graph.has(b):
		graph[b] = []
	if not (b in graph[a]):
		graph[a].append(b)
	if not (a in graph[b]):
		graph[b].append(a)

func _remove_edge(a: Vector2i, b: Vector2i) -> void:
	if graph.has(a):
		graph[a].erase(b)
	if graph.has(b):
		graph[b].erase(a)

## Cells reachable from `start` through rail connections.
func network_of(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if not is_rail(start):
		return seen
	var frontier: Array[Vector2i] = [start]
	seen[start] = true
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for next in graph[cell]:
			if not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen

## Shortest rail path from `from` to `to`, avoiding `blocked` cells (the
## endpoints are always allowed). Empty when no path exists.
func shortest_path(from: Vector2i, to: Vector2i, blocked: Dictionary = {}) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not is_rail(from) or not is_rail(to):
		return path
	if from == to:
		path.append(from)
		return path
	var previous: Dictionary = {}
	previous[from] = from
	var frontier: Array[Vector2i] = [from]
	var head := 0
	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		for next in graph[cell]:
			if previous.has(next) or (blocked.has(next) and next != to):
				continue
			previous[next] = cell
			if next == to:
				var cursor := to
				while cursor != from:
					path.push_front(cursor)
					cursor = previous[cursor]
				path.push_front(from)
				return path
			frontier.append(next)
	return path

## Validates a build without changing anything. A new tile only ever
## connects to the tile it is extended from; joining it to anything else is
## the explicit link gesture below, so construction never surprises the
## player by fusing to rail that merely happens to be adjacent.
func evaluate_placement(anchor: Vector2i, cell: Vector2i) -> Dictionary:
	if not in_bounds(cell):
		return {"ok": false, "reason": "That tile is outside the courtyard."}
	if is_rail(cell):
		return {"ok": false, "reason": "That space already holds rail."}
	if not is_rail(anchor) or (anchor - cell).length_squared() != 1:
		return {"ok": false, "reason": "New rail must touch the rail you are extending."}
	return {"ok": true, "reason": ""}

## Lays one tile connected to `anchor`. Returns the evaluate_placement()
## verdict; never reroutes, because a fresh tile is always a dead end.
func place_rail(anchor: Vector2i, cell: Vector2i) -> Dictionary:
	var verdict := evaluate_placement(anchor, cell)
	if not verdict.ok:
		return verdict
	graph[cell] = []
	_add_edge(cell, anchor)
	built_cells[cell] = true
	revision += 1
	_render_all()
	network_changed.emit()
	return verdict

func is_dead_end(cell: Vector2i) -> bool:
	return is_rail(cell) and graph[cell].size() == 1

## Pairs [cell, target] the link gesture offers while hovering `cell`: a dead
## end can be joined to any adjacent unconnected rail of its own circuit, and
## hovering that rail offers the same join from the other side.
func link_candidates(cell: Vector2i) -> Array:
	var pairs: Array = []
	if not is_rail(cell):
		return pairs
	for offset in ORTHOGONAL:
		var target := cell + offset
		if evaluate_link(cell, target).ok:
			pairs.append([cell, target])
	return pairs

func evaluate_link(a: Vector2i, b: Vector2i) -> Dictionary:
	if not is_rail(a) or not is_rail(b):
		return {"ok": false, "reason": "Both ends of a link must be rail."}
	if (a - b).length_squared() != 1:
		return {"ok": false, "reason": "Only touching rails can be joined."}
	if b in graph[a]:
		return {"ok": false, "reason": "Those rails are already joined."}
	if not is_dead_end(a) and not is_dead_end(b):
		return {"ok": false, "reason": "Only a dead end can be joined to other rail."}
	if not network_of(a).has(b):
		return {"ok": false, "reason": "That would join two separate circuits. Extend one circuit at a time."}
	return {"ok": true, "reason": ""}

## Joins a dead end to adjacent rail. If the join closes a detour off a
## route and the detour is longer than the stretch it bypasses, the route is
## rerouted through it and route_changed fires for the convoys driving it.
## Returns the evaluate_link() verdict, extended with "rerouted": route
## index or -1.
func link_rail(a: Vector2i, b: Vector2i) -> Dictionary:
	var verdict := evaluate_link(a, b)
	if not verdict.ok:
		return verdict
	# Decide the reroute before the edge exists so the path between the two
	# ends runs the long way round through the circuit.
	var path := shortest_path(a, b)
	var reroute := _reroute_from_cycle(path)
	_add_edge(a, b)
	revision += 1
	verdict["rerouted"] = -1
	if not reroute.is_empty():
		var route_index: int = reroute.route_index
		routes[route_index] = _cells_to_points(reroute.cells)
		verdict["rerouted"] = route_index
		route_changed.emit(route_index, routes[route_index])
	_render_all()
	network_changed.emit()
	return verdict

## Removes a player-built tile. Refuses authored rail, tiles a convoy is
## standing on (the caller checks occupancy via `occupied`), and any removal
## that would split the circuit or leave a route with no way round the gap.
## Returns {"ok", "reason", "rerouted"}; a rerouted route emits route_changed.
func remove_rail(cell: Vector2i, occupied: bool = false) -> Dictionary:
	if not is_rail(cell):
		return {"ok": false, "reason": "There is no rail there.", "rerouted": -1}
	if not is_built(cell):
		return {"ok": false, "reason": "The station's own rails cannot be removed.", "rerouted": -1}
	if occupied:
		return {"ok": false, "reason": "A train is standing on that rail. Wait for it to pass.", "rerouted": -1}
	var route_index := route_index_of(cell)
	var repaired: Array[Vector2i] = []
	if route_index >= 0:
		repaired = _route_without_cell(route_index, cell)
		if repaired.is_empty():
			return {"ok": false, "reason": "Removing that rail would break a train's circuit.", "rerouted": -1}
	# Keep the network in one piece so no rail is ever stranded off the circuit.
	var links: Array = graph[cell].duplicate()
	if links.size() > 1:
		var without: Dictionary = {}
		without[cell] = true
		var reach := _network_excluding(links[0], without)
		for link in links:
			if not reach.has(link):
				return {"ok": false, "reason": "Removing that rail would strand the track beyond it.", "rerouted": -1}
	for link in links:
		_remove_edge(cell, link)
	graph.erase(cell)
	built_cells.erase(cell)
	revision += 1
	if route_index >= 0:
		routes[route_index] = _cells_to_points(repaired)
		route_changed.emit(route_index, routes[route_index])
	_render_all()
	network_changed.emit()
	return {"ok": true, "reason": "", "rerouted": route_index}

## Route that a locomotive dropped on `cell` can drive. An existing route is
## returned as its index; a closed player-built detour that no route uses yet
## becomes a new route. -1 when the rail dead-ends and cannot loop.
func route_for_engine(cell: Vector2i) -> int:
	var existing := route_index_of(cell)
	if existing >= 0:
		return existing
	var cycle := _cycle_through(cell)
	if cycle.size() < 4:
		return -1
	routes.append(_cells_to_points(cycle))
	revision += 1
	return routes.size() - 1

func _cells_to_points(cells: Array[Vector2i]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell in cells:
		points.append(world_of(cell))
	return points

func _network_excluding(start: Vector2i, excluded: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	if not is_rail(start) or excluded.has(start):
		return seen
	var frontier: Array[Vector2i] = [start]
	seen[start] = true
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for next in graph[cell]:
			if excluded.has(next) or seen.has(next):
				continue
			seen[next] = true
			frontier.append(next)
	return seen

## `path` is the existing rail path between the two ends being joined; with
## the new edge it forms a cycle. If the path runs along a route for one
## contiguous stretch (a..b) and the rest of the cycle is player-built rail
## longer than that stretch, the route adopts it as a detour. Everything else
## — shortcuts, spur-only cycles, lobes touching a route at a single cell —
## leaves routes alone.
func _reroute_from_cycle(path: Array[Vector2i]) -> Dictionary:
	if path.size() < 2:
		return {}
	for route_index in range(routes.size()):
		var cells := route_cells(route_index)
		var on_route: Array[int] = []
		for index in range(path.size()):
			if path[index] in cells:
				on_route.append(index)
		if on_route.size() < 2:
			continue
		# The route stretch must be one contiguous run in the middle of the
		# path; a detour that dips onto the route twice is not a simple bump.
		var start_index := on_route[0]
		var end_index := on_route[-1]
		if end_index - start_index != on_route.size() - 1:
			continue
		var a := path[start_index]
		var b := path[end_index]
		# The detour runs from b's side round the new edge to a's side.
		var detour: Array[Vector2i] = []
		for index in range(end_index + 1, path.size()):
			detour.append(path[index])
		for index in range(0, start_index):
			detour.append(path[index])
		# Only rail the player laid may become route; an authored siding never
		# gets stitched back in as a zigzag.
		var player_made := not detour.is_empty()
		for detour_cell in detour:
			if not is_built(detour_cell):
				player_made = false
				break
		if not player_made:
			continue
		var arc_edges := end_index - start_index
		var detour_edges := detour.size() + 1
		if detour_edges <= arc_edges:
			continue
		var rerouted := _splice_detour(cells, a, b, detour)
		if rerouted.is_empty():
			continue
		return {"route_index": route_index, "cells": rerouted}
	return {}

## Replaces the shorter route stretch between a and b with the detour, keeping
## the rest of the ring in its original driving order.
func _splice_detour(cells: Array[Vector2i], a: Vector2i, b: Vector2i, detour_from_b: Array[Vector2i]) -> Array[Vector2i]:
	var count := cells.size()
	var index_a := cells.find(a)
	var index_b := cells.find(b)
	if index_a < 0 or index_b < 0 or index_a == index_b:
		return []
	var forward_steps := (index_b - index_a + count) % count
	var backward_steps := (index_a - index_b + count) % count
	var result: Array[Vector2i] = []
	if forward_steps <= backward_steps:
		# The bypassed stretch runs a -> b in driving order. Keep b -> ... -> a,
		# then take the detour from a back round to b.
		var cursor := index_b
		while true:
			result.append(cells[cursor])
			if cursor == index_a:
				break
			cursor = (cursor + 1) % count
		var detour := detour_from_b.duplicate()
		detour.reverse()
		result.append_array(detour)
	else:
		var cursor := index_a
		while true:
			result.append(cells[cursor])
			if cursor == index_b:
				break
			cursor = (cursor + 1) % count
		result.append_array(detour_from_b)
	if result.size() < 4 or not _ring_is_valid(result):
		return []
	return result

func _ring_is_valid(cells: Array[Vector2i]) -> bool:
	var seen: Dictionary = {}
	for index in range(cells.size()):
		if seen.has(cells[index]):
			return false
		seen[cells[index]] = true
		var next := cells[(index + 1) % cells.size()]
		if (next - cells[index]).length_squared() != 1:
			return false
	return true

## Route ring after lifting `cell`. Lifting any tile of a player-built detour
## drops the whole detour from the route: the stretch of consecutive built
## cells around it is replaced by the shortest rail path between the
## authored cells on either side (normally the stretch the detour bypassed).
## The other detour tiles stay on the board as spurs. Empty when no such
## path exists, meaning the route would be broken.
func _route_without_cell(route_index: int, cell: Vector2i) -> Array[Vector2i]:
	var cells := route_cells(route_index)
	var index := cells.find(cell)
	if index < 0:
		return []
	var count := cells.size()
	var run_start := index
	while is_built(cells[(run_start - 1 + count) % count]) and (run_start - 1 + count) % count != index:
		run_start = (run_start - 1 + count) % count
	var run_end := index
	while is_built(cells[(run_end + 1) % count]) and (run_end + 1) % count != index:
		run_end = (run_end + 1) % count
	var run: Dictionary = {}
	var cursor := run_start
	while true:
		run[cells[cursor]] = true
		if cursor == run_end:
			break
		cursor = (cursor + 1) % count
	if run.size() >= count - 1:
		return []
	var before := cells[(run_start - 1 + count) % count]
	var after := cells[(run_end + 1) % count]
	var blocked: Dictionary = {}
	blocked[cell] = true
	for other in cells:
		if other != before and other != after and not run.has(other):
			blocked[other] = true
	var bridge := shortest_path(before, after, blocked)
	if bridge.is_empty():
		return []
	var result: Array[Vector2i] = []
	# Walk the ring from `after` round to `before`, then bridge back.
	cursor = (run_end + 1) % count
	while true:
		result.append(cells[cursor])
		if cells[cursor] == before:
			break
		cursor = (cursor + 1) % count
	for bridge_index in range(1, bridge.size() - 1):
		result.append(bridge[bridge_index])
	if not _ring_is_valid(result):
		return []
	return result

## Longest simple cycle through `cell`, found by bounded depth-first search.
## Rail networks are tiny (at most 108 cells) and mostly loops, so the budget
## is generous in practice and merely guards against pathological ladders.
func _cycle_through(cell: Vector2i) -> Array[Vector2i]:
	if not is_rail(cell) or graph[cell].size() < 2:
		return []
	var best: Array[Vector2i] = []
	var budget := [6000]
	var visited: Dictionary = {}
	visited[cell] = true
	var trail: Array[Vector2i] = [cell]
	_cycle_search(cell, cell, visited, trail, best, budget)
	return best

func _cycle_search(origin: Vector2i, cell: Vector2i, visited: Dictionary, trail: Array[Vector2i], best: Array[Vector2i], budget: Array) -> void:
	if budget[0] <= 0:
		return
	budget[0] -= 1
	for next in graph[cell]:
		if next == origin and trail.size() >= 4:
			if trail.size() > best.size():
				best.assign(trail)
			continue
		if visited.has(next):
			continue
		visited[next] = true
		trail.append(next)
		_cycle_search(origin, next, visited, trail, best, budget)
		trail.pop_back()
		visited.erase(next)

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _render_all() -> void:
	for child in get_children():
		child.queue_free()
	_tiles_by_cell = {}
	for cell in graph:
		_render_cell(cell)

## Draws one cell from its connection set rather than its position in a
## route, so authored rings, junctions, crossings and dead ends all share one
## rule: one straight per collinear pair, one curve per perpendicular pair,
## and the buffer-stop end cap wherever only a single rail leaves the tile.
func _render_cell(cell: Vector2i) -> void:
	var point := world_of(cell)
	var directions: Array[Vector2i] = []
	for neighbour in graph[cell]:
		directions.append(neighbour - cell)
	var pieces: Array[Dictionary] = []
	match directions.size():
		0:
			pieces.append({"kind": "end", "rotation": 0.0})
		1:
			pieces.append({"kind": "end", "rotation": _end_rotation(directions[0])})
		2:
			pieces.append(_pair_piece(directions[0], directions[1]))
		_:
			pieces = _junction_pieces(cell, directions)
	var sprites: Array[Sprite2D] = []
	for piece in pieces:
		var texture: Texture2D = rail_texture
		match String(piece.kind):
			"curve": texture = curve_texture
			"end": texture = end_texture
		var shadow := Sprite2D.new()
		shadow.texture = texture
		shadow.position = point + Vector2(0.0, 7.0)
		shadow.modulate = Color(0.04, 0.035, 0.025, 0.38)
		shadow.z_index = -7
		shadow.scale = Vector2(tile_scale * 1.1, tile_scale * 1.06)
		shadow.rotation = float(piece.rotation)
		add_child(shadow)
		var tile := Sprite2D.new()
		tile.texture = texture
		tile.position = point
		tile.z_index = -5
		tile.scale = Vector2(tile_scale, tile_scale)
		tile.rotation = float(piece.rotation)
		tile.set_meta("piece", String(piece.kind))
		add_child(tile)
		sprites.append(tile)
	_tiles_by_cell[cell] = sprites

## Sprites currently drawn for a cell — used by tests and the rail builder's
## hover treatment.
func tiles_at(cell: Vector2i) -> Array:
	return _tiles_by_cell.get(cell, [])

func _pair_piece(a: Vector2i, b: Vector2i) -> Dictionary:
	if a == -b:
		return {"kind": "straight", "rotation": PI * 0.5 if a.x != 0 else 0.0}
	return {"kind": "curve", "rotation": _curve_rotation(Vector2(a), Vector2(b))}

## Three or four connections. A route driving through the cell decides how the
## rails pair up (a lobe returning to its own junction is two curves, a
## crossing is two straights); anything the routes do not explain falls back
## to a straight through the collinear pair plus a curve for the odd branch.
func _junction_pieces(cell: Vector2i, directions: Array[Vector2i]) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	var paired: Dictionary = {}
	for pairing in _route_pairings(cell):
		var a: Vector2i = pairing[0]
		var b: Vector2i = pairing[1]
		if paired.has(a) or paired.has(b) or not (a in directions) or not (b in directions):
			continue
		paired[a] = true
		paired[b] = true
		pieces.append(_pair_piece(a, b))
	var remaining: Array[Vector2i] = []
	for direction in directions:
		if not paired.has(direction):
			remaining.append(direction)
	while remaining.size() >= 2:
		var a: Vector2i = remaining.pop_front()
		var partner_index := -1
		for index in range(remaining.size()):
			if remaining[index] == -a:
				partner_index = index
				break
		if partner_index < 0:
			partner_index = 0
		var b: Vector2i = remaining[partner_index]
		remaining.remove_at(partner_index)
		pieces.append(_pair_piece(a, b))
	if remaining.size() == 1:
		# A branch with no partner still needs a curve into the through-line so
		# the switch reads as connected rather than a floating stub.
		var stub: Vector2i = remaining[0]
		var through: Vector2i = directions[0] if directions[0] != stub else directions[1]
		pieces.append(_pair_piece(stub, through))
	return pieces

func _route_pairings(cell: Vector2i) -> Array:
	var pairings: Array = []
	for route in routes:
		var count := route.size()
		for index in range(count):
			if cell_of(route[index]) != cell:
				continue
			var previous := cell_of(route[(index - 1 + count) % count]) - cell
			var next := cell_of(route[(index + 1) % count]) - cell
			pairings.append([previous, next])
	return pairings

## Source art: buffer stop at the top, open rail at the bottom.
func _end_rotation(open_direction: Vector2i) -> float:
	return Vector2(open_direction).angle() - PI * 0.5

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
