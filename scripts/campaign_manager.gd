extends Node
## Autoload. Owns the campaign's ordered level list, current progress, and
## the cumulative unlocked roster.
##
## Main.tscn is fully reloaded to move between levels — every scene-owned
## node (EnemySpawner's wave counter, trains, the shop) resets for free.
## This, LevelManager, and PhaseManager are the only state that survives a
## reload, so they're the only ones that need an explicit reset between
## levels — see reset_for_current_level() and advance_to_next_level().

signal level_completed(level: LevelData, is_finale: bool)

const SAVE_PATH := "user://campaign_progress.cfg"

var levels: Array[LevelData] = []
var current_level_index: int = 0
var campaign_complete: bool = false
## Transient launch intent. This guarantees that choosing New Game replays the
## opening lesson even when a browser has not flushed the deleted tutorial save
## to IndexedDB before Main begins loading.
var tutorial_requested: bool = false

var _endless_level: LevelData

func _ready() -> void:
	levels = [
		_make_level("Boiler Room", 3, 300, [0], -1),
		_make_level("Fare Collection", 4, 350, [0, 3], 3),
		_make_level("Swarm Warning", 4, 400, [0, 3, 2], 2),
		_make_level("Iron Hide", 5, 450, [0, 3, 2, 4], 4),
		_make_level("Full Load", 5, 500, [0, 3, 2, 4, 5], 5),
		_make_level("Long Haul", 6, 550, [0, 3, 2, 4, 5, 6], 6),
		_make_level("All Aboard", 8, 600, [0, 3, 2, 4, 5, 6, 1], 1),
	]
	var last: LevelData = levels[-1]
	_endless_level = _make_level("Open Rails", 0, last.starting_currency, last.unlocked_tower_indices, -1)

func _make_level(level_name: String, waves: int, currency: int, unlocked: Array[int], new_index: int) -> LevelData:
	var level := LevelData.new()
	level.level_name = level_name
	level.wave_count = waves
	level.starting_currency = currency
	level.unlocked_tower_indices = unlocked
	level.new_tower_index = new_index
	return level

func current_level() -> LevelData:
	if campaign_complete or levels.is_empty():
		return _endless_level
	return levels[mini(current_level_index, levels.size() - 1)]

func is_tower_unlocked(tower_index: int) -> bool:
	var level := current_level()
	return level != null and tower_index in level.unlocked_tower_indices

## Called by EnemySpawner when the current level's final wave clears.
## Pauses PhaseManager so the station timer can't auto-start a wave the
## just-unlocked roster hasn't been shown for yet.
func complete_current_level() -> void:
	var level := current_level()
	if level == null:
		return
	PhaseManager.paused = true
	var is_finale: bool = not campaign_complete and current_level_index == levels.size() - 1
	level_completed.emit(level, is_finale)

## Advances progress, then reloads the scene fresh for the next level (or
## the post-campaign endless state). Restart the very state a reload can't
## touch — LevelManager's wallet and PhaseManager's clock — before the new
## scene's own _ready() chain runs, so it doesn't inherit the old level's.
func advance_to_next_level() -> void:
	if not campaign_complete and current_level_index < levels.size() - 1:
		current_level_index += 1
	else:
		campaign_complete = true
	reset_for_current_level()
	save_progress()
	get_tree().reload_current_scene()

func reset_for_current_level() -> void:
	var level := current_level()
	if level == null:
		return
	LevelManager.reset_currency(level.starting_currency)
	PhaseManager.reset()

## Resets in-memory progress to level 1 and immediately persists it, so
## starting a new game properly overwrites (not just ignores) any old save.
func restart_campaign() -> void:
	current_level_index = 0
	campaign_complete = false
	tutorial_requested = true
	reset_for_current_level()
	save_progress()

## Read-once request consumed by TutorialDirector as the new Main scene opens.
func consume_tutorial_request() -> bool:
	var requested := tutorial_requested
	tutorial_requested = false
	return requested

## Writes current_level_index/campaign_complete to user:// — on the web
## export this is backed by IndexedDB, so it survives closing the tab.
func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("campaign", "current_level_index", current_level_index)
	config.set_value("campaign", "campaign_complete", campaign_complete)
	config.save(SAVE_PATH)

## True only once a save exists AND it represents real progress (past level
## 1, or the campaign finished) — a fresh save from restart_campaign() at
## level 0 shouldn't make the title screen offer to "continue" nothing.
func has_saved_progress() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	var index: int = config.get_value("campaign", "current_level_index", 0)
	var complete: bool = config.get_value("campaign", "campaign_complete", false)
	return index > 0 or complete

## Loads saved progress into memory and resets the level-scoped autoload
## state (wallet, phase clock) to match — call right before changing to
## Main.tscn, same as restart_campaign().
func continue_saved_game() -> void:
	tutorial_requested = false
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		current_level_index = config.get_value("campaign", "current_level_index", 0)
		campaign_complete = config.get_value("campaign", "campaign_complete", false)
	reset_for_current_level()
