extends TextureButton
## Gives the illustrated title-screen plates a tactile hover and press response.

@export_range(1.0, 1.25, 0.005) var hover_scale := 1.065
@export_range(0.8, 1.0, 0.005) var pressed_scale := 0.965
@export_range(0.01, 0.5, 0.01) var animation_time := 0.11

var _tween: Tween
var _hovered := false

func _ready() -> void:
	resized.connect(_update_pivot)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(func() -> void: _animate_to(pressed_scale))
	button_up.connect(func() -> void: _animate_to(hover_scale if _hovered else 1.0))
	_update_pivot()

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func _on_mouse_entered() -> void:
	_hovered = true
	z_index = 5
	_animate_to(hover_scale)

func _on_mouse_exited() -> void:
	_hovered = false
	z_index = 0
	_animate_to(1.0)

func _animate_to(target_scale: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * target_scale, animation_time)
