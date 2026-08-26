extends Node2D
## Compatibility node only. THE_BOARD.png already contains the authored tile
## surface. Painting another grid here doubles its seams and creates the broken
## brick pattern, so this overlay deliberately renders nothing.

@export var light_tile: Texture2D
@export var dark_tile: Texture2D
@export var bounds: Rect2 = Rect2(-330.0, -270.0, 660.0, 810.0)
@export var cell_size: float = 90.0

func _ready() -> void:
	visible = false
