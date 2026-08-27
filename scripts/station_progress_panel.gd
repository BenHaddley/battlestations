extends Control
class_name StationProgressPanel
## Reusable, fully live Station/Battle schedule card. Text nodes, route art,
## locomotive and button are separate elements rather than a stretched image.

signal skip_wait_pressed

@export var title_text := "BATTLE // STATIONS":
	set(value):
		title_text = value
		if title_label: title_label.text = value
@export var phase_text := "STATION"
@export var status_text := "DEPARTURE 00:19"
@export var subtitle_text := "PREPARE • BUY • COUPLE"
@export_range(2, 12, 1) var checkpoint_count := 7

const FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")
const TrackScript := preload("res://scripts/station_progress_track.gd")

var title_label: Label
var track: StationProgressTrack
var phase_label: Label
var status_label: Label
var subtitle_label: Label
var skip_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_elements()
	set_phase(phase_text, status_text, subtitle_text)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func configure(total_checkpoints: int) -> void:
	checkpoint_count = clampi(total_checkpoints, 2, 12)
	if track:
		track.checkpoint_count = checkpoint_count

func set_level_progress(current_checkpoint: int, total_checkpoints: int, animate := true) -> void:
	configure(total_checkpoints)
	var denominator := float(maxi(total_checkpoints - 1, 1))
	track.set_progress(clampf(float(current_checkpoint) / denominator, 0.0, 1.0), animate)

func set_progress_fraction(value: float, total_checkpoints: int, animate := true) -> void:
	configure(total_checkpoints)
	track.set_progress(value, animate)

func set_phase(new_phase: String, new_status: String, new_subtitle: String) -> void:
	phase_text = new_phase
	status_text = new_status
	subtitle_text = new_subtitle
	if phase_label: phase_label.text = phase_text
	if status_label: status_label.text = status_text
	if subtitle_label: subtitle_label.text = subtitle_text

func set_button_state(label_text: String, disabled: bool) -> void:
	if skip_button:
		skip_button.text = label_text
		skip_button.disabled = disabled

func _build_elements() -> void:
	if get_child_count() > 0:
		return
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 8.0
	stack.offset_top = 5.0
	stack.offset_right = -8.0
	stack.offset_bottom = -5.0
	stack.add_theme_constant_override("separation", 1)
	add_child(stack)

	title_label = _label(title_text, 14, Color("4e1716"))
	title_label.rotation = -0.012
	stack.add_child(title_label)

	track = TrackScript.new()
	track.checkpoint_count = checkpoint_count
	track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(track)

	phase_label = _label(phase_text, 23, Color("fff7dd"), 3)
	phase_label.rotation = 0.012
	stack.add_child(phase_label)
	status_label = _label(status_text, 14, Color("fff5dc"), 2)
	stack.add_child(status_label)
	subtitle_label = _label(subtitle_text, 9, Color("f7edd5"), 1)
	stack.add_child(subtitle_label)

	skip_button = Button.new()
	skip_button.custom_minimum_size = Vector2(0.0, 25.0)
	skip_button.text = "SKIP WAIT"
	skip_button.add_theme_font_override("font", FONT)
	skip_button.add_theme_font_size_override("font_size", 13)
	skip_button.add_theme_color_override("font_color", Color("fff2d2"))
	skip_button.add_theme_stylebox_override("normal", _button_style(Color("79201b")))
	skip_button.add_theme_stylebox_override("hover", _button_style(Color("a52d24")))
	skip_button.add_theme_stylebox_override("disabled", _button_style(Color("4a5155")))
	skip_button.pressed.connect(func() -> void: skip_wait_pressed.emit())
	stack.add_child(skip_button)

func _label(value: String, font_size: int, color: Color, outline := 0) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", Color("27120f"))
		label.add_theme_constant_override("outline_size", outline)
	return label

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("18100d")
	style.border_width_left = 4
	style.border_width_top = 3
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 2
	return style

func _draw() -> void:
	# Slightly mismatched nested rectangles create the physical inked-card look.
	var outer := Rect2(Vector2(1.0, 2.0), size - Vector2(3.0, 4.0))
	draw_rect(outer, Color("17100d"), true)
	var red_border := outer.grow(-4.0)
	draw_rect(red_border, Color("7f211d"), true)
	var paper := red_border.grow(-4.0)
	draw_rect(paper, Color("69a9d8"), true)
	draw_polyline(PackedVector2Array([
		paper.position + Vector2(2.0, 1.0),
		Vector2(paper.end.x - 2.0, paper.position.y + 3.0),
		paper.end - Vector2(1.0, 2.0),
		Vector2(paper.position.x + 3.0, paper.end.y - 1.0),
		paper.position + Vector2(2.0, 1.0),
	]), Color("21130f"), 2.5)
	# Uneven translucent paint strokes keep the blue from reading as flat web UI.
	draw_line(paper.position + Vector2(9.0, 35.0), Vector2(paper.end.x - 8.0, paper.position.y + 32.0), Color(0.75, 0.9, 0.95, 0.13), 9.0)
	draw_line(Vector2(paper.position.x + 12.0, paper.end.y - 43.0), paper.end - Vector2(11.0, 47.0), Color(0.1, 0.28, 0.42, 0.09), 8.0)
