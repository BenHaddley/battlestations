extends Control
class_name GameOverOverlay
## Failure overlay shared by campaign levels and Challenge Mode. Every visible
## element uses the supplied comic artwork; live Controls provide interaction.

const MISSION_BANNER := preload("res://assets/sprites/ui/game over ai placeholder/speed up.png")
const CHALLENGE_BANNER := preload("res://assets/sprites/ui/game over ai placeholder/9176d68e-4b09-4ea8-b1c1-5902f84c4681.png")
const PANEL_ART := preload("res://assets/sprites/ui/game over ai placeholder/e06694de-3d90-4f72-a5a1-0f2326091e65.png")
const CHARACTER_ART := preload("res://assets/sprites/ui/game over ai placeholder/b9cbf534-19c7-4ed2-8366-188e966b4589.png")
const RESTART_ART := preload("res://assets/sprites/ui/game over ai placeholder/996a85bf-261c-4019-8773-62684991ff4c.png")
const RETRY_ART := preload("res://assets/sprites/ui/game over ai placeholder/e56795ab-7528-4c5b-87e9-c8e9ef73d71c.png")
const MENU_ART := preload("res://assets/sprites/ui/game over ai placeholder/951252df-4834-42b9-b7cd-fc3ca3323257.png")
const FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")

var _dim: ColorRect
var _panel: TextureRect
var _banner: TextureRect
var _character: TextureRect
var _message: Label
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
	_banner.texture = CHALLENGE_BANNER if is_challenge else MISSION_BANNER
	_primary_button.texture_normal = RETRY_ART if is_challenge else RESTART_ART
	_primary_button.tooltip_text = "Retry Challenge" if is_challenge else "Restart Level"
	_primary_button.set_meta("failure_action", "retry_challenge" if is_challenge else "restart_level")
	_message.text = "That run got off the rails." if is_challenge else "The station has been overrun."
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

	_panel = _art_rect("IndustrialPanel", PANEL_ART, Vector2(410, 70), Vector2(460, 575))
	add_child(_panel)

	_banner = _art_rect("FailureBanner", MISSION_BANNER, Vector2(417, 55), Vector2(446, 149))
	add_child(_banner)

	_character = _art_rect("CharacterFailure", CHARACTER_ART, Vector2(542, 160), Vector2(196, 245))
	add_child(_character)

	_message = Label.new()
	_message.name = "FailureMessage"
	_message.position = Vector2(450, 414)
	_message.size = Vector2(380, 38)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_override("font", FONT)
	_message.add_theme_font_size_override("font_size", 20)
	_message.add_theme_color_override("font_color", Color("2c190f"))
	_message.add_theme_color_override("font_outline_color", Color("f5ddb0"))
	_message.add_theme_constant_override("outline_size", 2)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message)

	_primary_button = _art_button("PrimaryButton", RESTART_ART, Vector2(505, 456), Vector2(270, 90), _restart_run)
	add_child(_primary_button)
	_menu_button = _art_button("MainMenuButton", MENU_ART, Vector2(505, 548), Vector2(270, 90), _return_to_title)
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
	_panel.modulate.a = 0.0
	_banner.modulate.a = 0.0
	_character.modulate.a = 0.0
	_message.modulate.a = 0.0
	_primary_button.modulate.a = 0.0
	_menu_button.modulate.a = 0.0
	_primary_button.disabled = true
	_menu_button.disabled = true
	_panel.position.y = 42.0
	_banner.position.y = 37.0
	var tween := create_tween()
	tween.tween_property(_dim, "color:a", 0.8, 0.12)
	tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_panel, "position:y", 70.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_banner, "modulate:a", 1.0, 0.11)
	tween.parallel().tween_property(_banner, "position:y", 55.0, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_character, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(_message, "modulate:a", 1.0, 0.12)
	tween.tween_property(_primary_button, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(_menu_button, "modulate:a", 1.0, 0.1)
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
