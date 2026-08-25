extends Node2D
class_name TrackRenderer
## Lays a strip of rail tiles down each lane so the enemy route reads as an
## actual railway instead of empty ground. Driven by Main from
## EnemySpawner's lane data, so the visuals can never drift out of sync
## with where enemies actually walk.

@export var rail_texture: Texture2D
@export var tile_scale: float = 0.12

func build(lane_x_positions: PackedFloat32Array, spawn_y: float, leak_y: float) -> void:
	for child in get_children():
		child.queue_free()

	if rail_texture == null or lane_x_positions.is_empty():
		return

	var tile_height: float = rail_texture.get_height() * tile_scale
	var step_count: int = ceili((leak_y - spawn_y) / tile_height)

	for lane_x in lane_x_positions:
		for i in range(step_count):
			var tile := Sprite2D.new()
			tile.texture = rail_texture
			tile.scale = Vector2(tile_scale, tile_scale)
			tile.position = Vector2(lane_x, spawn_y + tile_height * 0.5 + i * tile_height)
			tile.z_index = -5
			add_child(tile)
