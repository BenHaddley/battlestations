extends Control
class_name HpGauge
## Draws only the moving parts of the station health meter: the empty channel
## and the fill that rises inside it. The casing, "HP" heading and heart cap all
## belong to the UI artwork, so nothing here paints a second frame and nothing
## here is stretched when health changes -- the gauge is laid straight over the
## authored slot and only the fill's height moves.

## Sampled from the authored HP artwork so a live gauge and the drawn one that
## it replaces read as the same object.
const EMPTY_COLOR := Color(0.392, 0.373, 0.333)
const FILL_COLOR := Color(0.827, 0.0, 0.0)
const CREST_COLOR := Color(0.988, 0.706, 0.157)
## A hurt meter carries an amber crest at the head of its fill. The drawn full
## and nearly full meters have none, so the crest fades in as health falls
## between these two fractions rather than sitting on a healthy station.
const CREST_FADE_START := 0.85
const CREST_FADE_END := 0.6
## The crest holds at this share of the track once it is fully faded in, and is
## never more than half the fill, so a nearly empty meter is a short glow rather
## than a band taller than the health it reports.
const CREST_TRACK_RATIO := 0.22
const CREST_FILL_RATIO := 0.5
const DRAIN_SPEED := 0.85

var displayed_fraction: float = 1.0
var target_fraction: float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_fraction(value: float) -> void:
	target_fraction = clampf(value, 0.0, 1.0)
	set_process(true)

func _process(delta: float) -> void:
	displayed_fraction = move_toward(displayed_fraction, target_fraction, delta * DRAIN_SPEED)
	queue_redraw()
	if is_equal_approx(displayed_fraction, target_fraction):
		set_process(false)

func _draw() -> void:
	var track := Rect2(Vector2.ZERO, size)
	draw_rect(track, EMPTY_COLOR, true)
	var fill_height := track.size.y * displayed_fraction
	if fill_height < 1.0:
		return
	var fill_top := track.end.y - fill_height
	draw_rect(Rect2(track.position.x, fill_top, track.size.x, fill_height), FILL_COLOR, true)
	var crest_weight := clampf(inverse_lerp(CREST_FADE_START, CREST_FADE_END, displayed_fraction), 0.0, 1.0)
	var crest_height := minf(fill_height * CREST_FILL_RATIO, track.size.y * CREST_TRACK_RATIO * crest_weight)
	if crest_height >= 1.0:
		draw_rect(Rect2(track.position.x, fill_top, track.size.x, crest_height), CREST_COLOR, true)
