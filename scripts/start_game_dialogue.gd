extends Control
class_name StartGameDialogue

signal continue_selected
signal restart_selected
signal closed

const DAISY := preload("res://dasiyTalking.png")

var artwork: TextureRect
var dialogue_label: Label
var continue_button: Button
var restart_button: Button
var back_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_refresh_type_scale)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.012, 0.01, 0.48)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	artwork = TextureRect.new()
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.texture = DAISY
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)

	dialogue_label = Label.new()
	dialogue_label.anchor_left = 0.285
	dialogue_label.anchor_top = 0.70
	dialogue_label.anchor_right = 0.72
	dialogue_label.anchor_bottom = 0.83
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_label.clip_text = true
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_color_override("font_color", Color("fff7e4"))
	dialogue_label.add_theme_color_override("font_outline_color", Color("050505"))
	dialogue_label.add_theme_constant_override("outline_size", 5)
	add_child(dialogue_label)

	continue_button = _make_choice_button("CONTINUE GAME", Color("497b4d"))
	continue_button.anchor_left = 0.30
	continue_button.anchor_top = 0.835
	continue_button.anchor_right = 0.49
	continue_button.anchor_bottom = 0.91
	continue_button.pressed.connect(func() -> void: continue_selected.emit())
	add_child(continue_button)

	restart_button = _make_choice_button("RESTART GAME", Color("a63a2f"))
	restart_button.anchor_left = 0.51
	restart_button.anchor_top = 0.835
	restart_button.anchor_right = 0.70
	restart_button.anchor_bottom = 0.91
	restart_button.pressed.connect(func() -> void: restart_selected.emit())
	add_child(restart_button)

	back_button = Button.new()
	back_button.anchor_left = 0.89
	back_button.anchor_top = 0.025
	back_button.anchor_right = 0.985
	back_button.anchor_bottom = 0.075
	back_button.text = "ESC  BACK"
	back_button.flat = true
	back_button.add_theme_color_override("font_color", Color("fff1d0"))
	back_button.add_theme_color_override("font_outline_color", Color("17100b"))
	back_button.add_theme_constant_override("outline_size", 5)
	back_button.pressed.connect(close)
	add_child(back_button)

	_refresh_type_scale()
	visible = false

func open(has_save: bool) -> void:
	visible = true
	continue_button.disabled = not has_save
	if has_save:
		dialogue_label.text = "Welcome back. We can continue from your last station, or restart from the beginning."
		restart_button.text = "RESTART GAME"
		continue_button.grab_focus()
	else:
		dialogue_label.text = "There is no journey to continue yet. Start a new game from the beginning."
		restart_button.text = "START NEW GAME"
		restart_button.grab_focus()

func close() -> void:
	visible = false
	closed.emit()

func _make_choice_button(label: String, fill: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", Color("fff3d6"))
	button.add_theme_color_override("font_disabled_color", Color(0.75, 0.72, 0.65, 0.58))
	button.add_theme_color_override("font_outline_color", Color("21130c"))
	button.add_theme_constant_override("outline_size", 5)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("21130c")
	style.set_border_width_all(4)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 5
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_stylebox_override("focus", style.duplicate())
	return button

func _refresh_type_scale() -> void:
	var width := size.x if size.x > 0 else 1280.0
	var body := clampi(roundi(width / 58.0), 18, 24)
	dialogue_label.add_theme_font_size_override("font_size", body)
	continue_button.add_theme_font_size_override("font_size", clampi(body - 2, 17, 25))
	restart_button.add_theme_font_size_override("font_size", clampi(body - 2, 17, 25))
	back_button.add_theme_font_size_override("font_size", clampi(body - 9, 12, 17))

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
