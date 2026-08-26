extends Control
## Standalone board-registration sheet published at /test for environment art.
## All measurements mirror the live TrackRenderer, EnemySpawner and
## BattlefieldOverlay values so replacement artwork can be aligned exactly.

const BOARD_TEXTURE := preload("res://assets/sprites/board/THE_BOARD.png")
const FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")
const SOURCE_SIZE := Vector2(2100.0, 1920.0)
const TRACK_BOUNDS := Rect2(-330.0, -270.0, 660.0, 810.0)
const TRACK_STEP := 90.0
const LANE_X := [-350.0, -235.0, -118.0, 0.0, 118.0, 235.0, 350.0]
const LANE_TOP := -335.0
const LANE_BOTTOM := 665.0

var board_rect := Rect2()
var board_scale := 1.0

func _ready() -> void:
	set_process_input(true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101714"))
	var available := size - Vector2(28.0, 28.0)
	board_scale = minf(available.x / SOURCE_SIZE.x, available.y / SOURCE_SIZE.y)
	var drawn_size := SOURCE_SIZE * board_scale
	board_rect = Rect2((size - drawn_size) * 0.5, drawn_size)
	draw_texture_rect(BOARD_TEXTURE, board_rect, false)
	draw_rect(board_rect, Color("16100c"), false, 5.0)

	_draw_track_grid()
	_draw_spider_lanes()
	_draw_header()
	_draw_legend()

func _screen_from_world(world: Vector2) -> Vector2:
	return board_rect.position + (world + SOURCE_SIZE * 0.5) * board_scale

func _draw_track_grid() -> void:
	var bounds_top_left := _screen_from_world(TRACK_BOUNDS.position)
	var bounds_bottom_right := _screen_from_world(TRACK_BOUNDS.end)
	var live_bounds := Rect2(bounds_top_left, bounds_bottom_right - bounds_top_left)
	draw_rect(live_bounds, Color(0.0, 0.95, 1.0, 0.11), true)
	draw_rect(live_bounds, Color("00efff"), false, 5.0)

	var column := 0
	var x := TRACK_BOUNDS.position.x
	while x <= TRACK_BOUNDS.end.x + 0.1:
		var start := _screen_from_world(Vector2(x, TRACK_BOUNDS.position.y))
		var finish := _screen_from_world(Vector2(x, TRACK_BOUNDS.end.y))
		draw_line(start, finish, Color(0.05, 0.95, 1.0, 0.88), 2.0)
		_draw_tag("C%d" % column, start + Vector2(-13.0, -22.0), Color("00efff"))
		column += 1
		x += TRACK_STEP

	var row := 0
	var y := TRACK_BOUNDS.position.y
	while y <= TRACK_BOUNDS.end.y + 0.1:
		var start := _screen_from_world(Vector2(TRACK_BOUNDS.position.x, y))
		var finish := _screen_from_world(Vector2(TRACK_BOUNDS.end.x, y))
		draw_line(start, finish, Color(0.05, 0.95, 1.0, 0.88), 2.0)
		_draw_tag("R%d" % row, start + Vector2(-34.0, 7.0), Color("00efff"))
		row += 1
		y += TRACK_STEP

	# Every intersection is a legal rail centre, not a tile edge.
	for grid_x in range(column):
		for grid_y in range(row):
			var point := _screen_from_world(TRACK_BOUNDS.position + Vector2(grid_x, grid_y) * TRACK_STEP)
			draw_circle(point, 4.0, Color("fff19a"))
			draw_circle(point, 7.0, Color("17120c"), false, 2.0)

func _draw_spider_lanes() -> void:
	for index in range(LANE_X.size()):
		var lane_x: float = LANE_X[index]
		var start := _screen_from_world(Vector2(lane_x, LANE_TOP))
		var finish := _screen_from_world(Vector2(lane_x, LANE_BOTTOM))
		draw_dashed_line(start, finish, Color(1.0, 0.15, 0.55, 0.92), 3.0, 10.0)
		_draw_tag("LANE %d" % (index + 1), start + Vector2(-27.0, -17.0), Color("ff3f91"), 15)
	var danger_a := _screen_from_world(Vector2(-390.0, LANE_BOTTOM))
	var danger_b := _screen_from_world(Vector2(390.0, LANE_BOTTOM))
	draw_line(danger_a, danger_b, Color("ff5b25"), 5.0)
	_draw_tag("STATION LEAK LINE", danger_a + Vector2(6.0, -8.0), Color("ff7a3c"), 18)

func _draw_header() -> void:
	var panel := Rect2(18.0, 18.0, 395.0, 104.0)
	draw_rect(panel, Color(0.04, 0.055, 0.045, 0.93), true)
	draw_rect(panel, Color("f7da82"), false, 4.0)
	draw_string(FONT, panel.position + Vector2(18.0, 32.0), "ARTIST BOARD GRID", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("fff0b2"))
	draw_string(FONT, panel.position + Vector2(18.0, 60.0), "Source canvas. 2100 by 1920 pixels", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
	draw_string(FONT, panel.position + Vector2(18.0, 86.0), "Rail centres. 90 pixels apart", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("75f4ff"))

func _draw_legend() -> void:
	var panel := Rect2(size.x - 395.0, size.y - 118.0, 375.0, 98.0)
	draw_rect(panel, Color(0.04, 0.055, 0.045, 0.93), true)
	draw_rect(panel, Color("f7da82"), false, 4.0)
	draw_line(panel.position + Vector2(16.0, 25.0), panel.position + Vector2(54.0, 25.0), Color("00efff"), 4.0)
	draw_string(FONT, panel.position + Vector2(67.0, 32.0), "cyan. legal railway lattice", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_dashed_line(panel.position + Vector2(16.0, 52.0), panel.position + Vector2(54.0, 52.0), Color("ff3f91"), 4.0, 7.0)
	draw_string(FONT, panel.position + Vector2(67.0, 59.0), "pink. spider lane centres", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_line(panel.position + Vector2(16.0, 79.0), panel.position + Vector2(54.0, 79.0), Color("ff5b25"), 4.0)
	draw_string(FONT, panel.position + Vector2(67.0, 86.0), "orange. station leak line", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _draw_tag(text: String, at: Vector2, color: Color, font_size := 17) -> void:
	draw_string(FONT, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.9))
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
