extends Node
## Autoload. Tracks whether the pointer is over a UI panel so board clicks
## don't fall through to a Plot underneath an open panel.

var is_hovering_ui: bool = false

func set_hovering_state(state: bool) -> void:
	is_hovering_ui = state

func is_hovering() -> bool:
	return is_hovering_ui
