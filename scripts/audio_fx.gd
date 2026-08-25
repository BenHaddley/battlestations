extends Node
## Autoload. Fire-and-forget one-shot SFX playback, so callers don't each
## need their own AudioStreamPlayer bookkeeping.

func play(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
