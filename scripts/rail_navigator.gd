extends RefCounted
class_name RailNavigator
## A tape of the actual rail edges occupied by the consist. Both ends can
## grow, so backing out of a buffer preserves every car's order and facing.

var track: TrackRenderer
var points := PackedVector2Array()
var distance := 0.0
var visits: Dictionary = {}
var buffer_hit := false
var known_revision := -1
var stranded := false

func setup(renderer: TrackRenderer, ring: PackedVector2Array, engine_distance: float, tail: float) -> void:
	track = renderer
	var metrics := TrainConvoy._metrics_for(ring)
	var sample := TrainConvoy._sample_on(ring, metrics.starts, metrics.length, engine_distance)
	var index := int(sample.index)
	var behind := ceili(tail / track.path_step) + 2
	# Routes contain one point per rail tile.
	for offset in range(-behind, 2):
		points.append(ring[posmod(index + offset, ring.size())])
	distance = float(behind) * track.path_step + Vector2(sample.position).distance_to(ring[index])

func setup_edge(renderer: TrackRenderer, start: Vector2, finish: Vector2, position: Vector2) -> void:
	track = renderer
	points = PackedVector2Array([start, finish])
	distance = start.distance_to(position)

func length() -> float:
	return maxf(0.0, (points.size() - 1) * track.path_step)

func sample(at: float) -> Dictionary:
	var clamped := clampf(at, 0.0, length())
	var index := mini(int(clamped / track.path_step), points.size() - 2)
	var weight := (clamped - index * track.path_step) / track.path_step
	var position := points[index].lerp(points[index + 1], weight)
	return {"position": position, "direction": (points[index + 1] - points[index]).normalized(), "index": index}

func _extend(front: bool) -> bool:
	var tip := track.cell_of(points[-1] if front else points[0])
	var previous := track.cell_of(points[-2] if front else points[1])
	var choices: Array = track.graph.get(tip, []).duplicate()
	choices.erase(previous)
	if choices.is_empty():
		return false
	var best: Vector2i = choices[0]
	var best_score := INF
	for value in choices:
		var cell: Vector2i = value
		# Fresh branches win; thereafter balance use, preferring straight rails.
		var score := float(visits.get(_edge_key(tip, cell), 0)) * 10.0
		if cell - tip != tip - previous:
			score += 1.0
		if track.built_cells.has(cell):
			score -= 2.0
		if score < best_score:
			best_score = score
			best = cell
	var key := _edge_key(tip, best)
	visits[key] = int(visits.get(key, 0)) + 1
	if front:
		points.append(track.world_of(best))
	else:
		points.insert(0, track.world_of(best))
		distance += track.path_step
	return true

func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var first := str(a)
	var second := str(b)
	return first + ":" + second if first < second else second + ":" + first

func ensure_tail(tail: float) -> bool:
	while distance < tail:
		if not _extend(false):
			return false
	return true

func valid(at: float, count: int, spacing: float, clearance: float) -> bool:
	if at < count * spacing - 0.01 or at > length() + 0.01:
		return false
	for first in range(count + 1):
		for second in range(first + 2, count + 1):
			if Vector2(sample(at - first * spacing).position).distance_to(sample(at - second * spacing).position) < clearance:
				return false
	return true

func advance(amount: float, count: int, spacing: float, clearance: float) -> bool:
	buffer_hit = false
	_refresh_network(count * spacing)
	if stranded:
		return false
	var tail := count * spacing
	var remaining := absf(amount)
	var forward := amount >= 0.0
	while remaining > 0.001:
		var step := minf(remaining, 6.0)
		var room := length() - distance if forward else distance - tail
		if room < step:
			if _extend(forward):
				continue
			step = maxf(room, 0.0)
			buffer_hit = true
		var candidate := distance + step * (1.0 if forward else -1.0)
		if not valid(candidate, count, spacing, clearance):
			return false
		distance = candidate
		remaining -= step
		if buffer_hit:
			break
	# Keep one extra tile beyond either end; future junction choices remain live.
	while distance - tail > track.path_step * 2.0:
		points.remove_at(0)
		distance -= track.path_step
	while length() - distance > track.path_step * 2.0:
		points.resize(points.size() - 1)
	return true

func _refresh_network(tail: float) -> void:
	if known_revision == track.revision:
		return
	known_revision = track.revision
	stranded = false
	# Discard any unoccupied future rail that was lifted while building.
	for index in range(points.size() - 1):
		var a := track.cell_of(points[index])
		var b := track.cell_of(points[index + 1])
		if b in track.graph.get(a, []):
			continue
		if index * track.path_step >= distance - 0.01:
			points.resize(index + 1)
			break
	var remove_count := 0
	for index in range(points.size() - 1):
		if (index + 1) * track.path_step > distance - tail + 0.01:
			break
		var a := track.cell_of(points[index])
		var b := track.cell_of(points[index + 1])
		if b not in track.graph.get(a, []):
			remove_count = index + 1
	if remove_count > 0:
		points = points.slice(remove_count)
		distance -= remove_count * track.path_step
	if points.size() < 2:
		var cell := track.cell_of(points[0])
		var neighbors: Array = track.graph.get(cell, [])
		if neighbors.is_empty():
			stranded = true
			points.append(points[0])
		else:
			points.append(track.world_of(neighbors[0]))
		distance = 0.0
