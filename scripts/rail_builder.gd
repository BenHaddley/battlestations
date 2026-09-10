extends Node2D
class_name RailBuilder
## STATIONS-only rail construction. Hover any rail tile to reveal plus signs
## on the empty tiles beside it; click a plus to lay connected rail for the
## provisional per-tile price. Right-click player-built rail to lift it again
## for a full refund. Nothing here runs during BATTLE.

signal rail_built(cell: Vector2i, rerouted_route: int)
signal rail_removed(cell: Vector2i)

const FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")
const READY_COLOR := Color(0.36, 0.95, 0.62, 0.95)
const POOR_COLOR := Color(1.0, 0.78, 0.32, 0.95)
const INVALID_COLOR := Color(0.95, 0.38, 0.32, 0.95)
const REMOVE_COLOR := Color(1.0, 0.52, 0.42, 0.95)

var main: Node
var track: TrackRenderer
var menu: Menu
var rail_cost: int = 50

var has_anchor := false
var anchor := Vector2i.ZERO
var candidates: Array[Vector2i] = []
## [end, target] pairs offered as join markers while the anchor is hovered.
var links: Array = []
var has_hovered_candidate := false
var hovered_candidate := Vector2i.ZERO
var hovered_link: Array = []
var has_hovered_removable := false
var hovered_removable := Vector2i.ZERO
var tiles_built := 0
var tiles_removed := 0
var links_made := 0

func _ready() -> void:
	z_index = 45
	var balance: GameBalance = load("res://resources/game_balance.tres")
	if balance:
		rail_cost = balance.rail_tile_cost

func configure(game: Node, track_renderer: TrackRenderer, hud: Menu) -> void:
	main = game
	track = track_renderer
	menu = hud

## Construction is a STATION activity, and only while the board itself is
## the active surface (no card open, no shop drag, no remove mode).
## Construction is a STATION activity the player arms with BUILD TRACK, and
## only while the board itself is the active surface (no card open, no shop
## drag, no remove mode). Arming it deliberately keeps the plus and remove
## markers off the board during ordinary play.
func active() -> bool:
	if track == null or main == null:
		return false
	if not PhaseManager.rail_building_enabled or not PhaseManager.is_station():
		return false
	if menu != null and not menu.building_track:
		return false
	return bool(main.board_interaction_enabled())

func _process(_delta: float) -> void:
	if menu != null and menu.building_track and not (PhaseManager.rail_building_enabled and PhaseManager.is_station()):
		# A wave started while building was armed; drop back to normal play.
		menu.set_build_track(false)
	if not active():
		_clear_hover()
		queue_redraw()
		return
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
	var cell := track.cell_of(world_position)
	var inside := track.in_bounds(cell) and track.world_of(cell).distance_to(world_position) <= track.path_step * 0.5
	has_hovered_candidate = false
	has_hovered_removable = false
	hovered_link = []
	# Join markers sit between two tiles, so test them before deciding which
	# tile the pointer is over.
	if has_anchor:
		for pair in links:
			if _link_marker_position(pair).distance_to(world_position) <= 15.0:
				hovered_link = pair
				break
	if not hovered_link.is_empty():
		pass
	elif inside and track.is_rail(cell):
		has_anchor = true
		anchor = cell
		candidates = track.expansion_candidates(cell)
		links = track.link_candidates(cell)
		if track.is_built(cell):
			has_hovered_removable = true
			hovered_removable = cell
	elif inside and has_anchor and cell in candidates:
		has_hovered_candidate = true
		hovered_candidate = cell
	else:
		has_anchor = false
		candidates = []
		links = []
	queue_redraw()

func _clear_hover() -> void:
	has_anchor = false
	candidates = []
	links = []
	hovered_link = []
	has_hovered_candidate = false
	has_hovered_removable = false

func _link_marker_position(pair: Array) -> Vector2:
	return (track.world_of(pair[0]) + track.world_of(pair[1])) * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if not active() or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not hovered_link.is_empty():
		attempt_link(hovered_link[0], hovered_link[1])
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT and has_hovered_candidate:
		attempt_build(anchor, hovered_candidate)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT and has_hovered_removable:
		attempt_remove(hovered_removable)
		get_viewport().set_input_as_handled()

