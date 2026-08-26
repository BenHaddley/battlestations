extends Node2D
## Paints the illustrated checkerboard field inside the board frame. Shares
## track_renderer.gd's grid constants so the tiles line up with the rail
## and lane coordinates rather than being a separately-tuned overlay.

@export var light_tile: Texture2D
@export var dark_tile: Texture2D
@export var bounds: Rect2 = Rect2(-330.0, -270.0, 660.0, 810.0)
@export var cell_size: float = 90.0

func _ready() -> void:
	_build_grid()

func _build_grid() -> void:
	if light_tile == null or dark_tile == null:
		return
	var columns: int = ceili(bounds.size.x / cell_size)
	var rows: int = ceili(bounds.size.y / cell_size)
	var light_size: Vector2 = light_tile.get_size()
	for row in range(rows):
		for col in range(columns):
			var tile := Sprite2D.new()
			tile.texture = dark_tile if (row + col) % 2 == 0 else light_tile
			tile.centered = false
			tile.position = bounds.position + Vector2(col * cell_size, row * cell_size)
			if light_size.x > 0.0 and light_size.y > 0.0:
				tile.scale = Vector2(cell_size / light_size.x, cell_size / light_size.y)
			add_child(tile)
