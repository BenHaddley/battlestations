extends TextureRect
class_name GifPlayer
## Godot's importer only keeps the first frame of a .gif — this cycles a
## pre-extracted frame sequence on a timer to reproduce the animation.

@export var frames: Array[Texture2D] = []
@export var frame_duration: float = 0.15

var _index: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	if not frames.is_empty():
		texture = frames[0]

func _process(delta: float) -> void:
	if frames.size() <= 1:
		return
	_elapsed += delta
	if _elapsed >= frame_duration:
		_elapsed -= frame_duration
		_index = (_index + 1) % frames.size()
		texture = frames[_index]
