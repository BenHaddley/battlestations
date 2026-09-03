extends Node
## Autoload. Fire-and-forget one-shot SFX playback, so callers don't each
## need their own AudioStreamPlayer bookkeeping.

var _cue_cache: Dictionary = {}

func _ready() -> void:
	pass

func play(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

## Short procedural UI cues avoid adding provenance-sensitive placeholder files.
func play_cue(cue: StringName) -> void:
	var settings: Array = {
		&"purchase": [660.0, 0.09, -10.0],
		&"upgrade": [880.0, 0.12, -9.0],
		&"station_hit": [105.0, 0.16, -7.0],
		&"ui": [440.0, 0.055, -14.0],
	}.get(cue, [330.0, 0.06, -14.0])
	if not _cue_cache.has(cue):
		_cue_cache[cue] = _tone(float(settings[0]), float(settings[1]))
	play(_cue_cache[cue], float(settings[2]))

func _tone(frequency: float, duration: float) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var frames := maxi(1, roundi(SAMPLE_RATE * duration))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for frame in range(frames):
		var progress := float(frame) / float(frames)
		var envelope := sin(PI * progress)
		var sample := sin(TAU * frequency * float(frame) / SAMPLE_RATE) * envelope
		bytes.encode_s16(frame * 2, int(sample * 16000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