## Joining a dead end to its circuit costs nothing; the tiles were paid for
## when they were laid. This is what closes a detour and hands it to the
## train.
func attempt_link(end_cell: Vector2i, target: Vector2i) -> bool:
	if not PhaseManager.rail_building_enabled or not PhaseManager.is_station():
		_feedback("Rails can only be joined during STATIONS.", false)
		return false
	var result: Dictionary = track.link_rail(end_cell, target)
	if not result.ok:
		_feedback(String(result.reason), false)
		return false
	AudioFX.play_cue(&"upgrade")
	links_made += 1
	var rerouted := int(result.get("rerouted", -1))
	if rerouted >= 0:
		_feedback("Rails joined. The circuit now takes the new detour.", true)
	else:
		_feedback("Rails joined.", true)
	has_anchor = true
	anchor = end_cell
	candidates = track.expansion_candidates(end_cell)
	links = track.link_candidates(end_cell)
	hovered_link = []
	rail_built.emit(end_cell, rerouted)
	queue_redraw()
	return true

## Charges only after the tile is actually laid, so a refused placement
## never touches the wallet or the railway.
func attempt_build(from_cell: Vector2i, cell: Vector2i) -> bool:
	if not PhaseManager.rail_building_enabled or not PhaseManager.is_station():
		_feedback("Rails can only be built during STATIONS.", false)
		return false
	var verdict: Dictionary = track.evaluate_placement(from_cell, cell)
	if not verdict.ok:
		_feedback(String(verdict.reason), false)
		return false
	if LevelManager.currency < rail_cost:
		_feedback("Not enough Delta. Each rail tile costs Δ%d." % rail_cost, false)
		return false
	var result: Dictionary = track.place_rail(from_cell, cell)
	if not result.ok:
		_feedback(String(result.reason), false)
		return false
	LevelManager.spend_currency(rail_cost, "rail")
	AudioFX.play_cue(&"purchase")
	tiles_built += 1
	var joinable: Array = track.link_candidates(cell)
	if joinable.is_empty():
		_feedback("Rail laid for Δ%d." % rail_cost, true)
	else:
		_feedback("Rail laid for Δ%d. Click the link ring to join it to the circuit." % rail_cost, true)
	# Keep the hover anchored on the fresh tile so a straight run can be laid
	# with repeated clicks rather than re-hovering after every piece.
	has_anchor = true
	anchor = cell
	candidates = track.expansion_candidates(cell)
	links = joinable
	has_hovered_candidate = false
	hovered_link = []
	rail_built.emit(cell, -1)
	queue_redraw()
	return true

func attempt_remove(cell: Vector2i) -> bool:
	if not PhaseManager.rail_building_enabled or not PhaseManager.is_station():
		_feedback("Rails can only be changed during STATIONS.", false)
		return false
	var occupied := bool(main.rail_cell_occupied(cell))
	var result: Dictionary = track.remove_rail(cell, occupied)
	if not result.ok:
		_feedback(String(result.reason), false)
		return false
	LevelManager.increase_currency(rail_cost, "rail_refund")
	AudioFX.play_cue(&"ui")
	tiles_removed += 1
	_feedback("Rail lifted. Δ%d refunded." % rail_cost, true)
	_clear_hover()
	rail_removed.emit(cell)
	queue_redraw()
	return true

func _feedback(message: String, success: bool) -> void:
	if menu:
		menu.show_placement_feedback(message, success)

