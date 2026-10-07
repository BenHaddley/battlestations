extends Button
## Authored A/B plates. The parallelogram is shared by drawing and hit testing,
## so the transparent corners never steal clicks from a neighbouring tile.

@export var normal_texture: Texture2D
@export var hover_texture: Texture2D
@export var label: String
@export var slant := 0.328

func _ready() -> void:
	flat = true
	accessibility_name = label
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _on_mouse_entered() -> void:
	# Return to pointer navigation without leaving a second label lit up.
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and focused.get_script() == get_script():
		focused.release_focus()
	queue_redraw()

func _polygon() -> PackedVector2Array:
	var skew := size.y * slant
	return PackedVector2Array([Vector2(skew, 0), Vector2(size.x, 0),
		Vector2(size.x - skew, size.y), Vector2(0, size.y)])

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _polygon())

func _draw() -> void:
	var texture := hover_texture if (is_hovered() or has_focus() or is_pressed()) and not disabled else normal_texture
	if texture == null or size.x <= 0 or size.y <= 0:
		return
	var polygon := _polygon()
	var uv := PackedVector2Array()
	for point in polygon:
		uv.append(point / size)
	draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, texture)
