extends Control
## Functional shell over the authored 16:9 title-screen illustration.

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
	start_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not modal.visible and not start_choice_modal.visible:
		_on_start_pressed()
	elif event.is_action_pressed("ui_cancel"):
		if modal.visible:
			modal.hide()
		elif start_choice_modal.visible:
			start_choice_modal.hide()
		else:
			_quit_game()

func _play_music_looped() -> void:
	var stream: AudioStreamMP3 = music_player.stream as AudioStreamMP3
	if stream:
		stream.loop = true
	music_player.play()

## Only offers the continue/new-game choice when there's an actual saved
## run to continue — a first-time player just starts straight in, same as
## before this existed.
func _on_start_pressed() -> void:
	if starting:
		return
	if CampaignManager.has_saved_progress():
		start_choice_modal.show()
		continue_button.grab_focus()
	else:
		_on_new_game_pressed()

func _on_continue_pressed() -> void:
	start_choice_modal.hide()
	CampaignManager.continue_saved_game()
	_launch_game()

func _on_new_game_pressed() -> void:
	start_choice_modal.hide()
	CampaignManager.restart_campaign()
	_launch_game()

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
