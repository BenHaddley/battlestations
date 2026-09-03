extends Control
## Functional shell over the authored 16:9 title-screen illustration.

const StartGameDialogueScript := preload("res://scripts/start_game_dialogue.gd")
const EnemyDataResource := preload("res://scripts/enemy_data.gd")
const TUTORIAL_SAVE_FILE := "tutorial.cfg"

@onready var start_button: Button = $StartButton
@onready var level_select_button: Button = $LevelSelectButton
@onready var challenges_button: Button = $ChallengesButton
@onready var almanac_button: Button = $AlmanacButton
@onready var achievements_button: Button = $AchievementsButton
@onready var options_button: Button = $OptionsButton
@onready var profile_button: Button = $ProfileButton
@onready var quit_button: Button = $QuitButton
@onready var modal: PanelContainer = $Modal
@onready var modal_title: Label = $Modal/Margin/VBox/Title
@onready var modal_copy: Label = $Modal/Margin/VBox/Copy
@onready var music_player: AudioStreamPlayer = $MusicPlayer

@onready var start_choice_modal: PanelContainer = $StartChoiceModal
@onready var continue_button: Button = $StartChoiceModal/Margin/VBox/ContinueButton
@onready var new_game_button: Button = $StartChoiceModal/Margin/VBox/NewGameButton

var starting := false
var start_dialogue: Control

func _ready() -> void:
	if _is_artist_grid_build():
		get_tree().change_scene_to_file("res://scenes/ArtistGridView.tscn")
		return
	Engine.time_scale = 1.0
	AppSettings.load_settings()
	music_player.bus = &"Music"
	get_tree().paused = false
	_play_music_looped()
	start_button.pressed.connect(_on_start_pressed)
	level_select_button.pressed.connect(_show_level_select)
	challenges_button.pressed.connect(_show_challenges)
	almanac_button.pressed.connect(_show_almanac)
	achievements_button.pressed.connect(_show_achievements)
	options_button.pressed.connect(_show_options)
	profile_button.pressed.connect(_show_profiles)
	quit_button.pressed.connect(_quit_game)
	$Modal/Margin/VBox/BackButton.pressed.connect(func() -> void: modal.hide())
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	start_dialogue = StartGameDialogueScript.new()
	add_child(start_dialogue)
	start_dialogue.continue_selected.connect(_on_continue_pressed)
	start_dialogue.restart_selected.connect(_on_new_game_pressed)
	start_dialogue.closed.connect(start_button.grab_focus)
	start_button.grab_focus()

## Pages publishes the same tested game pack beneath /test. Detecting the URL
## here keeps the production title screen untouched while giving artists a
## stable, shareable registration sheet built from the live grid constants.
func _is_artist_grid_build() -> bool:
	if not OS.has_feature("web"):
		return "--artist-grid" in OS.get_cmdline_user_args()
	var location = JavaScriptBridge.eval("window.location.pathname + window.location.search")
	return String(location).contains("/test") or String(location).contains("artist-grid")

func _unhandled_input(event: InputEvent) -> void:
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
	var stream: AudioStreamMP3 = music_player.stream as AudioStreamMP3
	if stream:
		stream.loop = true
	music_player.play()

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
	music_player.stop()
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
	_prepare_interactive_modal("ALMANAC", "Units reveal their entries after appearing in a run.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(630, 470)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for tower in BuildManager.towers:
		_add_almanac_card(grid, "tower:%s" % tower.tower_name.to_snake_case(), tower.tower_name, tower.summary, tower.icon)
	for profile in EnemyRoster.PROFILES:
		var data := EnemyDataResource.new()
		data.enemy_id = String(profile.id)
		data.enemy_name = String(profile.name)
		data.summary = _enemy_summary(String(profile.get("ability", "")))
		data.icon = profile.walk_a
		_add_almanac_card(grid, "enemy:%s" % data.enemy_id, data.enemy_name, data.summary, data.icon)
	_add_dynamic_before_back(scroll)
	_expand_modal(365.0, 340.0)
	modal.show()

func _add_almanac_card(parent: GridContainer, content_id: String, title: String, summary: String, icon: Texture2D) -> void:
	var discovered := DiscoveryTracker.is_discovered(content_id)
	var card := Button.new()
	card.disabled = true
	card.custom_minimum_size = Vector2(300, 104)
	card.text = "%s\n%s" % [title, summary] if discovered else "???\nNOT YET DISCOVERED"
	card.icon = icon if discovered else null
	card.expand_icon = true
	card.add_theme_constant_override("icon_max_width", 72)
	card.modulate = Color.WHITE if discovered else Color(0.38, 0.38, 0.38, 0.72)
	parent.add_child(card)

func _enemy_summary(ability: String) -> String:
	return {
		"dots": "Changes form as it takes damage.", "charge": "Bursts forward at speed.",
		"rally": "Strengthens nearby spiders.", "armor": "Shrugs off repeated hits.",
		"enrage": "Enrages below half health.", "jump": "Moves only while jumping.",
		"hatch": "Hatches into smaller spiders.", "": "A quick railway pest."
	}.get(ability, "A dangerous railway pest.")

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

func _show_info_modal(title: String, copy: String) -> void:
	_clear_dynamic_modal_content()
	modal_copy.visible = true
	_clear_challenge_buttons()
	modal_title.text = title
	modal_copy.text = copy
	_reset_modal_size()
	modal.show()
	$Modal/Margin/VBox/BackButton.grab_focus()

func _clear_challenge_buttons() -> void:
	for old_button in $Modal/Margin/VBox.get_children():
		if old_button is Button and old_button.name.begins_with("Challenge"):
			old_button.queue_free()

func _reset_modal_size() -> void:
	modal.offset_left = -250.0
	modal.offset_right = 250.0
	modal.offset_top = -145.0
	modal.offset_bottom = 145.0

func _show_challenges() -> void:
	modal_title.text = "CHALLENGE JOB CARDS"
	modal_copy.text = "Pick one strange railway job. Challenge runs do not overwrite campaign progress."
	_clear_challenge_buttons()
	var back_button: Button = $Modal/Margin/VBox/BackButton
	for challenge in CampaignManager.CHALLENGES:
		var button := Button.new()
		button.name = "Challenge%s" % String(challenge.id).to_pascal_case()
		button.custom_minimum_size = Vector2(0, 48)
		button.text = "%s. %s" % [String(challenge.name), String(challenge.tagline)]
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color("2b160d"))
		button.pressed.connect(_launch_challenge.bind(String(challenge.id)))
		$Modal/Margin/VBox.add_child(button)
		$Modal/Margin/VBox.move_child(button, back_button.get_index())
	modal.offset_left = -330.0
	modal.offset_right = 330.0
	modal.offset_top = -335.0
	modal.offset_bottom = 335.0
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
		modal_title.text = "THANKS FOR PLAYING!"
		modal_copy.text = "This browser tab can be closed whenever you are ready."
		modal.show()
		return
	get_tree().quit()
