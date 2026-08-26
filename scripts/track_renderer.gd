extends Node2D
class_name TrackRenderer
## Generates one connected, bounded railway per run. Horizontal sweeps cross
## every spider lane and alternating edge connectors create real turns.

@export var rail_texture: Texture2D
@export var curve_texture: Texture2D
@export var tile_scale: float = 0.105
@export var path_step: float = 90.0
@export var track_bounds: Rect2 = Rect2(-330.0, -270.0, 660.0, 810.0)
@export_range(4, 5) var minimum_sweeps: int = 5
@export_range(4, 5) var maximum_sweeps: int = 5

var path_points: PackedVector2Array = PackedVector2Array()

func generate_layout() -> PackedVector2Array:
	randomize()
	for child in get_children():
		child.queue_free()

	var columns: Array[float] = []
	var rows: Array[float] = []
	var x := track_bounds.position.x
	while x <= track_bounds.end.x + 0.1:
		columns.append(x)
		x += path_step
	var y := track_bounds.position.y
	while y <= track_bounds.end.y + 0.1:
		rows.append(y)
		y += path_step

	var sweep_count: int = randi_range(minimum_sweeps, maximum_sweeps)
	var selected_row_indices: Array[int] = [randi_range(0, 2), rows.size() / 2, randi_range(rows.size() - 3, rows.size() - 1)]
	while selected_row_indices.size() < sweep_count:
		var candidate := randi_range(1, rows.size() - 2)
		if candidate not in selected_row_indices:
			selected_row_indices.append(candidate)
	selected_row_indices.sort()

	path_points = PackedVector2Array()
	var left_to_right := randf() >= 0.5
	for sweep_i in range(selected_row_indices.size()):
		var row_index: int = selected_row_indices[sweep_i]
		var ordered_columns := columns.duplicate()
		if not left_to_right:
			ordered_columns.reverse()
		for column_x in ordered_columns:
			_append_unique(Vector2(column_x, rows[row_index]))

		if sweep_i < selected_row_indices.size() - 1:
			var next_row_index: int = selected_row_indices[sweep_i + 1]
			var edge_x: float = ordered_columns[-1]
			for connector_row in range(row_index + 1, next_row_index + 1):
				_append_unique(Vector2(edge_x, rows[connector_row]))
		left_to_right = not left_to_right

	_render_path()
	return path_points

func _append_unique(point: Vector2) -> void:
	if path_points.is_empty() or not path_points[-1].is_equal_approx(point):
		path_points.append(point)

func _render_path() -> void:
	for index in range(path_points.size()):
		var shadow := Sprite2D.new()
		shadow.texture = rail_texture
		shadow.position = path_points[index] + Vector2(0.0, 7.0)
		shadow.modulate = Color(0.04, 0.035, 0.025, 0.38)
		shadow.z_index = -7
		var tile := Sprite2D.new()
		tile.position = path_points[index]
		tile.z_index = -5

		var previous_direction := Vector2.ZERO
		var next_direction := Vector2.ZERO
		if index > 0:
			previous_direction = (path_points[index - 1] - path_points[index]).normalized()
		if index < path_points.size() - 1:
			next_direction = (path_points[index + 1] - path_points[index]).normalized()

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

func get_drop_target(world_position: Vector2, tolerance: float) -> Dictionary:
	var nearest_index := -1
	var nearest_distance := INF
	for index in range(path_points.size()):
		var distance := world_position.distance_to(path_points[index])
		if distance < nearest_distance:
			nearest_index = index
			nearest_distance = distance
	return {
		"valid": nearest_index >= 0 and nearest_distance <= tolerance,
		"index": nearest_index,
		"position": path_points[nearest_index] if nearest_index >= 0 else Vector2.ZERO,
	}

func covers_lanes(lane_x_positions: PackedFloat32Array, weapon_range: float) -> bool:
	for lane_x in lane_x_positions:
		var covered := false
		for point in path_points:
			if absf(point.x - lane_x) <= weapon_range:
				covered = true
				break
		if not covered:
			return false
	return true

func set_drag_active(active: bool) -> void:
	var tint := Color(1.0, 0.85, 0.35, 1.0) if active else Color.WHITE
	for tile in get_children():
		if tile is Sprite2D:
			tile.modulate = tint
