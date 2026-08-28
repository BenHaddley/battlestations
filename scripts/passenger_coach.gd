extends Node2D
class_name PassengerCoach
## Non-combat car: generates passive income while coupled to the train.

@export var weight: float = 1.0
@export var income_amount: int = 32
@export var income_interval: float = 8.0

var _elapsed: float = 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= income_interval:
		_elapsed -= income_interval
		LevelManager.increase_currency(income_amount)
		_show_income_popup()

func set_convoy_transform(world_position: Vector2, direction: Vector2) -> void:
	global_position = world_position
	if not direction.is_zero_approx():
		rotation = direction.angle() - PI * 0.5

func _show_income_popup() -> void:
	var label := Label.new()
	label.text = "+Δ%d" % income_amount
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32, 1.0))
	label.add_theme_font_size_override("font_size", 20)
	label.global_position = global_position + Vector2(-24.0, -50.0)
	label.z_index = 61
	get_tree().current_scene.add_child(label)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 34.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
