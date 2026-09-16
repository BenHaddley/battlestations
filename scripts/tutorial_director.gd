extends CanvasLayer
class_name TutorialDirector
## Duck and Daisy teach the campaign progressively. Every lesson is keyed and
## recorded per profile, so a fresh profile sees the opening again, a
## continued save still meets every car it has unlocked, and a skipped lesson
## never nags twice. Lessons with an objective highlight the control or unit
## involved and hold the departure clock until the player has done it (or
## chooses to start the wave anyway). Battle events queue their lesson for
## the next STATION so combat never talks over an unfinished instruction.

const SAVE_FILE := "tutorial.cfg"
const RAIL_COST_FALLBACK := 50

var overlay: DialogueOverlay
var main: Node
var spawner: EnemySpawner
var menu: Menu
var queue: Array[Dictionary] = []
## Sequences raised during BATTLE that must wait for the next STATION.
var station_backlog: Array[Dictionary] = []
var current: Dictionary = {}
## Lesson id that owns the sequence on screen; marked complete when it ends.
var current_lesson := ""
var lessons_done: Dictionary = {}
## Lesson ids raised during BATTLE, shown once the wave clears.
var deferred_lessons: Array[String] = []
var baseline_car_count := 0
var tutorial_active := false
var first_wave_seen := false
var final_wave_hyped := false
var level_index := 0
var _car_counts_at_objective: Dictionary = {}
var _rail_built_since_objective := false
var _event_lessons_seen_this_level: Dictionary = {}

func _ready() -> void:
	layer = 250
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = DialogueOverlay.new()
	add_child(overlay)
	overlay.advance_requested.connect(_advance)
	overlay.skip_requested.connect(_skip_all)
	call_deferred("_connect_game")

func _connect_game() -> void:
	# The director is instanced inside Main.tscn, so its parent is the level
	# even when Main itself is embedded under another root (the regression
	# suite does exactly that).
	main = get_parent()
	if main == null or main.get_node_or_null("EnemySpawner") == null:
		main = get_tree().current_scene
	if main == null:
		return
	# Reverse mode owns its short Duck and Daisy introduction; campaign tutorial
	# prompts about buying train cars would contradict Spider Assault. Challenge
	# job cards are remixes, not lessons.
	if CampaignManager.is_challenge_active():
		return
	spawner = main.get_node_or_null("EnemySpawner")
	menu = main.get_node_or_null("CanvasLayer/Menu")
	if spawner:
		spawner.wave_started.connect(_on_wave_started)
		spawner.wave_cleared.connect(_on_wave_cleared)
	if CampaignManager.has_signal("level_completed"):
		CampaignManager.level_completed.connect(_on_level_completed)
	var builder = main.get("rail_builder")
	if builder != null and builder.has_signal("rail_built"):
		builder.rail_built.connect(_on_rail_built)
	GameEvents.train_unit_bitten.connect(_on_unit_bitten)
	GameEvents.train_unit_destroyed.connect(_on_unit_destroyed)
	GameEvents.engine_wrecked.connect(_on_engine_wrecked)
	load_progress()
	baseline_car_count = _car_count()
	level_index = int(CampaignManager.get("current_level_index"))
	var new_game_requested := CampaignManager.consume_tutorial_request()
	if new_game_requested:
		# A new campaign forgets every lesson, even if a browser has not yet
		# flushed the title screen's deletion of the old save.
		reset_progress()
		lessons_done = {}
	if level_index == 0 and (new_game_requested or not is_done("opening")):
		tutorial_active = true
		_begin_lesson("opening", [
			_entry("Duck", "Welcome aboard. See that train. That is your defense."),
			_entry("Daisy", "Against spiders, specifically. Please do not fire at the furniture."),
			_entry("Duck", "No promises. Grab that Gunner from the Train Yard and couple it up.", "gunner_placed", "DRAG THE GUNNER ONTO A TRAIN", _highlight_shop_button.bind(0)),
			_entry("Daisy", "Good. The weapons ride the rails instead of sitting around the board."),
			_entry("Duck", "And the engine handles the driving. Hands free. Mostly."),
			_entry("Daisy", "The departure clock is held while we talk. Start the wave when you are ready.", "wave_started", "PRESS START WAVE", _highlight_wave_button),
			_entry("Duck", "Spiders incoming. Your Gunner fires whenever one gets close."),
			_entry("Daisy", "You steer the plan. The weapon handles the shooting."),
		])
	else:
		_queue_car_lessons()

