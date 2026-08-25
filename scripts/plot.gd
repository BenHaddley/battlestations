extends Area2D
class_name Plot
## Clickable build tile. Hover tint, buys the shop's selected tower when
## empty, opens that turret's upgrade panel when occupied.

@export var hover_color: Color = Color(1, 1, 1, 0.6)

@onready var sprite: Sprite2D = $Sprite2D

var tower_node: Node2D = null
var turret: Turret = null
var start_color: Color

func _ready() -> void:
	start_color = sprite.modulate
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func _on_mouse_entered() -> void:
	sprite.modulate = hover_color

func _on_mouse_exited() -> void:
	sprite.modulate = start_color

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_build_or_upgrade()

func _try_build_or_upgrade() -> void:
	if UIManager.is_hovering():
		return

	if tower_node != null:
		turret.open_upgrade_ui()
		return

	var tower_to_build: TowerData = BuildManager.get_selected_tower()

	if tower_to_build.cost > LevelManager.currency:
		push_warning("You can't afford this tower")
		return

	LevelManager.spend_currency(tower_to_build.cost)

	tower_node = tower_to_build.scene.instantiate()
	get_tree().current_scene.add_child(tower_node)
	tower_node.global_position = global_position
	turret = tower_node as Turret
