extends Control
class_name TrainControlPanel
## Tiny read-only selected-engine indicator. Driving is handled with Up/Down
## (or W/S), leaving the battlefield visible at the moment controls matter most.

signal control_changed(direction: int, throttle_notch: int)
signal deselect_requested

const THROTTLE_LABELS := ["BRAKE", "COAST", "PWR 1", "PWR 2", "PWR 3", "FULL"]
const REVERSER_LABELS := ["REV", "N", "FWD"]
const METAL := Color("282725")
const METAL_EDGE := Color("100d0b")
const CREAM := Color("ead49e")
const BURGUNDY := Color("7f241d")
const LAMP := Color("64e0a0")
const HAND_FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")

var _convoy: TrainConvoy
var _train_number := 0
var _requested_direction := 0
var _throttle_notch := 1
var _display_reverser := 1.0
var _display_throttle := 1.0
var _expansion := 0.0
var _dragging_throttle := false
var _animation: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(292, 38)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func show_for(convoy: TrainConvoy, train_number: int) -> void:
	_convoy = convoy
	_train_number = train_number
	_requested_direction = convoy.requested_direction
	_throttle_notch = convoy.throttle_notch
	_display_reverser = float(_requested_direction + 1)
	_display_throttle = float(_throttle_notch)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_animate_property("_expansion", 1.0, 0.16)

func clear() -> void:
	control_changed.emit(0, 1)
	_convoy = null
	_train_number = 0
	_requested_direction = 0
	_throttle_notch = 1
	_dragging_throttle = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animate_property("_expansion", 0.0, 0.14)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _expansion < 0.05 or not is_instance_valid(_convoy):
		return
	var housing := Rect2(0, 0, 292, 38)
	_draw_housing(housing)
	var direction := "→" if _convoy.current_speed >= 0.0 else "←"
	var ratio := absf(_convoy.current_speed) / maxf(_convoy.cruise_speed, 1.0)
	var pace := "SLOW" if ratio < 0.72 else ("FAST" if ratio > 1.28 else "NORMAL")
	_draw_centered_text("ENGINE %d   %s %s   ↑↓/WS DRIVE" % [_train_number, direction, pace], Vector2(146, 25), 15, CREAM)

func _draw_housing(rect: Rect2) -> void:
	draw_style_box(_housing_style(), rect)
	for scratch in [
		[Vector2(rect.position.x + 18, rect.position.y + 22), Vector2(rect.position.x + 74, rect.position.y + 19)],
		[Vector2(rect.end.x - 102, rect.position.y + 31), Vector2(rect.end.x - 34, rect.position.y + 35)],
		[Vector2(rect.position.x + 194, rect.end.y - 13), Vector2(rect.position.x + 253, rect.end.y - 15)],
	]:
		draw_line(scratch[0], scratch[1], Color(0.8, 0.72, 0.55, 0.12), 2.0)
	for bolt in [rect.position + Vector2(12, 11), Vector2(rect.end.x - 12, rect.position.y + 11), Vector2(rect.position.x + 12, rect.end.y - 10), rect.end - Vector2(12, 10)]:
		_draw_bolt(bolt)

func _draw_selected_plate() -> void:
	var plate := Rect2(157, 4, 190, 23)
	draw_rect(plate, Color("d5bc83"), true)
	draw_rect(plate, METAL_EDGE, false, 3.0)
	_draw_centered_text("LOCOMOTIVE %d" % _train_number, Vector2(247, 21), 15, Color("211812"))
	draw_circle(Vector2(327, 15), 6.5, Color("132119"))
	draw_circle(Vector2(327, 15), 3.8, LAMP)

func _draw_reverser() -> void:
	var box := Rect2(15, 30, 127, 62)
	draw_rect(box, Color("1b1a18"), true)
	draw_rect(box, Color("080706"), false, 3.0)
	_draw_centered_text("REVERSER", Vector2(78, 43), 12, CREAM)
	var xs := [31.0, 78.0, 125.0]
	for index in range(3):
		var active := index == _requested_direction + 1
		_draw_centered_text(REVERSER_LABELS[index], Vector2(xs[index], 85), 10, Color("ffe59c") if active else Color("a89a78"))
		draw_circle(Vector2(xs[index], 71), 4.5, BURGUNDY if active else Color("58534a"))
	draw_line(Vector2(30, 61), Vector2(126, 61), Color("090806"), 10.0)
	draw_line(Vector2(30, 60), Vector2(126, 60), Color("756d5c"), 2.0)
	var lever_x := lerpf(xs[0], xs[2], _display_reverser / 2.0)
	draw_line(Vector2(78, 76), Vector2(lever_x, 54), Color("b49b61"), 7.0, true)
	draw_circle(Vector2(lever_x, 52), 9.5, METAL_EDGE)
	draw_circle(Vector2(lever_x, 51), 6.5, Color("8f3127"))

