extends Control
class_name GameOverOverlay
## Failure overlay shared by campaign levels and Challenge Mode. Gameplay remains
## visible beneath a light dimmer while the supplied GAME OVER artwork fades in.

const GAME_OVER_ART := preload("res://assets/sprites/ui/GAME_OVER_TEXT.webp")
const RESTART_ART := preload("res://assets/sprites/ui/game over ai placeholder/996a85bf-261c-4019-8773-62684991ff4c.png")
const RETRY_ART := preload("res://assets/sprites/ui/game over ai placeholder/e56795ab-7528-4c5b-87e9-c8e9ef73d71c.png")
const MENU_ART := preload("res://assets/sprites/ui/game over ai placeholder/951252df-4834-42b9-b7cd-fc3ca3323257.png")

var _dim: ColorRect
var _title_art: TextureRect
var _primary_button: TextureButton
var _menu_button: TextureButton
var _showing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 900
	visible = false
	_build_ui()

func show_failure(is_challenge: bool) -> void:
	if _showing:
		return
	_showing = true
	_primary_button.texture_normal = RETRY_ART if is_challenge else RESTART_ART
	_primary_button.tooltip_text = "Retry Challenge" if is_challenge else "Restart Level"
	_primary_button.set_meta("failure_action", "retry_challenge" if is_challenge else "restart_level")
	visible = true
	get_tree().paused = true
	_play_intro()

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dimmer"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.055, 0.06, 0.055, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_title_art = _art_rect("GameOverText", GAME_OVER_ART, Vector2(180, 78), Vector2(920, 460))
	add_child(_title_art)

	_primary_button = _art_button("PrimaryButton", RESTART_ART, Vector2(355, 570), Vector2(270, 90), _restart_run)
	add_child(_primary_button)
	_menu_button = _art_button("MainMenuButton", MENU_ART, Vector2(655, 570), Vector2(270, 90), _return_to_title)
	_menu_button.tooltip_text = "Main Menu"
	add_child(_menu_button)

func _art_rect(node_name: String, texture: Texture2D, location: Vector2, dimensions: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.position = location
	rect.size = dimensions
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _art_button(node_name: String, texture: Texture2D, location: Vector2, dimensions: Vector2, callback: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.name = node_name
	button.position = location
	button.size = dimensions
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	button.mouse_entered.connect(func() -> void: button.modulate = Color(1.08, 1.08, 0.9, 1.0))
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	return button

func _play_intro() -> void:
	_dim.color.a = 0.0
	_title_art.modulate.a = 0.0
	_primary_button.modulate.a = 0.0
	_menu_button.modulate.a = 0.0
	_primary_button.disabled = true
	_menu_button.disabled = true
	_title_art.scale = Vector2(0.96, 0.96)
	_title_art.pivot_offset = _title_art.size * 0.5
	var tween := create_tween()
	tween.tween_property(_dim, "color:a", 0.5, 0.35)
	tween.parallel().tween_property(_title_art, "modulate:a", 1.0, 0.55)
	tween.parallel().tween_property(_title_art, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_primary_button, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_menu_button, "modulate:a", 1.0, 0.18)
	tween.tween_callback(_enable_actions)

func _enable_actions() -> void:
	_primary_button.disabled = false
	_menu_button.disabled = false
	_primary_button.grab_focus()

func _restart_run() -> void:
	CampaignManager.reset_for_current_level()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_title() -> void:
	CampaignManager.clear_challenge()
	PhaseManager.reset()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
