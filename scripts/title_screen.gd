extends Control
## Authored A/B menu plates over silent archival railway footage.

const StartGameDialogueScript := preload("res://scripts/start_game_dialogue.gd")
const AlmanacPanelScript := preload("res://scripts/almanac_panel.gd")
const TUTORIAL_SAVE_FILE := "tutorial.cfg"
const TITLE_MUSIC_TRACKS: Array[AudioStreamOggVorbis] = [
	preload("res://assets/audio/title_menu/track_1.ogg"),
	preload("res://assets/audio/title_menu/track_2.ogg"),
	preload("res://assets/audio/title_menu/track_3.ogg"),
	preload("res://assets/audio/title_menu/track_4.ogg"),
]

## Pick once per app launch, including when gameplay later returns to this scene.
static var _title_track_index := -1

@onready var start_button: Button = $MenuCanvas/StartButton
@onready var almanac_button: Button = $MenuCanvas/AlmanacButton
@onready var achievements_button: Button = $MenuCanvas/AchievementsButton
@onready var options_button: Button = $MenuCanvas/OptionsButton
@onready var profile_button: Button = $MenuCanvas/ProfileButton
@onready var modal: PanelContainer = $Modal
@onready var modal_title: Label = $Modal/Margin/VBox/Title
@onready var modal_copy: Label = $Modal/Margin/VBox/Copy
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var vinyl_player: AudioStreamPlayer = $VinylPlayer

@onready var start_choice_modal: PanelContainer = $StartChoiceModal
@onready var continue_button: Button = $StartChoiceModal/Margin/VBox/ContinueButton
@onready var new_game_button: Button = $StartChoiceModal/Margin/VBox/NewGameButton

var starting := false
var start_dialogue: Control
var almanac: AlmanacPanel

func _ready() -> void:
	if _is_artist_grid_build():
		get_tree().change_scene_to_file("res://scenes/ArtistGridView.tscn")
		return
	Engine.time_scale = 1.0
	AppSettings.load_settings()
	music_player.bus = &"Music"
	vinyl_player.bus = &"Music"
	get_tree().paused = false
	_play_music_looped()
	resized.connect(_layout_menu)
	_layout_menu()
	$MenuCanvas/Footage.finished.connect($MenuCanvas/Footage.play)
	start_button.pressed.connect(_on_start_pressed)
	$MenuCanvas/ShopButton.pressed.connect(_show_shop)
	$MenuCanvas/GamesButton.pressed.connect(_show_games)
	$MenuCanvas/SurvivalButton.pressed.connect(_launch_challenge.bind("survival"))
	$MenuCanvas/SandboxButton.pressed.connect(_launch_challenge.bind("sandbox"))
	almanac_button.pressed.connect(_show_almanac)
	achievements_button.pressed.connect(_show_achievements)
	options_button.pressed.connect(_show_options)
	profile_button.pressed.connect(_show_profiles)
	$Modal/Margin/VBox/BackButton.pressed.connect(func() -> void: modal.hide())
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	start_dialogue = StartGameDialogueScript.new()
	add_child(start_dialogue)
	start_dialogue.continue_selected.connect(_on_continue_pressed)
	start_dialogue.restart_selected.connect(_on_new_game_pressed)
	start_dialogue.closed.connect(start_button.grab_focus)
	almanac = AlmanacPanelScript.new()
	add_child(almanac)
	almanac.closed.connect(almanac_button.grab_focus)
	for overlay in [modal, start_choice_modal, start_dialogue, almanac]:
		overlay.visibility_changed.connect(_sync_menu_input)
	if _autostart_requested():
		call_deferred("_on_new_game_pressed")

func _layout_menu() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	$MenuCanvas.scale = Vector2.ONE * factor
	$MenuCanvas.position = (size - Vector2(1280, 720) * factor) * 0.5

func _sync_menu_input() -> void:
	var blocked := modal.visible or start_choice_modal.visible or start_dialogue.visible or almanac.visible
	$ModalBlocker.visible = blocked
	for child in $MenuCanvas.get_children():
		if child is Button:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP
			child.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	if modal.visible:
		_back_button().grab_focus()

