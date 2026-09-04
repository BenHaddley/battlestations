extends AudioStreamPlayer
## Shuffled background-music playlist. Plays every track in a randomized
## order with no immediate repeats, then reshuffles and keeps going —
## instead of looping a single song for the whole session.

const SPIDER_ASSAULT_PATH := "res://assets/audio/songs/Spider Assault - The Fun House.mp3"
const WEB_SPIDER_ASSAULT_TRACK := preload("res://assets/audio/web/Spider Assault - The Fun House.ogg")
const WEB_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/web/Maggie Blues.ogg"),
]
const SONG_DIRECTORY := "res://assets/audio/songs"
const SPIDER_ASSAULT_FILE_NAME := "Spider Assault - The Fun House.mp3"

@export var tracks: Array[AudioStream] = []

var _queue: Array[int] = []
var _last_played: int = -1
var play_history: Array[int] = [] ## Exposed for lightweight playlist regression tests.

func _ready() -> void:
	bus = &"Music"
	if CampaignManager.is_spider_assault():
		var special_track: AudioStream = WEB_SPIDER_ASSAULT_TRACK if OS.has_feature("web") else load(SPIDER_ASSAULT_PATH) as AudioStream
		tracks.clear()
		if special_track:
			tracks.append(special_track)
		else:
			tracks.assign(WEB_TRACKS)
	elif tracks.is_empty():
		tracks = WEB_TRACKS.duplicate() if OS.has_feature("web") else _load_native_playlist()
	for track in tracks:
		var mp3 := track as AudioStreamMP3
		if mp3:
			mp3.loop = CampaignManager.is_spider_assault()
	finished.connect(_play_next)
	_play_next()

func _load_native_playlist() -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	for file_name in DirAccess.get_files_at(SONG_DIRECTORY):
		if file_name.get_extension().to_lower() != "mp3" or file_name == SPIDER_ASSAULT_FILE_NAME:
			continue
		var loaded := load(SONG_DIRECTORY.path_join(file_name)) as AudioStream
		if loaded:
			result.append(loaded)
	return result if not result.is_empty() else WEB_TRACKS.duplicate()

func _play_next() -> void:
	if tracks.is_empty():
		return
	var index := _take_next_index()
	stream = tracks[index]
	play()

func _take_next_index() -> int:
	if _queue.is_empty():
		_reshuffle()
	var index: int = _queue.pop_back()
	_last_played = index
	play_history.append(index)
	return index

## Reshuffles the play order. When there's more than one track, retries
## until the new order's next pick doesn't match whatever just finished, so
## the same song never plays twice back to back across a reshuffle boundary.
func _reshuffle() -> void:
	_queue.assign(range(tracks.size()))
	_queue.shuffle()
	if tracks.size() > 1:
		while _queue[-1] == _last_played:
			_queue.shuffle()
