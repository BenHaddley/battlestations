extends AudioStreamPlayer
## Shuffled background-music playlist. Plays every track in a randomized
## order with no immediate repeats, then reshuffles and keeps going —
## instead of looping a single song for the whole session.

@export var tracks: Array[AudioStream] = []

var _queue: Array[int] = []
var _last_played: int = -1
var play_history: Array[int] = [] ## Exposed for lightweight playlist regression tests.

func _ready() -> void:
	for track in tracks:
		var mp3 := track as AudioStreamMP3
		if mp3:
			mp3.loop = false
	finished.connect(_play_next)
	_play_next()

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
