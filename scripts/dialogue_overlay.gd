extends Control
class_name DialogueOverlay

signal advance_requested
signal skip_requested

const DUCK := preload("res://duckTalking.png")
const DAISY := preload("res://dasiyTalking.png")

var artwork: TextureRect
var dialogue_label: Label
var prompt_label: Label
var skip_button: Button
var waiting_for_action := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	artwork = TextureRect.new()
	artwork.position = Vector2(280, 292)
	artwork.size = Vector2(720, 405)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_STOP
	artwork.gui_input.connect(_on_artwork_input)
	add_child(artwork)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(470, 548)
	dialogue_label.size = Vector2(365, 116)
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_label.add_theme_color_override("font_color", Color("fff7e4"))
	dialogue_label.add_theme_color_override("font_outline_color", Color("050505"))
	dialogue_label.add_theme_constant_override("outline_size", 3)
	dialogue_label.add_theme_font_size_override("font_size", 22)
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(dialogue_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(700, 660)
	prompt_label.size = Vector2(125, 22)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.add_theme_color_override("font_color", Color("99dcff"))
	prompt_label.add_theme_font_size_override("font_size", 13)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(prompt_label)

	skip_button = Button.new()
	skip_button.position = Vector2(1082, 18)
	skip_button.size = Vector2(174, 38)
	skip_button.text = "SKIP DIALOGUE"
	skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_button.add_theme_color_override("font_color", Color("fff1cf"))
	skip_button.add_theme_font_size_override("font_size", 16)
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = Color("702016")
	skip_style.border_color = Color("1d100b")
	skip_style.set_border_width_all(3)
	skip_style.corner_radius_top_left = 3
	skip_style.corner_radius_top_right = 7
	skip_style.corner_radius_bottom_left = 6
	skip_style.corner_radius_bottom_right = 2
	skip_button.add_theme_stylebox_override("normal", skip_style)
	skip_button.pressed.connect(func() -> void: skip_requested.emit())
	add_child(skip_button)
	visible = false

func show_entry(entry: Dictionary) -> void:
	var speaker := String(entry.get("speaker", "Duck"))
	artwork.texture = DAISY if speaker.to_lower() == "daisy" else DUCK
	dialogue_label.text = String(entry.get("text", ""))
	waiting_for_action = not String(entry.get("wait_for", "")).is_empty()
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE if waiting_for_action else Control.MOUSE_FILTER_STOP
	prompt_label.text = String(entry.get("action_hint", "DO THAT TO CONTINUE")) if waiting_for_action else "CLICK / SPACE  ▶"
	visible = true

func _on_artwork_input(event: InputEvent) -> void:
	if not waiting_for_action and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and not waiting_for_action and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")):
		advance_requested.emit()
		get_viewport().set_input_as_handled()
