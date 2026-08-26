extends Control
## Functional shell over the authored 16:9 title-screen illustration.

const StartGameDialogueScript := preload("res://scripts/start_game_dialogue.gd")
const TUTORIAL_SAVE_PATH := "user://battle_stations_tutorial.cfg"

@onready var start_button: Button = $StartButton
@onready var press_start_button: Button = $PressStartButton
@onready var challenges_button: Button = $ChallengesButton
@onready var options_button: Button = $OptionsButton
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
	Engine.time_scale = 1.0
	get_tree().paused = false
	_play_music_looped()
	start_button.pressed.connect(_on_start_pressed)
	press_start_button.pressed.connect(_on_start_pressed)
	challenges_button.pressed.connect(_show_challenges)
	options_button.pressed.connect(_show_options)
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
	press_start_button.disabled = true
	music_player.stop()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _show_challenges() -> void:
	modal_title.text = "CHALLENGES"
	modal_copy.text = "Challenge cards are being prepared.\n\nFor now: keep the station safe and build your train."
	modal.show()
	$Modal/Margin/VBox/BackButton.grab_focus()

func _show_options() -> void:
	modal_title.text = "OPTIONS"
	modal_copy.text = "Use the illustrated controls in battle to pause or run at double speed.\n\nMore sound and display options are coming soon."
	modal.show()
	$Modal/Margin/VBox/BackButton.grab_focus()

func _quit_game() -> void:
	if OS.has_feature("web"):
		modal_title.text = "THANKS FOR PLAYING!"
		modal_copy.text = "This browser tab can be closed whenever you are ready."
		modal.show()
		return
	get_tree().quit()
