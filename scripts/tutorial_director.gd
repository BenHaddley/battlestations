extends CanvasLayer
class_name TutorialDirector
## Event-driven campaign dialogue. This scene deliberately discovers the
## current Main nodes instead of requiring edits to the campaign/phase work.

const SAVE_PATH := "user://battle_stations_tutorial.cfg"

var overlay: DialogueOverlay
var main: Node
var spawner: EnemySpawner
var menu: Menu
var queue: Array[Dictionary] = []
var current: Dictionary = {}
var baseline_car_count := 0
var tutorial_active := false
var first_wave_seen := false
var first_payout_seen := false
var final_wave_hyped := false
var pause_state_before_sequence := false

func _ready() -> void:
	layer = 250
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = DialogueOverlay.new()
	add_child(overlay)
	overlay.advance_requested.connect(_advance)
	overlay.skip_requested.connect(_skip_all)
	call_deferred("_connect_game")

func _connect_game() -> void:
	main = get_tree().current_scene
	if main == null:
		return
	# Reverse mode owns its short Duck and Daisy introduction; campaign tutorial
	# prompts about buying train cars would contradict Spider Assault.
	if CampaignManager.is_spider_assault():
		return
	spawner = main.get_node_or_null("EnemySpawner")
	menu = main.get_node_or_null("CanvasLayer/Menu")
	if spawner:
		spawner.wave_started.connect(_on_wave_started)
		spawner.wave_cleared.connect(_on_wave_cleared)
	if CampaignManager.has_signal("level_completed"):
		CampaignManager.level_completed.connect(_on_level_completed)
	baseline_car_count = _car_count()
	var level_index: int = int(CampaignManager.get("current_level_index"))
	var new_game_requested := CampaignManager.consume_tutorial_request()
	if level_index == 0 and (new_game_requested or not _tutorial_was_completed()):
		tutorial_active = true
		_enqueue([
			_entry("Duck", "Welcome aboard. See that train. That is your defense."),
			_entry("Daisy", "Against spiders, specifically. Please do not fire at the furniture."),
			_entry("Duck", "No promises. Grab that Gunner from the Train Yard and couple it up.", "gunner_placed", "DRAG THE GUNNER ONTO A TRAIN"),
		])
	else:
		_enqueue(_campaign_intro(level_index))

func _process(_delta: float) -> void:
	if not tutorial_active or current.is_empty():
		return
	match String(current.get("wait_for", "")):
		"gunner_placed":
			if _car_count() > baseline_car_count:
				_complete_requirement([
					_entry("Daisy", "Good. The weapons ride the rails instead of sitting around the board."),
					_entry("Duck", "And the engine handles the driving. Hands free. Mostly."),
					_entry("Daisy", "Start the wave when you are ready.", "wave_started", "START THE FIRST WAVE"),
				])

func _on_wave_started(wave: int) -> void:
	if tutorial_active and String(current.get("wait_for", "")) == "wave_started":
		_complete_requirement([
			_entry("Duck", "Spiders incoming. Your Gunner fires whenever one gets close."),
			_entry("Daisy", "You steer the plan. The weapon handles the shooting."),
		])
	first_wave_seen = true
	if spawner and spawner.wave_target > 0 and wave == spawner.wave_target and not final_wave_hyped:
		final_wave_hyped = true
		_enqueue([
			_entry("Duck", "Final wave. This is where legends are forged."),
			_entry("Daisy", "Or where Duck learns what indoor voice means."),
		])

func _on_wave_cleared(wave: int) -> void:
	if tutorial_active and wave == 1 and not first_payout_seen:
		first_payout_seen = true
		_enqueue([
			_entry("Duck", "We survived, and got paid. More Delta means more train cars."),
			_entry("Daisy", "Spend carefully. Every car adds weight to the train."),
			_entry("Duck", "A heavy train still hits hard. It just stops being graceful."),
		])

func _on_level_completed(_level, _is_finale: bool) -> void:
	var level_index: int = int(CampaignManager.get("current_level_index"))
	var ending: Array[Dictionary] = [
		_entry("Duck", "Station secured. I knew the train would pull through."),
		_entry("Daisy", "The player pulled through. The train followed the track."),
	]
	if level_index == 0:
		ending.append(_entry("Duck", "Same thing. Next stop, a bigger arsenal."))
		_mark_tutorial_completed()
	_enqueue(ending)

func _campaign_intro(level_index: int) -> Array[Dictionary]:
	match level_index:
		1: return [_entry("Duck", "Passenger Coach. It makes Delta while the train moves."), _entry("Daisy", "An economy car. Try not to spend its earnings before they exist.")]
		2: return [_entry("Duck", "The Ballast Blaster is for spiders with no respect for personal space."), _entry("Daisy", "Clusters. He means it works well against clusters.")]
		3: return [_entry("Duck", "Coal Cannon. Big shell, big noise, very satisfying."), _entry("Daisy", "Save it for tougher spiders. It trades speed for force.")]
		4: return [_entry("Duck", "Brake Van on the tail. Now the whole train means business."), _entry("Daisy", "It caps the consist and strengthens the cars ahead of it.")]
		5: return [_entry("Duck", "The Tender lets the engine haul a much heavier defense."), _entry("Daisy", "Put it directly behind the engine or the extra capacity will not count.")]
		6: return [_entry("Duck", "Chaingunner. Seven shots of extremely enthusiastic problem solving."), _entry("Daisy", "Powerful bursts, followed by a long cooldown. Plan around both.")]
		_: return []

func _entry(speaker: String, text: String, wait_for := "", hint := "") -> Dictionary:
	return {"speaker": speaker, "text": text, "wait_for": wait_for, "action_hint": hint}

func _enqueue(entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	queue.append_array(entries)
	if current.is_empty():
		pause_state_before_sequence = PhaseManager.paused
		_show_next()

func _show_next() -> void:
	if queue.is_empty():
		current = {}
		overlay.visible = false
		PhaseManager.paused = pause_state_before_sequence
		return
	current = queue.pop_front()
	# Even requirement-bearing entries begin as conversation. The first advance
	# switches them into objective mode and releases the station clock.
	PhaseManager.paused = true
	overlay.show_entry(current)

func _advance() -> void:
	if current.is_empty():
		return
	var requirement := String(current.get("wait_for", ""))
	if not requirement.is_empty():
		# Speak the instruction first. Advancing retracts the characters and
		# exposes a small objective tag while the gameplay event remains armed.
		if not overlay.waiting_for_action:
			overlay.show_objective(String(current.get("action_hint", "CONTINUE THE OBJECTIVE")))
			PhaseManager.paused = false
		return
	_show_next()

func _complete_requirement(followups: Array[Dictionary]) -> void:
	current = {}
	overlay.visible = false
	queue.append_array(followups)
	_show_next()

func _skip_all() -> void:
	queue.clear()
	current = {}
	overlay.visible = false
	PhaseManager.paused = pause_state_before_sequence
	if tutorial_active:
		_mark_tutorial_completed()
	tutorial_active = false

func _car_count() -> int:
	var total := 0
	var convoys = main.get("convoys") if main else null
	if convoys == null:
		return 0
	for convoy in convoys:
		if is_instance_valid(convoy):
			total += int(convoy.car_count())
	return total

func _tutorial_was_completed() -> bool:
	var config := ConfigFile.new()
	return config.load(SAVE_PATH) == OK and bool(config.get_value("tutorial", "completed", false))

func _mark_tutorial_completed() -> void:
	var config := ConfigFile.new()
	config.set_value("tutorial", "completed", true)
	config.save(SAVE_PATH)
