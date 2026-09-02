extends Button
## Keeps the input rectangle fixed while animating only the illustrated plate.

@export var button_texture: Texture2D
@export_range(1.0, 1.1, 0.005) var hover_scale := 1.055
@export_range(0.8, 1.0, 0.005) var pressed_scale := 0.965
@export_range(0.01, 0.5, 0.01) var animation_time := 0.11

var _tween: Tween
var _hovered := false
var _visual: TextureRect

func _ready() -> void:
	_build_visual()
	resized.connect(_update_visual_pivot)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(func() -> void: _animate_to(pressed_scale))
	button_up.connect(func() -> void: _animate_to(hover_scale if _hovered else 1.0))
	_update_visual_pivot()

func _build_visual() -> void:
	flat = true
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_visual = TextureRect.new()
	_visual.name = "Visual"
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.texture = button_texture
	_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_visual.stretch_mode = TextureRect.STRETCH_SCALE
	_visual.show_behind_parent = true
	add_child(_visual)

func _update_visual_pivot() -> void:
	if _visual:
		_visual.pivot_offset = _visual.size * 0.5

func _on_mouse_entered() -> void:
	_hovered = true
	z_index = 5
	_animate_to(hover_scale)

func _on_mouse_exited() -> void:
	_hovered = false
	z_index = 0
	_animate_to(1.0)

func _animate_to(target_scale: float) -> void:
	if not _visual:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_visual, "scale", Vector2.ONE * target_scale, animation_time)
