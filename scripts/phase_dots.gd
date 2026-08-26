extends Control
## Rolling row of phase-progress dots strung along a connecting line: filled
## = completed, hollow = upcoming, a larger ringed dot = current — colored
## red during BATTLE, blue during STATION, matching the schedule panel's
## own phase color language.

const DOT_COUNT := 7

var _current_index: int = 1
var _is_battle: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## current_index is the wave number this dot row treats as "now" — the wave
## in progress during BATTLE, or the upcoming wave being counted down to
## during STATION.
func refresh(current_index: int, is_battle: bool) -> void:
	_current_index = current_index
	_is_battle = is_battle
	queue_redraw()

func _draw() -> void:
	var start_index: int = maxi(1, _current_index - 2)
	var spacing: float = size.x / float(DOT_COUNT)
	var radius: float = minf(spacing, size.y) * 0.36
	var y: float = size.y * 0.5
	var current_color: Color = Color(0.86, 0.16, 0.1, 1) if _is_battle else Color(0.12, 0.42, 0.86, 1)
	var line_color := Color(0.1, 0.08, 0.06, 0.55)

	draw_line(Vector2(spacing * 0.5, y), Vector2(spacing * (DOT_COUNT - 0.5), y), line_color, 3.5, true)

	for i in range(DOT_COUNT):
		var wave_number: int = start_index + i
		var x: float = spacing * (i + 0.5)
		if wave_number < _current_index:
			draw_circle(Vector2(x, y), radius, Color(0.08, 0.06, 0.04, 1))
		elif wave_number == _current_index:
			draw_circle(Vector2(x, y), radius * 1.55, current_color)
			draw_arc(Vector2(x, y), radius * 1.55, 0.0, TAU, 22, Color(0.04, 0.03, 0.02, 1), 3.0, true)
		else:
			draw_circle(Vector2(x, y), radius * 0.82, Color(0.94, 0.9, 0.8, 1))
			draw_arc(Vector2(x, y), radius * 0.82, 0.0, TAU, 16, Color(0.08, 0.06, 0.04, 1), 2.2, true)
