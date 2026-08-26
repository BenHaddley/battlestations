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

var starting := false

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_play_music_looped()
	start_button.pressed.connect(_start_game)
	press_start_button.pressed.connect(_start_game)
	challenges_button.pressed.connect(_show_challenges)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(_quit_game)
	$Modal/Margin/VBox/BackButton.pressed.connect(func() -> void: modal.hide())
	start_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not modal.visible:
		_start_game()
	elif event.is_action_pressed("ui_cancel"):
		if modal.visible:
			modal.hide()
		else:
			_quit_game()

func _play_music_looped() -> void:
	var stream: AudioStreamMP3 = music_player.stream as AudioStreamMP3
	if stream:
		stream.loop = true
	music_player.play()

func _start_game() -> void:
	if starting:
		return
	starting = true
	start_button.disabled = true
	press_start_button.disabled = true
	music_player.stop()
	CampaignManager.restart_campaign()
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
