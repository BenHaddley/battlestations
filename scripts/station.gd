extends Node2D
class_name Station
## The thing being defended. Spiders that reach it remain on the board and
## attack periodically until killed; the run ends once HP reaches zero.

signal health_changed(current: int, max_health: int)
signal defeated

@export var max_health: int = 60

var current_health: int
var resting_position: Vector2

const SIGN_FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")
## The nameplate used to sit on the rails, competing with sleepers and route
## arrows. It now stands on posts in the clear band between the bottom of the
## railway and the station body — below it would fall off the viewport.
const SIGN_CENTER := Vector2(0.0, -42.0)

func _ready() -> void:
	current_health = max_health
	resting_position = position
	GameEvents.station_attacked.connect(take_damage)
	health_changed.emit(current_health, max_health)
	var plate := get_node_or_null("NameLabel") as Label
	if plate:
		plate.visible = false
	queue_redraw()

func _draw() -> void:
	var font: Font = SIGN_FONT
	var font_size := 17
	var text := "STATION"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var board := Rect2(SIGN_CENTER - Vector2(text_size.x * 0.5 + 13.0, 15.0), Vector2(text_size.x + 26.0, 30.0))
	# Two short posts down to the station body, then the enamel sign itself.
	for post_x in [board.position.x + 12.0, board.end.x - 12.0]:
		draw_line(Vector2(post_x, board.end.y), Vector2(post_x, board.end.y + 18.0), Color(0.16, 0.12, 0.08, 0.9), 4.0)
	draw_rect(board.grow(2.0), Color(0.08, 0.06, 0.04, 0.55), true)
	draw_rect(board, Color("2f4f7a"), true)
	draw_rect(board, Color("f2e3bb"), false, 2.5)
	draw_string(font, Vector2(SIGN_CENTER.x - text_size.x * 0.5, SIGN_CENTER.y + 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fdf3d6"))

func take_damage(amount: int = 1) -> void:
	if current_health <= 0:
		return
	AudioFX.play_cue(&"station_hit")
	current_health = max(0, current_health - maxi(amount, 0))
	var tween := create_tween()
	for offset in [Vector2(10, 0), Vector2(-9, 0), Vector2(6, 0), Vector2.ZERO]:
		tween.tween_property(self, "position", resting_position + offset, 0.045)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		defeated.emit()
