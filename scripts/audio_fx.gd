extends Node
## Autoload. Fire-and-forget one-shot SFX playback, so callers don't each
## need their own AudioStreamPlayer bookkeeping. Crowded moments — a
## Chaingunner burst landing while a wave dies — are kept readable by
## capping how many copies of one sound play at once and ducking the
## extras, on top of a limiter on the SFX bus (see AppSettings).

## At most this many simultaneous players of the same stream; further
## requests within the window are dropped so bursts cannot pile up.
const MAX_VOICES_PER_STREAM := 4
## Each extra simultaneous copy of a sound plays this much quieter.
const STACK_DUCK_DB := -3.0

var _cue_cache: Dictionary = {}
## stream path (or object id) -> Array of live AudioStreamPlayer
var _voices: Dictionary = {}
var dropped_voices: int = 0

func _ready() -> void:
	pass

func play(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var key := _voice_key(stream)
	var live: Array = _voices.get(key, [])
	live = live.filter(func(player) -> bool: return is_instance_valid(player) and player.playing)
	if live.size() >= MAX_VOICES_PER_STREAM:
		_voices[key] = live
		dropped_voices += 1
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db + STACK_DUCK_DB * live.size()
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	live.append(player)
	_voices[key] = live

## Live players for a stream — used by tests and the debug overlay.
func active_voices(stream: AudioStream) -> int:
	var live: Array = _voices.get(_voice_key(stream), [])
	var count := 0
	for player in live:
		if is_instance_valid(player) and player.playing:
			count += 1
	return count

func _voice_key(stream: AudioStream) -> String:
	return stream.resource_path if not stream.resource_path.is_empty() else str(stream.get_instance_id())

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
