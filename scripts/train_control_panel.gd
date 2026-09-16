extends Control
class_name TrainControlPanel
## Tiny read-only selected-engine indicator. Driving is handled with Up/Down
## (or W/S), leaving the battlefield visible at the moment controls matter most.

signal control_changed(direction: int, throttle_notch: int)
signal deselect_requested

const METAL := Color("282725")
const METAL_EDGE := Color("100d0b")
const CREAM := Color("ead49e")
const HAND_FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")

var _convoy: TrainConvoy
var _train_number := 0
var _expansion := 0.0
var _animation: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(400, 44)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

## Second line of the readout: live weight against capacity and engine
## health, refreshed every frame so coupling, selling, losing a Tender or
## taking bites all show immediately.
func status_line() -> String:
	if not is_instance_valid(_convoy):
		return ""
	var line := "WEIGHT %d / %d" % [roundi(_convoy.total_weight()), roundi(_convoy.effective_capacity())]
	if _convoy.unit_health:
		line += "   ENGINE HP %d / %d" % [ceili(_convoy.unit_health.hit_points), roundi(_convoy.unit_health.max_hit_points)]
	if _convoy.wrecked:
		line += "   WRECKED"
	return line

func show_for(convoy: TrainConvoy, train_number: int) -> void:
	_convoy = convoy
	_train_number = train_number
	mouse_filter = Control.MOUSE_FILTER_STOP
	_animate_property("_expansion", 1.0, 0.16)

func clear() -> void:
	control_changed.emit(0, 1)
	_convoy = null
	_train_number = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animate_property("_expansion", 0.0, 0.14)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _expansion < 0.05 or not is_instance_valid(_convoy):
		return
	var housing := Rect2(0, 0, 400, 44)
	_draw_housing(housing)
	var direction := "→" if _convoy.current_speed >= 0.0 else "←"
	var ratio := absf(_convoy.current_speed) / maxf(_convoy.cruise_speed, 1.0)
	var pace := "SLOW" if ratio < 0.72 else ("FAST" if ratio > 1.28 else "NORMAL")
	if _convoy.wrecked:
		pace = "WRECKED"
	_draw_centered_text("CONTROLLING ENGINE %d   %s %s   ↑↓/WS DRIVE" % [_train_number, direction, pace], Vector2(200, 19), 14, CREAM)
	_draw_centered_text(status_line(), Vector2(200, 37), 13, Color("ffd98a"))

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