func _draw() -> void:
	if not active():
		return
	var half := track.path_step * 0.5
	if not has_anchor:
		# Armed but not over a rail: outline the buildable network so the player
		# can see where construction is possible before committing to a tile.
		for cell in track.rail_cells():
			var outline_world: Vector2 = track.world_of(cell)
			draw_rect(Rect2(outline_world - Vector2(half, half), Vector2(track.path_step, track.path_step)), Color(0.42, 0.95, 0.72, 0.10), true)
		_draw_tag(Vector2(0.0, track.track_bounds.position.y - 18.0), "HOVER A RAIL TO EXTEND IT", READY_COLOR)
		return
	# The circuit the hovered rail belongs to reads as one connected object.
	for cell in track.network_of(anchor):
		var glow_world: Vector2 = track.world_of(cell)
		draw_rect(Rect2(glow_world - Vector2(half, half), Vector2(track.path_step, track.path_step)), Color(0.42, 0.95, 0.72, 0.13), true)
	var anchor_world := track.world_of(anchor)
	draw_rect(Rect2(anchor_world - Vector2(half, half), Vector2(track.path_step, track.path_step)), Color(1.0, 0.92, 0.55, 0.16), true)
	draw_rect(Rect2(anchor_world - Vector2(half - 2.0, half - 2.0), Vector2(track.path_step - 4.0, track.path_step - 4.0)), Color(1.0, 0.92, 0.55, 0.7), false, 2.5)
	var affordable := LevelManager.currency >= rail_cost
	for candidate in candidates:
		var verdict: Dictionary = track.evaluate_placement(anchor, candidate)
		var color := INVALID_COLOR
		if verdict.ok:
			color = READY_COLOR if affordable else POOR_COLOR
		var hovered := has_hovered_candidate and candidate == hovered_candidate
		if hovered and verdict.ok:
			_draw_preview_tile(track.world_of(candidate), candidate - anchor, color)
		_draw_plus(track.world_of(candidate), color, hovered)
		if hovered:
			var tag := "Δ%d" % rail_cost if verdict.ok else "BLOCKED"
			_draw_tag(track.world_of(candidate) + Vector2(0.0, half + 14.0), tag, color)
	for pair in links:
		var hovered_pair: bool = not hovered_link.is_empty() and hovered_link[0] == pair[0] and hovered_link[1] == pair[1]
		_draw_link(_link_marker_position(pair), hovered_pair)
		if hovered_pair:
			_draw_tag(_link_marker_position(pair) + Vector2(0.0, 26.0), "JOIN RAILS", Color(0.55, 0.85, 1.0, 0.95))
	if has_hovered_removable:
		var world := track.world_of(hovered_removable)
		draw_line(world + Vector2(-11, -11), world + Vector2(11, 11), Color(0.1, 0.04, 0.03, 0.9), 7.0, true)
		draw_line(world + Vector2(-11, 11), world + Vector2(11, -11), Color(0.1, 0.04, 0.03, 0.9), 7.0, true)
		draw_line(world + Vector2(-11, -11), world + Vector2(11, 11), REMOVE_COLOR, 3.5, true)
		draw_line(world + Vector2(-11, 11), world + Vector2(11, -11), REMOVE_COLOR, 3.5, true)
		_draw_tag(world + Vector2(0.0, -half - 6.0), "RIGHT-CLICK  +Δ%d" % rail_cost, REMOVE_COLOR)

func _draw_plus(center: Vector2, color: Color, hovered: bool) -> void:
	var radius := 17.0 if hovered else 14.0
	draw_circle(center, radius + 3.0, Color(0.08, 0.05, 0.03, 0.85))
	draw_circle(center, radius, Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 0.9))
	var arm := radius * 0.62
	draw_line(center + Vector2(-arm, 0), center + Vector2(arm, 0), color, 4.5 if hovered else 3.5, true)
	draw_line(center + Vector2(0, -arm), center + Vector2(0, arm), color, 4.5 if hovered else 3.5, true)
	draw_arc(center, radius, 0.0, TAU, 28, color, 2.0, true)

## Translucent picture of the tile that would be laid, oriented like the rail
## it extends, so the player sees the result before paying for it.
func _draw_preview_tile(center: Vector2, direction: Vector2i, color: Color) -> void:
	var texture: Texture2D = track.rail_texture
	if texture == null:
		return
	var size := texture.get_size() * track.tile_scale
	var rotation := PI * 0.5 if direction.x != 0 else 0.0
	draw_set_transform(center, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, Color(1.0, 1.0, 1.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var half := track.path_step * 0.5
	draw_rect(Rect2(center - Vector2(half, half), Vector2(track.path_step, track.path_step)), Color(color.r, color.g, color.b, 0.5), false, 2.0)

## Two interlocked rings between the dead end and the rail it can join.
func _draw_link(center: Vector2, hovered: bool) -> void:
	var color := Color(0.55, 0.85, 1.0, 1.0) if hovered else Color(0.45, 0.72, 0.95, 0.9)
	var radius := 9.0 if hovered else 7.5
	draw_circle(center, radius + 7.0, Color(0.06, 0.05, 0.08, 0.85))
	draw_arc(center + Vector2(-4.0, 0.0), radius, 0.0, TAU, 20, color, 3.0, true)
	draw_arc(center + Vector2(4.0, 0.0), radius, 0.0, TAU, 20, color, 3.0, true)

func _draw_tag(center: Vector2, text: String, color: Color) -> void:
	var font: Font = FONT
	var font_size := 15
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var box := Rect2(center - Vector2(width * 0.5 + 8.0, 12.0), Vector2(width + 16.0, 24.0))
	draw_rect(box, Color(0.08, 0.05, 0.03, 0.88), true)
	draw_rect(box, color, false, 2.0)
	draw_string(font, box.position + Vector2(8.0, 17.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.96, 0.85, 1.0))
