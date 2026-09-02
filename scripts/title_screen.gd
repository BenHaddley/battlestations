extends Control
## Functional shell over the authored 16:9 title-screen illustration.

const StartGameDialogueScript := preload("res://scripts/start_game_dialogue.gd")
const TUTORIAL_SAVE_PATH := "user://battle_stations_tutorial.cfg"

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

## Start always opens the character-led choice. With no meaningful save the
## Continue option is visibly unavailable and Daisy points the player to New Game.
func _on_start_pressed() -> void:
	if starting:
		return
	start_choice_modal.hide()
	start_dialogue.open(CampaignManager.has_saved_progress())

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
	if FileAccess.file_exists(TUTORIAL_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_SAVE_PATH))

func _launch_game() -> void:
	if starting:
		return
	starting = true
	start_button.disabled = true
	music_player.stop()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _show_level_select() -> void:
	_show_info_modal("LEVEL SELECT", "Replay unlocked stations and return for any objectives you missed.\n\nLevel selection is coming in a later update.")

func _show_almanac() -> void:
	_show_info_modal("ALMANAC", "Review discovered trains, cars, spiders, and railway notes.\n\nThe almanac is coming in a later update.")

func _show_achievements() -> void:
	_show_info_modal("ACHIEVEMENTS", "Complete special tasks to earn medals for this cabinet.\n\nAchievements are coming in a later update.")

func _show_profiles() -> void:
	_show_info_modal("PROFILES", "Three separate railway profiles are planned.\n\nProfile switching is coming in a later update.")

func _show_info_modal(title: String, copy: String) -> void:
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
	_show_info_modal("SETTINGS", "Use the illustrated controls in battle to pause or run at double speed.\n\nMore sound and display options are coming soon.")

func _quit_game() -> void:
	if OS.has_feature("web"):
		modal_title.text = "THANKS FOR PLAYING!"
		modal_copy.text = "This browser tab can be closed whenever you are ready."
		modal.show()
		return
	get_tree().quit()
