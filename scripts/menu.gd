extends Control
class_name Menu
## Shop panel. Slides open/closed and shows a live currency readout.

@onready var currency_label: Label = $CurrencyLabel
@export var anim: AnimationPlayer

var is_menu_open: bool = true

func _process(_delta: float) -> void:
	currency_label.text = str(LevelManager.currency)

func toggle_menu() -> void:
	is_menu_open = not is_menu_open
	if anim:
		anim.play("menu_open" if is_menu_open else "menu_closed")
