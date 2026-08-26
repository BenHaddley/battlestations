extends Control
class_name DialogueOverlay

signal advance_requested
signal skip_requested

const DUCK := preload("res://duckTalking.png")
const DAISY := preload("res://dasiyTalking.png")

var artwork: TextureRect
var dialogue_label: Label
var continue_label: Label
var skip_button: Button
var objective_panel: PanelContainer
var objective_label: Label
var waiting_for_action := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_refresh_type_scale)

	# Each supplied image is already a complete 16:9 visual-novel composition:
	# Duck at the left, Daisy at the right, and its own opaque comic dialogue box.
	artwork = TextureRect.new()
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_STOP
	artwork.gui_input.connect(_on_artwork_input)
	add_child(artwork)

	# Safe area measured from the existing black box. It starts below both
	# nameplates, so the supplied speaker artwork can never cover line one.
	dialogue_label = Label.new()
	dialogue_label.anchor_left = 0.285
	dialogue_label.anchor_top = 0.735
	dialogue_label.anchor_right = 0.72
	dialogue_label.anchor_bottom = 0.91
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_label.clip_text = true
	dialogue_label.add_theme_color_override("font_color", Color("fff7e4"))
	dialogue_label.add_theme_color_override("font_outline_color", Color("050505"))
	dialogue_label.add_theme_constant_override("outline_size", 3)
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(dialogue_label)

	continue_label = Label.new()
	continue_label.anchor_left = 0.58
	continue_label.anchor_top = 0.905
	continue_label.anchor_right = 0.715
	continue_label.anchor_bottom = 0.945
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_label.text = "CLICK TO CONTINUE  ▶"
	continue_label.add_theme_color_override("font_color", Color("9bdcff"))
	continue_label.add_theme_color_override("font_outline_color", Color("050505"))
	continue_label.add_theme_constant_override("outline_size", 2)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(continue_label)

	# Quiet and secondary: no large red control fighting the regular right HUD.
	skip_button = Button.new()
	skip_button.anchor_left = 0.885
	skip_button.anchor_top = 0.025
	skip_button.anchor_right = 0.985
	skip_button.anchor_bottom = 0.075
	skip_button.text = "[ESC] Skip"
	skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_button.flat = true
	skip_button.add_theme_color_override("font_color", Color(1, 0.94, 0.82, 0.82))
	skip_button.add_theme_color_override("font_hover_color", Color("ffffff"))
	skip_button.add_theme_color_override("font_outline_color", Color("16100b"))
	skip_button.add_theme_constant_override("outline_size", 3)
	skip_button.pressed.connect(func() -> void: skip_requested.emit())
	add_child(skip_button)

	_build_objective_tag()
	_refresh_type_scale()
	visible = false

func _build_objective_tag() -> void:
	objective_panel = PanelContainer.new()
	objective_panel.anchor_left = 0.30
	objective_panel.anchor_top = 0.035
	objective_panel.anchor_right = 0.70
	objective_panel.anchor_bottom = 0.105
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("efe0b8")
	style.border_color = Color("2a190f")
	style.set_border_width_all(4)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 2
	style.shadow_color = Color(0.04, 0.02, 0.01, 0.55)
	style.shadow_size = 5
	objective_panel.add_theme_stylebox_override("panel", style)
	add_child(objective_panel)
	objective_label = Label.new()
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.add_theme_color_override("font_color", Color("371d11"))
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_panel.add_child(objective_label)
	objective_panel.visible = false

func show_entry(entry: Dictionary) -> void:
	var speaker := String(entry.get("speaker", "Duck"))
	artwork.texture = DAISY if speaker.to_lower() == "daisy" else DUCK
	dialogue_label.text = String(entry.get("text", ""))
	waiting_for_action = false
	artwork.visible = true
	dialogue_label.visible = true
	continue_label.visible = true
	objective_panel.visible = false
	artwork.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true

func show_objective(objective: String) -> void:
	waiting_for_action = true
	artwork.visible = false
	dialogue_label.visible = false
	continue_label.visible = false
	objective_label.text = "OBJECTIVE — %s" % objective
	objective_panel.visible = true
	visible = true

func _refresh_type_scale() -> void:
	var width := size.x if size.x > 0 else 1280.0
	var body_size := clampi(roundi(width / 52.0), 18, 28)
	dialogue_label.add_theme_font_size_override("font_size", body_size)
	continue_label.add_theme_font_size_override("font_size", clampi(body_size - 10, 12, 16))
	skip_button.add_theme_font_size_override("font_size", clampi(body_size - 8, 13, 17))
	objective_label.add_theme_font_size_override("font_size", clampi(body_size - 3, 16, 23))

func _on_artwork_input(event: InputEvent) -> void:
	if not waiting_for_action and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		skip_requested.emit()
		get_viewport().set_input_as_handled()
	elif not waiting_for_action and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")):
		advance_requested.emit()
		get_viewport().set_input_as_handled()