func _draw_throttle() -> void:
	var box := Rect2(151, 30, 234, 62)
	draw_rect(box, Color("1a1917"), true)
	draw_rect(box, Color("080706"), false, 3.0)
	_draw_centered_text("THROTTLE", Vector2(268, 43), 12, CREAM)
	var left := 166.0
	var spacing := 40.5
	for index in range(6):
		var x := left + spacing * index
		var active := index == _throttle_notch
		draw_line(Vector2(x, 56), Vector2(x, 66), Color("e5c980") if active else Color("6d6556"), 3.0)
		_draw_centered_text(THROTTLE_LABELS[index], Vector2(x, 85), 9, Color("ffe59c") if active else Color("aaa07e"))
	draw_line(Vector2(left, 61), Vector2(left + spacing * 5, 61), Color("090806"), 12.0)
	draw_line(Vector2(left, 59), Vector2(left + spacing * 5, 59), Color("706858"), 2.0)
	var handle_x := left + spacing * _display_throttle
	var pivot := Vector2(268, 89)
	draw_line(pivot, Vector2(handle_x, 51), Color("c2a76b"), 9.0, true)
	draw_circle(pivot, 10.0, METAL_EDGE)
	draw_circle(pivot, 6.0, Color("7f6c49"))
	var grip := Rect2(handle_x - 15, 40, 30, 22)
	draw_style_box(_grip_style(), grip)
	draw_line(grip.position + Vector2(6, 6), grip.end - Vector2(6, 7), Color(1, 1, 1, 0.09), 2.0)

func _draw_speed_gauge() -> void:
	var box := Rect2(394, 30, 91, 62)
	draw_rect(box, Color("171817"), true)
	draw_rect(box, Color("080706"), false, 3.0)
	_draw_centered_text("SPEED", Vector2(439, 43), 12, CREAM)
	var speed_fraction := 0.0
	var movement := "STOPPED"
	if is_instance_valid(_convoy):
		speed_fraction = clampf(absf(_convoy.current_speed) / maxf(_convoy.max_speed, 1.0), 0.0, 1.0)
		if _convoy.current_speed > 1.0:
			movement = "MOVING  ▶"
		elif _convoy.current_speed < -1.0:
			movement = "◀  MOVING"
	for index in range(8):
		var lit := float(index + 1) / 8.0 <= speed_fraction
		var bar := Rect2(403 + index * 9.2, 51, 6.5, 19)
		draw_rect(bar, Color("e2b749") if lit else Color("47443d"), true)
		draw_rect(bar, Color("090806"), false, 1.0)
	_draw_centered_text(movement, Vector2(439, 85), 10, Color("9eeac1") if movement != "STOPPED" else Color("b5aa8a"))

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(_convoy) or _expansion < 0.9:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			deselect_requested.emit()
			accept_event()
			return


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_instance_valid(_convoy) or not event.pressed:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			deselect_requested.emit()

func _nearest_reverser(mouse_x: float) -> int:
	return clampi(roundi((mouse_x - 31.0) / 47.0) - 1, -1, 1)

func _nearest_throttle(mouse_x: float) -> int:
	return clampi(roundi((mouse_x - 166.0) / 40.5), 0, 5)

func _set_reverser(direction: int) -> void:
	_requested_direction = clampi(direction, -1, 1)
	_animate_property("_display_reverser", float(_requested_direction + 1), 0.1)
	control_changed.emit(_requested_direction, _throttle_notch)

func _set_throttle(notch: int) -> void:
	_throttle_notch = clampi(notch, 0, 5)
	_animate_property("_display_throttle", float(_throttle_notch), 0.09)
	control_changed.emit(_requested_direction, _throttle_notch)

func _animate_property(property: StringName, value: float, duration: float) -> void:
	if _animation and _animation.is_valid():
		_animation.kill()
	_animation = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation.tween_property(self, NodePath(property), value, duration)

func _draw_centered_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font: Font = HAND_FONT
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_bolt(center: Vector2) -> void:
	draw_circle(center, 6.0, Color("080706"))
	draw_circle(center, 3.7, Color("817762"))
	draw_line(center + Vector2(-2.5, 0), center + Vector2(2.5, 0), Color("26221c"), 1.5)

func _housing_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = METAL
	style.border_color = METAL_EDGE
	style.set_border_width_all(5)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 5
	return style

func _grip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("11100f")
	style.border_color = Color("050404")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 8
	return style
