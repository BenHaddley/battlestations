extends Control
class_name PauseMenu
## In-game pause card. Runs while SceneTree.paused so its controls remain live.

signal resumed

const FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")

var volume_slider: HSlider
var volume_value: Label
var mute_check: CheckButton
var fullscreen_check: CheckButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500
	visible = false
	_build_interface()
	_load_settings()

func open() -> void:
	Engine.time_scale = 1.0
	visible = true
	get_tree().paused = true
	var resume_button := get_node_or_null("Shade/Card/Margin/Content/ResumeButton") as Button
	if resume_button:
		resume_button.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _build_interface() -> void:
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.035, 0.045, 0.04, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var card := PanelContainer.new()
	card.name = "Card"
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -260
	card.offset_top = -290
	card.offset_right = 260
	card.offset_bottom = 290
	card.add_theme_stylebox_override("panel", _paper_style(Color("e7c98e"), Color("29150e"), 9))
	shade.add_child(card)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 13)
	content.add_theme_font_override("font", FONT)
	margin.add_child(content)

	var title := Label.new()
	title.text = "GAME PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 45)
	title.add_theme_color_override("font_color", Color("5e1715"))
	content.add_child(title)

	var rule := HSeparator.new()
	rule.add_theme_constant_override("separation", 8)
	content.add_child(rule)

	_add_button(content, "ResumeButton", "RESUME GAME", close, Color("4f7b43"))

	var settings_title := Label.new()
	settings_title.text = "SETTINGS"
	settings_title.add_theme_font_override("font", FONT)
	settings_title.add_theme_font_size_override("font_size", 27)
	settings_title.add_theme_color_override("font_color", Color("2a1710"))
	content.add_child(settings_title)

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	content.add_child(volume_row)
	var volume_label := Label.new()
	volume_label.text = "VOLUME"
	volume_label.custom_minimum_size.x = 105
	volume_label.add_theme_font_override("font", FONT)
	volume_label.add_theme_font_size_override("font_size", 22)
	volume_row.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 1
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(volume_slider)
	volume_value = Label.new()
	volume_value.custom_minimum_size.x = 48
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_value.add_theme_font_override("font", FONT)
	volume_value.add_theme_font_size_override("font_size", 20)
	volume_row.add_child(volume_value)

	mute_check = CheckButton.new()
	mute_check.text = "MUTE ALL SOUND"
	mute_check.add_theme_font_override("font", FONT)
	mute_check.add_theme_font_size_override("font_size", 21)
	mute_check.toggled.connect(_on_mute_toggled)
	content.add_child(mute_check)

	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "FULLSCREEN"
	fullscreen_check.add_theme_font_override("font", FONT)
	fullscreen_check.add_theme_font_size_override("font_size", 21)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	content.add_child(fullscreen_check)

	_add_button(content, "RestartButton", "RESTART THIS JOB", _restart_current, Color("b46a28"))
	_add_button(content, "TitleButton", "RETURN TO TITLE", _return_to_title, Color("8b201b"))

	var hint := Label.new()
	hint.text = "ESC ALSO RESUMES"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("65483a"))
	content.add_child(hint)

func _add_button(parent: VBoxContainer, node_name: String, caption: String, callback: Callable, color: Color) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size.y = 52
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color("fff0c8"))
	button.add_theme_stylebox_override("normal", _paper_style(color, Color("21100b"), 5))
	button.add_theme_stylebox_override("hover", _paper_style(color.lightened(0.14), Color("f6d66f"), 6))
	button.add_theme_stylebox_override("focus", _paper_style(color.lightened(0.1), Color("f6d66f"), 6))
	button.pressed.connect(callback)
	parent.add_child(button)

func _paper_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style

func _on_volume_changed(value: float) -> void:
	var safe_value := clampf(value, 0.0, 100.0)
	AppSettings.music_percent = safe_value
	AppSettings.sfx_percent = safe_value
	AppSettings.apply()
	volume_value.text = "%d%%" % roundi(safe_value)
	_save_settings()

func _on_mute_toggled(enabled: bool) -> void:
	AudioServer.set_bus_mute(0, enabled)
	_save_settings()

func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func _restart_current() -> void:
	CampaignManager.reset_for_current_level()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_title() -> void:
	CampaignManager.clear_challenge()
	PhaseManager.reset()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _load_settings() -> void:
	var config := ConfigFile.new()
	var volume := 80.0
	var muted := false
	if config.load(ProfileManager.profile_path("settings.cfg")) == OK:
		volume = float(config.get_value("audio", "music_percent", AppSettings.music_percent))
		muted = bool(config.get_value("audio", "muted", false))
	volume_slider.set_value_no_signal(volume)
	mute_check.set_pressed_no_signal(muted)
	fullscreen_check.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_on_volume_changed(volume)
	AudioServer.set_bus_mute(0, muted)

func _save_settings() -> void:
	if volume_slider == null or mute_check == null:
		return
	var config := ConfigFile.new()
	config.set_value("audio", "music_percent", volume_slider.value)
	config.set_value("audio", "sfx_percent", volume_slider.value)
	config.set_value("game", "default_speed", AppSettings.default_game_speed)
	config.set_value("audio", "muted", mute_check.button_pressed)
	config.set_value("display", "fullscreen", fullscreen_check.button_pressed if fullscreen_check else false)
	config.save(ProfileManager.profile_path("settings.cfg"))
