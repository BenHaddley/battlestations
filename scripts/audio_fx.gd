extends Node
## Autoload. Fire-and-forget one-shot SFX playback, so callers don't each
## need their own AudioStreamPlayer bookkeeping.

const SETTINGS_PATH := "user://battle_stations_settings.cfg"

func _ready() -> void:
	# Apply saved audio before either the title music or gameplay playlist starts.
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var volume := clampf(float(config.get_value("audio", "master_volume", 80.0)), 0.0, 100.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume / 100.0, 0.0001)))
	AudioServer.set_bus_mute(0, bool(config.get_value("audio", "muted", false)))

func play(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