func _show_shop() -> void:
	_prepare_interactive_modal("SHOP", "Coming soon.")
	_expand_modal(280.0, 150.0)
	modal.show()

func _show_games() -> void:
	_prepare_interactive_modal("GAMES & MORE", "Choose your next railway job.")
	for entry in [["CHALLENGES", _show_challenges], ["LEVEL SELECT", _show_level_select]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(400, 54)
		button.pressed.connect(entry[1])
		_add_dynamic_before_back(button)
	_expand_modal(280.0, 200.0)
	modal.show()

## `?autostart` on the Web URL (or `--autostart` natively) begins a new
## campaign without a click, so an exported build can be smoke-tested in a
## headless browser — see tests/web_smoke.sh.
func _autostart_requested() -> bool:
	if OS.has_feature("web"):
		var location = JavaScriptBridge.eval("window.location.search")
		return String(location).contains("autostart")
	return "--autostart" in OS.get_cmdline_user_args()

## Pages publishes the same tested game pack beneath /test. Detecting the URL
## here keeps the production title screen untouched while giving artists a
## stable, shareable registration sheet built from the live grid constants.
func _is_artist_grid_build() -> bool:
	if not OS.has_feature("web"):
		return "--artist-grid" in OS.get_cmdline_user_args()
	var location = JavaScriptBridge.eval("window.location.pathname + window.location.search")
	return String(location).contains("/test") or String(location).contains("artist-grid")

func _unhandled_input(event: InputEvent) -> void:
	if almanac != null and almanac.visible:
		if event.is_action_pressed("ui_cancel"):
			if almanac.detail.visible:
				almanac._close_detail()
			else:
				almanac.close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") and not modal.visible and not start_choice_modal.visible and not start_dialogue.visible:
		_on_start_pressed()
	elif event.is_action_pressed("ui_cancel"):
		if modal.visible:
			modal.hide()
		elif start_dialogue.visible:
			start_dialogue.close()
		elif start_choice_modal.visible:
			start_choice_modal.hide()
		else:
			_quit_game()

func _play_music_looped() -> void:
	if _title_track_index < 0:
		_title_track_index = randi_range(0, TITLE_MUSIC_TRACKS.size() - 1)
	var track := TITLE_MUSIC_TRACKS[_title_track_index]
	track.loop = true
	music_player.stream = track
	(vinyl_player.stream as AudioStreamOggVorbis).loop = true
	music_player.play()
	vinyl_player.play()

func _stop_menu_music() -> void:
	music_player.stop()
	vinyl_player.stop()

## Start resumes the active profile's campaign immediately. Challenges never
## participate in this path; a profile with no campaign save gets the new-game
## choice and its character-led introduction instead.
func _on_start_pressed() -> void:
	if starting:
		return
	start_choice_modal.hide()
	if CampaignManager.has_campaign_save():
		CampaignManager.continue_saved_game()
		_launch_game()
	else:
		start_dialogue.open(false)

func _on_continue_pressed() -> void:
	start_choice_modal.hide()
	CampaignManager.continue_saved_game()
	_launch_game()

func _on_new_game_pressed() -> void:
	start_choice_modal.hide()
	_reset_tutorial_progress()
	CampaignManager.restart_campaign()
	_launch_game()

## A new campaign should replay its first-time teaching sequence. Tutorial
## completion intentionally lives outside the campaign save so Continue can
## suppress repeated lessons, therefore Restart must clear this exact flag.
func _reset_tutorial_progress() -> void:
	var tutorial_path := ProfileManager.profile_path(TUTORIAL_SAVE_FILE)
	if FileAccess.file_exists(tutorial_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tutorial_path))

