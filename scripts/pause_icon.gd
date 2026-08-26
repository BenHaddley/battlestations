extends Control
## Hand-drawn double-bar "pause" icon with a gentle continuous breathing
## pulse — enough motion to read as animated/alive without implying the
## forward motion a static pause symbol shouldn't suggest.

@export var ink_color: Color = Color(0.32, 0.08, 0.06, 1)
@export var speed: float = 1.1

var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta * speed
	queue_redraw()

func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var random := RandomNumberGenerator.new()
	random.seed = hash(get_path())
	var w := size.x
	var h := size.y
	var pulse := 1.0 + 0.07 * sin(_time * TAU)
	var bar_w := w * 0.2 * pulse
	var bar_h := h * 0.58 * pulse
	var gap := w * 0.18
	var cy := h * 0.5
	for i in range(2):
		var cx := w * 0.5 + (float(i) - 0.5) * (bar_w + gap)
		var jx := random.randf_range(-1.2, 1.2)
		var jy := random.randf_range(-1.2, 1.2)
		var rect := Rect2(cx - bar_w * 0.5 + jx, cy - bar_h * 0.5 + jy, bar_w, bar_h)
		draw_rect(rect, ink_color, true)
		draw_rect(rect, Color(0.04, 0.03, 0.02, 1), false, 2.4)
