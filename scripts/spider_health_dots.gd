extends Node2D
class_name SpiderHealthDots
## Procedural placeholder for the HP-stage dot markings until real per-stage
## spider art exists — draws directly over the sprite rather than swapping
## textures, so it's a drop-in removed the moment staged art is ready.
##
## Matches the intended design: lose a dot every 2 points of damage down to
## a single-dot stage at 5 HP, which then takes 5 more hits to kill.

## Kept near the abdomen's outer rim, deliberately away from the sprite's
## own baked-in eye markings (roughly (200,-360) and (-205,40) in this
## same native-pixel space) so the two don't visually merge.
const SLOT_OFFSETS: Array[Vector2] = [
	Vector2(-330, -280), Vector2(0, -430), Vector2(330, -280),
	Vector2(-380, 20), Vector2(380, 20), Vector2(0, 220),
]
const DOT_RADIUS: float = 34.0
const DOT_COLOR: Color = Color(0.82, 0.07, 0.05, 1.0)

var visible_dots: int = 6

signal stage_changed(previous_dots: int, current_dots: int)

func initialize_hit_points(current: int) -> void:
	# Spawn directly in the wave's intended form. This avoids playing a false
	# six-dot-to-one-dot damage transformation as a wave-one spider appears.
	visible_dots = _dots_for(current)
	queue_redraw()

func set_hit_points(current: int, _max_hit_points: int) -> void:
	var next_dots := _dots_for(current)
	if next_dots != visible_dots:
		var previous := visible_dots
		visible_dots = next_dots
		stage_changed.emit(previous, visible_dots)
	queue_redraw()

func _dots_for(hp: int) -> int:
	if hp <= 0:
		return 0
	if hp >= 14:
		return 6
	if hp >= 12:
		return 5
	if hp >= 10:
		return 4
	if hp >= 8:
		return 3
	if hp >= 6:
		return 2
	return 1

func _draw() -> void:
	for i in range(mini(visible_dots, SLOT_OFFSETS.size())):
		draw_circle(SLOT_OFFSETS[i], DOT_RADIUS, DOT_COLOR)
