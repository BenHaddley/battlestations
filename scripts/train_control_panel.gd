extends PanelContainer
class_name TrainControlPanel
## Compact hold-to-drive control for one selected convoy. The convoy still
## cruises automatically when neither direction button is held.

signal command_changed(command: int)
signal deselect_requested

var title_label: Label
var status_label: Label
var reverse_button: Button
var forward_button: Button
var _convoy: TrainConvoy

func _ready() -> void:
	custom_minimum_size = Vector2(350, 54)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	reverse_button = _make_button("◀  REVERSE")
	row.add_child(reverse_button)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	title_label = Label.new()
	title_label.text = "TRAIN SELECTED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	labels.add_child(title_label)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	labels.add_child(status_label)
	forward_button = _make_button("FORWARD  ▶")
	row.add_child(forward_button)
	reverse_button.button_down.connect(command_changed.emit.bind(-1))
	reverse_button.button_up.connect(command_changed.emit.bind(0))
	forward_button.button_down.connect(command_changed.emit.bind(1))
	forward_button.button_up.connect(command_changed.emit.bind(0))
	gui_input.connect(_on_gui_input)
	visible = false

func show_for(convoy: TrainConvoy, train_number: int) -> void:
	_convoy = convoy
	title_label.text = "TRAIN %d SELECTED" % train_number
	visible = true

func clear() -> void:
	command_changed.emit(0)
	_convoy = null
	visible = false

func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(_convoy):
		return
	var direction := "FORWARD" if _convoy.cruise_direction > 0 else "REVERSE"
	status_label.text = "%s  %d" % [direction, roundi(absf(_convoy.current_speed))]

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		deselect_requested.emit()

func _make_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(102, 42)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _button_style(Color("8a291f")))
	button.add_theme_stylebox_override("hover", _button_style(Color("b33a28")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("552018")))
	return button

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("efd49a")
	style.border_color = Color("21150e")
	style.set_border_width_all(4)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("1d120c")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 2
	return style