func _launch_game() -> void:
	if starting:
		return
	starting = true
	start_button.disabled = true
	_stop_menu_music()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _show_level_select() -> void:
	_prepare_interactive_modal("LEVEL SELECT", "Choose an unlocked mission to replay.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_mark_dynamic(grid)
	_modal_content().add_child(grid)
	_modal_content().move_child(grid, _back_button().get_index())
	for index in range(CampaignManager.levels.size()):
		var level: LevelData = CampaignManager.levels[index]
		var unlocked := CampaignManager.campaign_complete or index <= CampaignManager.current_level_index
		var card := Button.new()
		card.custom_minimum_size = Vector2(280, 74)
		card.text = "%s\n%d WAVES" % [level.level_name, level.wave_count] if unlocked else "???\nLOCKED — REACH MISSION %d" % (index + 1)
		card.disabled = not unlocked
		card.modulate = Color.WHITE if unlocked else Color(0.48, 0.48, 0.48, 0.72)
		if unlocked:
			card.pressed.connect(_launch_level.bind(index))
		grid.add_child(card)
	_expand_modal(330.0, 330.0)
	modal.show()

func _launch_level(index: int) -> void:
	CampaignManager.clear_challenge()
	CampaignManager.current_level_index = clampi(index, 0, CampaignManager.levels.size() - 1)
	CampaignManager.tutorial_requested = false
	CampaignManager.reset_for_current_level()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _show_almanac() -> void:
	modal.hide()
	start_choice_modal.hide()
	almanac.open()

func _show_achievements() -> void:
	_prepare_interactive_modal("ACHIEVEMENTS", "Complete tasks to unlock medals for this profile.")
	for definition in AchievementTracker.DEFINITIONS:
		var unlocked := String(definition.id) in AchievementTracker.unlocked_ids
		var card := Button.new()
		card.disabled = true
		card.custom_minimum_size = Vector2(590, 70)
		card.text = "%s  %s\n%s" % ["●" if unlocked else "○", definition.title if unlocked else "LOCKED MEDAL", definition.description]
		card.modulate = Color("f1ce72") if unlocked else Color(0.48, 0.48, 0.48, 0.75)
		_add_dynamic_before_back(card)
	_expand_modal(340.0, 300.0)
	modal.show()

func _show_profiles() -> void:
	_prepare_interactive_modal("PROFILES", "Choose one of three independent railway careers.")
	for slot in range(1, ProfileManager.SLOT_COUNT + 1):
		var row := HBoxContainer.new()
		var choose := Button.new()
		choose.custom_minimum_size = Vector2(250, 62)
		choose.text = "%s%s\n%s" % ["★ " if slot == ProfileManager.active_profile else "", ProfileManager.profile_name(slot), ProfileManager.progress_summary(slot)]
		choose.pressed.connect(_select_profile.bind(slot))
		row.add_child(choose)
		var rename := LineEdit.new()
		rename.placeholder_text = "Rename profile"
		rename.custom_minimum_size.x = 170
		rename.text_submitted.connect(func(new_name: String) -> void:
			ProfileManager.rename_profile(slot, new_name)
			_show_profiles()
		)
		row.add_child(rename)
		var erase := Button.new()
		erase.text = "DELETE"
		erase.pressed.connect(func() -> void:
			ProfileManager.delete_profile(slot)
			if slot == ProfileManager.active_profile:
				CampaignManager.current_level_index = 0
				CampaignManager.campaign_complete = false
			_show_profiles()
		)
		row.add_child(erase)
		_add_dynamic_before_back(row)
	_expand_modal(370.0, 285.0)
	modal.show()

func _select_profile(slot: int) -> void:
	ProfileManager.select_profile(slot)
	AppSettings.load_settings()
	DiscoveryTracker.load_discoveries()
	AchievementTracker.load_progress()
	CampaignManager.continue_saved_game()
	_show_profiles()

func _clear_challenge_buttons() -> void:
	for old_button in $Modal/Margin/VBox.get_children():
		if old_button is Button and old_button.name.begins_with("Challenge"):
			old_button.queue_free()

func _show_challenges() -> void:
	_prepare_interactive_modal("CHALLENGE JOB CARDS", "Pick one strange railway job. Challenge runs do not overwrite campaign progress.")
	var back_button: Button = $Modal/Margin/VBox/BackButton
	for challenge in CampaignManager.CHALLENGES:
		var button := Button.new()
		button.name = "Challenge%s" % String(challenge.id).to_pascal_case()
		button.custom_minimum_size = Vector2(0, 42)
		button.text = "%s. %s" % [String(challenge.name), String(challenge.tagline)]
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color("2b160d"))
		button.pressed.connect(_launch_challenge.bind(String(challenge.id)))
		$Modal/Margin/VBox.add_child(button)
		$Modal/Margin/VBox.move_child(button, back_button.get_index())
	modal.offset_left = -330.0
	modal.offset_right = 330.0
	# Height follows the job-card count so adding a challenge can't push the
	# Back button off the bottom of a 720-tall viewport.
	var half_height := minf(215.0 + CampaignManager.CHALLENGES.size() * 40.0, size.y * 0.5 - 8.0)
	modal.offset_top = -half_height
	modal.offset_bottom = half_height
	modal.show()
	var first_button := $Modal/Margin/VBox.get_node_or_null("ChallengeLastTrain") as Button
	if first_button:
		first_button.grab_focus()