# ---------------------------------------------------------------------------
# Per-profile progress
# ---------------------------------------------------------------------------

func load_progress() -> void:
	lessons_done = {}
	var config := ConfigFile.new()
	if config.load(ProfileManager.profile_path(SAVE_FILE)) != OK:
		return
	if bool(config.get_value("tutorial", "completed", false)):
		lessons_done["opening"] = true
		lessons_done["car:0"] = true
	if config.has_section("lessons"):
		for key in config.get_section_keys("lessons"):
			if bool(config.get_value("lessons", key, false)):
				lessons_done[key] = true

func save_progress() -> void:
	var config := ConfigFile.new()
	config.load(ProfileManager.profile_path(SAVE_FILE))
	config.set_value("tutorial", "completed", lessons_done.has("opening"))
	for lesson_id in lessons_done:
		config.set_value("lessons", lesson_id, true)
	config.save(ProfileManager.profile_path(SAVE_FILE))

func is_done(lesson_id: String) -> bool:
	return lessons_done.has(lesson_id)

func mark_done(lesson_id: String) -> void:
	if lesson_id.is_empty() or lessons_done.has(lesson_id):
		return
	lessons_done[lesson_id] = true
	save_progress()

## Forgets every lesson for the active profile so guidance plays again. A
## live director re-arms immediately; the next STATION reintroduces the cars
## already unlocked.
static func reset_progress() -> void:
	var path := ProfileManager.profile_path(SAVE_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func reload_progress() -> void:
	load_progress()
	_event_lessons_seen_this_level.clear()
	if current.is_empty() and PhaseManager.is_station():
		_queue_car_lessons()

# ---------------------------------------------------------------------------
# Lesson scheduling
# ---------------------------------------------------------------------------

## Every unlocked car the profile has not been introduced to, in unlock order,
## so a continued save or a level that unlocks two cars still meets each one.
func _queue_car_lessons() -> void:
	if not CampaignManager.challenge_shop_enabled():
		return
	var level: LevelData = CampaignManager.current_level()
	if level == null:
		return
	for tower_index in level.unlocked_tower_indices:
		var lesson_id := "car:%d" % tower_index
		if is_done(lesson_id) or tower_index >= BuildManager.towers.size():
			continue
		_begin_lesson(lesson_id, _car_lesson(tower_index))

func _car_lesson(tower_index: int) -> Array[Dictionary]:
	var tower: TowerData = BuildManager.towers[tower_index]
	var lines: Array[Dictionary] = []
	match tower_index:
		0:
			lines = [_entry("Duck", "Gunner Car. Reliable single-target fire across a 7×7 reach."), _entry("Daisy", "It fires on its own at the nearest spider. Your job is where the train goes.")]
		1:
			lines = [_entry("Duck", "Chaingunner. Seven shots of extremely enthusiastic problem solving."), _entry("Daisy", "A seven-round burst across 7×7, then a four-second recharge. Plan around both.")]
		2:
			lines = [_entry("Duck", "The Ballast Blaster is for spiders with no respect for personal space."), _entry("Daisy", "Clusters. He means it hits everything inside its short 3×3 reach at once.")]
		3:
			lines = [_entry("Duck", "Passenger Coach. It makes Delta while the train moves."), _entry("Daisy", "An economy car. Δ32 every eight seconds. Try not to spend its earnings before they exist.")]
		4:
			lines = [_entry("Duck", "Coal Cannon. Big shell, big noise, very satisfying."), _entry("Daisy", "Slow, heavy, 5×5 reach, and the shell knocks spiders back. Save it for the tough ones.")]
		5:
			lines = [_entry("Duck", "Brake Van on the tail. Now the whole train means business."), _entry("Daisy", "It weighs nothing and gives attacking cars 25% more damage, but nothing couples behind it. Put it on last.")]
		6:
			lines = [_entry("Duck", "The Tender lets the engine haul a much heavier defense."), _entry("Daisy", "Directly behind the engine or the extra capacity will not count. Click the engine afterwards and watch its capacity jump.")]
		7:
			lines = [_entry("Duck", "Mail Carrier. It flings envelopes, fast, at anything within 5×5."), _entry("Daisy", "Every envelope picks its own random spider. Weak letters, a lot of them, and crowds hate it.")]
		_:
			lines = [_entry("Duck", "%s. A new car for the yard." % tower.tower_name), _entry("Daisy", tower.summary)]
	var objective := "car_placed:%d" % tower_index
	if _car_lesson_feasible(tower):
		lines.append(_entry("Duck", "Couple one now, then we roll.", objective, "DRAG THE %s ONTO A TRAIN" % tower.tower_name.to_upper(), _highlight_shop_button.bind(tower_index)))
	else:
		lines.append(_entry("Daisy", "It costs Δ%d and weighs %d. Couple one once the wallet and the train can take it." % [tower.cost, roundi(tower.weight)]))
	return lines

## A guided task is only set when the player can actually complete it with
## the money, capacity and trains on the board right now.
func _car_lesson_feasible(tower: TowerData) -> bool:
	if tower == null or LevelManager.currency < tower.cost:
		return false
	var convoys = main.get("convoys") if main else null
	if convoys == null:
		return false
	for convoy in convoys:
		if not is_instance_valid(convoy) or convoy.get("capped") == true or convoy.get("wrecked") == true:
			continue
		if float(convoy.total_weight()) + tower.weight <= float(convoy.effective_capacity()):
			return true
	return false

## STATION lessons in a fixed order: the first-payout chat belongs to the
## opening mission; driving, rail building and car information are general and play
## at the first STATION after a wave on whichever level the profile reaches
## them, so a continued save is never left untaught.
func _station_lessons_for_level() -> void:
	if not station_backlog.is_empty():
		var backlog := station_backlog.duplicate()
		station_backlog.clear()
		_enqueue(backlog, true)
	if level_index == 0 and tutorial_active and not is_done("payout"):
		_begin_lesson("payout", [
			_entry("Duck", "We survived, and got paid. More Delta means more train cars."),
			_entry("Daisy", "Spend carefully. Every car adds weight to the train."),
			_entry("Duck", "A heavy train still hits hard. It just stops being graceful."),
			_entry("Daisy", "From here the departure clock runs itself. START WAVE skips the wait whenever you are ready."),
		])
	if not is_done("driving"):
		_begin_lesson("driving", [
			_entry("Daisy", "During STATIONS, trains stay parked. Click an engine to select it."),
			_entry("Duck", "Hold Up to drive forward or Down to back up. Release the key to park. Try it now.", "train_driven", "SELECT AN ENGINE, THEN HOLD UP OR DOWN", _highlight_first_engine),
			_entry("Daisy", "During BATTLE it cruises automatically. Tap Down to slow, or hold it to reverse."),
		])
	if not is_done("rails") and CampaignManager.challenge_shop_enabled():
		var rail_cost := _rail_cost()
		var rail_lines: Array[Dictionary] = [
			_entry("Duck", "Choose BUILD TRACK to clear the trains from view. Hover a rail and click a plus; choose DONE BUILDING when finished."),
			_entry("Daisy", "Δ%d a tile, for now. Trains pause at a buffer stop, then reverse. Blue join rings connect touching tracks, even separate circuits, for free." % rail_cost),
		]
		if LevelManager.currency >= rail_cost:
			rail_lines.append(_entry("Duck", "Lay one tile.", "rail_built", "HOVER A RAIL TILE, CLICK A PLUS  (Δ%d)" % rail_cost, _highlight_first_engine))
		rail_lines.append(_entry("Daisy", "Rails only go down during STATIONS. Right-click a tile you laid to lift it for a refund."))
		_begin_lesson("rails", rail_lines)
	if not is_done("car_info") and _upgrade_lesson_feasible():
		_begin_lesson("car_info", [
			_entry("Duck", "Click any coupled car to open its car information card."),
			_entry("Daisy", "Check its weapon and health here. Selling refunds half its purchase price.", "panel_opened", "CLICK A CAR ON THE TRAIN", _highlight_first_car),
			_entry("Duck", "Close the card whenever you are done and we carry on."),
		])
	for lesson_id in deferred_lessons:
		_begin_lesson(lesson_id, _event_lesson_lines(lesson_id))
	deferred_lessons.clear()

func _upgrade_lesson_feasible() -> bool:
	if main == null or main.get("upgrade_panel") == null:
		return false
	return _car_count() > 0

func _event_lesson_lines(lesson_id: String) -> Array[Dictionary]:
	match lesson_id:
		"biting":
			return [
				_entry("Daisy", "Did you see that? A spider walks round a train if a lane beside it is clear."),
				_entry("Duck", "And chews on it when there is not. About twenty-five damage a second, each. A bite pins the whole train until the spider is cleared."),
			]
		"destroyed":
			return [
				_entry("Duck", "We lost a car. The train closed the gap on its own."),
				_entry("Daisy", "Whatever that car gave us went with it: firepower, income, capacity, buffs. Rebuild during STATIONS."),
			]
		"wreck":
			return [
				_entry("Daisy", "An engine is wrecked. Its cars still fire from where they stand."),
				_entry("Duck", "Drop a new locomotive from the Train Yard onto the wreck and the whole train rolls again."),
			]
	return []

func _begin_lesson(lesson_id: String, entries: Array[Dictionary]) -> void:
	if entries.is_empty() or is_done(lesson_id):
		return
	for entry in entries:
		entry["lesson"] = lesson_id
	_enqueue(entries)

func _rail_cost() -> int:
	var builder = main.get("rail_builder") if main else null
	return int(builder.rail_cost) if builder != null else RAIL_COST_FALLBACK

# ---------------------------------------------------------------------------
# Game events
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if current.is_empty():
		return
	var requirement := String(current.get("wait_for", ""))
	if requirement.is_empty() or not overlay.waiting_for_action:
		return
	if _requirement_met(requirement):
		_complete_requirement()
	elif _relax_unavailable_car_objective():
		overlay.show_entry(current)

## Keep the introduction, but do not demand a purchase the current wallet
## and consist cannot support. The player can continue and buy later.
func _relax_unavailable_car_objective() -> bool:
	var requirement := String(current.get("wait_for", ""))
	if not requirement.begins_with("car_placed:") and requirement != "gunner_placed":
		return false
	var index := 0 if requirement == "gunner_placed" else int(requirement.trim_prefix("car_placed:"))
	var tower: TowerData = BuildManager.towers[index]
	if _car_lesson_feasible(tower):
		return false
	current["wait_for"] = ""
	current["text"] = "%s costs Δ%d and weighs %d. Couple one when the wallet and an uncapped train have room." % [tower.tower_name, tower.cost, roundi(tower.weight)]
	current.erase("highlight")
	current.erase("action_hint")
	return true

func _requirement_met(requirement: String) -> bool:
	match requirement:
		"gunner_placed":
			return _car_count() > baseline_car_count
		"train_driven":
			var convoys = main.get("convoys") if main else null
			if convoys == null:
				return false
			for convoy in convoys:
				if is_instance_valid(convoy) and int(convoy.get("manual_axis")) != 0:
					return true
			return false
		"panel_opened":
			var panel = main.get("upgrade_panel") if main else null
			return panel != null and panel.visible
		"rail_built":
			return _rail_built_since_objective
		"wave_started":
			return false
	if requirement.begins_with("car_placed:"):
		var tower_index := int(requirement.trim_prefix("car_placed:"))
		return _cars_of(tower_index) > int(_car_counts_at_objective.get(tower_index, 0))
	return false

func _on_wave_started(wave: int) -> void:
	first_wave_seen = true
	if not current.is_empty() and String(current.get("wait_for", "")) == "wave_started":
		_complete_requirement()
	elif not current.is_empty() and not String(current.get("wait_for", "")).is_empty():
		# The player chose to start the wave over an open STATION objective:
		# that lesson is theirs to skip, and combat must not talk over itself.
		_abandon_current_lesson()
	if spawner and spawner.wave_target > 0 and wave == spawner.wave_target and not final_wave_hyped:
		final_wave_hyped = true
		if not is_done("final_wave"):
			var hype: Array[Dictionary] = [
				_entry("Duck", "Final wave. This is where legends are forged."),
				_entry("Daisy", "Or where Duck learns what indoor voice means."),
			]
			for entry in hype:
				entry["lesson"] = "final_wave"
			_enqueue(hype, true)

func _on_wave_cleared(_wave: int) -> void:
	_station_lessons_for_level()

func _on_level_completed(_level, _is_finale: bool) -> void:
	var ending: Array[Dictionary] = [
		_entry("Duck", "Station secured. I knew the train would pull through."),
		_entry("Daisy", "The player pulled through. The train followed the track."),
	]
	if level_index == 0:
		ending.append(_entry("Duck", "Same thing. Next stop, a bigger arsenal."))
		mark_done("opening")
		mark_done("car:0")
	_enqueue(ending, true)

func _on_rail_built(_cell: Vector2i, _rerouted: int) -> void:
	_rail_built_since_objective = true

func _on_unit_bitten(_unit: Node2D) -> void:
	_raise_event_lesson("biting")

func _on_unit_destroyed(_label: String) -> void:
	_raise_event_lesson("destroyed")

func _on_engine_wrecked(_convoy: Node2D) -> void:
	_raise_event_lesson("wreck")

## Battle events wait for the next STATION; STATION events show at once.
func _raise_event_lesson(lesson_id: String) -> void:
	if CampaignManager.is_challenge_active() or is_done(lesson_id) or _event_lessons_seen_this_level.has(lesson_id):
		return
	_event_lessons_seen_this_level[lesson_id] = true
	if PhaseManager.is_station() and current.is_empty():
		_begin_lesson(lesson_id, _event_lesson_lines(lesson_id))
	elif not deferred_lessons.has(lesson_id):
		deferred_lessons.append(lesson_id)

# ---------------------------------------------------------------------------
# Sequence playback
# ---------------------------------------------------------------------------

func _entry(speaker: String, text: String, wait_for := "", hint := "", highlight: Callable = Callable()) -> Dictionary:
	return {"speaker": speaker, "text": text, "wait_for": wait_for, "action_hint": hint, "highlight": highlight}

## Sequences only start during STATION unless `battle_ok` says the lines are
## meant for combat (the opening's "spiders incoming", final-wave hype, the
## level ending). Anything else raised mid-wave waits in the backlog.
func _enqueue(entries: Array[Dictionary], battle_ok: bool = false) -> void:
	if entries.is_empty():
		return
	if not battle_ok and not PhaseManager.is_station():
		station_backlog.append_array(entries)
		return
	queue.append_array(entries)
	if current.is_empty():
		_show_next()

func _show_next() -> void:
	if queue.is_empty():
		_finish_lesson(current_lesson)
		current = {}
		current_lesson = ""
		overlay.visible = false
		PhaseManager.dialogue_hold = false
		return
	var next: Dictionary = queue.pop_front()
	var next_lesson := String(next.get("lesson", ""))
	if next_lesson != current_lesson:
		_finish_lesson(current_lesson)
		current_lesson = next_lesson
	current = next
	# Several cars can unlock together. Earlier purchases can spend the money
	# or cap a train after this instruction was queued, so check again now.
	_relax_unavailable_car_objective()
	# Even requirement-bearing entries begin as conversation. The first advance
	# switches them into objective mode; the departure clock stays held until
	# the objective is done so combat cannot interrupt an unfinished lesson.
	PhaseManager.dialogue_hold = true
	overlay.show_entry(current)

func _advance() -> void:
	if current.is_empty():
		return
	var requirement := String(current.get("wait_for", ""))
	if not requirement.is_empty():
		# Speak the instruction first. Advancing retracts the characters and
		# exposes a small objective tag while the gameplay event remains armed.
		if not overlay.waiting_for_action:
			_arm_objective(requirement)
			var highlight: Callable = current.get("highlight", Callable())
			overlay.show_objective(String(current.get("action_hint", "CONTINUE THE OBJECTIVE")), highlight.call() if highlight.is_valid() else null)
		return
	_show_next()

func _arm_objective(requirement: String) -> void:
	_rail_built_since_objective = false
	if requirement.begins_with("car_placed:"):
		var tower_index := int(requirement.trim_prefix("car_placed:"))
		_car_counts_at_objective[tower_index] = _cars_of(tower_index)
	elif requirement == "gunner_placed":
		baseline_car_count = _car_count()

## The objective is done: the rest of this lesson plays on. If a wave is
## underway, any other lesson waiting behind it moves to the STATION backlog.
func _complete_requirement() -> void:
	var lesson := current_lesson
	current = {}
	overlay.visible = false
	if not PhaseManager.is_station():
		var keep: Array[Dictionary] = []
		for entry in queue:
			if String(entry.get("lesson", "")) == lesson:
				keep.append(entry)
			else:
				station_backlog.append(entry)
		queue = keep
	_show_next()

## The player started a wave over an open STATION objective. That lesson is
## theirs to skip; whatever else was queued waits for the next STATION.
func _abandon_current_lesson() -> void:
	var lesson := current_lesson
	current = {}
	overlay.visible = false
	for entry in queue:
		if String(entry.get("lesson", "")) != lesson:
			station_backlog.append(entry)
	queue = []
	_finish_lesson(lesson)
	current_lesson = ""
	PhaseManager.dialogue_hold = false

func _finish_lesson(lesson_id: String) -> void:
	if lesson_id.is_empty():
		return
	mark_done(lesson_id)
	if lesson_id == "opening":
		mark_done("car:0")

func _skip_all() -> void:
	var skipped: Dictionary = {}
	if not current_lesson.is_empty():
		skipped[current_lesson] = true
	for entry in queue:
		skipped[String(entry.get("lesson", ""))] = true
	for entry in station_backlog:
		skipped[String(entry.get("lesson", ""))] = true
	queue.clear()
	station_backlog.clear()
	current = {}
	overlay.visible = false
	PhaseManager.dialogue_hold = false
	for lesson_id in skipped:
		_finish_lesson(String(lesson_id))
	current_lesson = ""
	if tutorial_active:
		mark_done("opening")
		mark_done("car:0")
	tutorial_active = false

# ---------------------------------------------------------------------------
# Highlight targets and board queries
# ---------------------------------------------------------------------------

func _highlight_shop_button(tower_index: int) -> Variant:
	if menu == null or tower_index >= Menu.TOWER_BUTTONS.size():
		return null
	return menu.get(Menu.TOWER_BUTTONS[tower_index])

func _highlight_wave_button() -> Variant:
	if menu == null or menu.station_progress_panel == null:
		return null
	return menu.station_progress_panel.skip_button

func _highlight_first_engine() -> Variant:
	var convoys = main.get("convoys") if main else null
	if convoys == null or convoys.is_empty():
		return null
	return convoys[0]

func _highlight_first_car() -> Variant:
	var convoys = main.get("convoys") if main else null
	if convoys == null:
		return null
	for convoy in convoys:
		if is_instance_valid(convoy) and not convoy.followers.is_empty() and is_instance_valid(convoy.followers[0]):
			return convoy.followers[0]
	return null

func _car_count() -> int:
	var total := 0
	var convoys = main.get("convoys") if main else null
	if convoys == null:
		return 0
	for convoy in convoys:
		if is_instance_valid(convoy):
			total += int(convoy.car_count())
	return total

func _cars_of(tower_index: int) -> int:
	if tower_index < 0 or tower_index >= BuildManager.towers.size():
		return 0
	var tower: TowerData = BuildManager.towers[tower_index]
	var total := 0
	var convoys = main.get("convoys") if main else null
	if convoys == null:
		return 0
	for convoy in convoys:
		if not is_instance_valid(convoy):
			continue
		for car in convoy.followers:
			if is_instance_valid(car) and car.get_meta("tower_data", null) == tower:
				total += 1
	return total