func _launch_challenge(challenge_id: String) -> void:
	if CampaignManager.start_challenge(challenge_id):
		modal.hide()
		_launch_game()

func _show_options() -> void:
	_prepare_interactive_modal("SETTINGS", "Changes save automatically for the active profile.")
	_add_setting_slider("MUSIC VOLUME", AppSettings.music_percent, func(value: float) -> void:
		AppSettings.music_percent = value
		AppSettings.save_settings()
	)
	_add_setting_slider("SFX VOLUME", AppSettings.sfx_percent, func(value: float) -> void:
		AppSettings.sfx_percent = value
		AppSettings.save_settings()
	)
	var speed_toggle := CheckButton.new()
	speed_toggle.text = "START BATTLES AT 2× SPEED"
	speed_toggle.button_pressed = AppSettings.default_game_speed > 1.5
	speed_toggle.toggled.connect(func(enabled: bool) -> void:
		AppSettings.default_game_speed = 2.0 if enabled else 1.0
		AppSettings.save_settings()
	)
	_add_dynamic_before_back(speed_toggle)
	var quit := Button.new()
	quit.text = "QUIT GAME"
	quit.custom_minimum_size.y = 42
	quit.pressed.connect(_quit_game)
	_add_dynamic_before_back(quit)
	_expand_modal(300.0, 230.0)
	modal.show()

func _prepare_interactive_modal(title: String, copy: String) -> void:
	_clear_dynamic_modal_content()
	_clear_challenge_buttons()
	modal_title.text = title
	modal_copy.text = copy
	modal_copy.visible = true

func _add_setting_slider(caption: String, value: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	_add_dynamic_before_back(row)

func _modal_content() -> VBoxContainer:
	return $Modal/Margin/VBox

func _back_button() -> Button:
	return $Modal/Margin/VBox/BackButton

func _mark_dynamic(control: Control) -> void:
	control.set_meta("dynamic_modal_content", true)

func _add_dynamic_before_back(control: Control) -> void:
	_mark_dynamic(control)
	_modal_content().add_child(control)
	_modal_content().move_child(control, _back_button().get_index())

func _clear_dynamic_modal_content() -> void:
	for child in _modal_content().get_children():
		if child.has_meta("dynamic_modal_content"):
			child.queue_free()

func _expand_modal(half_width: float, half_height: float) -> void:
	modal.offset_left = -half_width
	modal.offset_right = half_width
	modal.offset_top = -half_height
	modal.offset_bottom = half_height

func _quit_game() -> void:
	if OS.has_feature("web"):
		_prepare_interactive_modal("THANKS FOR PLAYING!", "This browser tab can be closed whenever you are ready.")
		modal.show()
		return
	get_tree().quit()
