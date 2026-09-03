extends Node

const DEFINITIONS: Array[Dictionary] = [
	{"id":"first_stop", "title":"FIRST STOP", "description":"Complete your first mission.", "condition":"level_complete"},
	{"id":"careful_spending", "title":"TRAVEL LIGHT", "description":"Complete a mission without buying anything.", "condition":"no_shopping"},
	{"id":"job_done", "title":"ODD JOB", "description":"Complete any challenge job card.", "condition":"challenge_complete"},
	{"id":"ten_waves", "title":"LONG HAUL", "description":"Survive ten waves across your career.", "condition":"waves_10"},
]

var unlocked_ids: Array[String] = []
var waves_survived := 0
var bought_this_run := false

func _ready() -> void:
	load_progress()
	GameEvents.wave_completed.connect(_on_wave_completed)
	GameEvents.purchase_made.connect(func() -> void: bought_this_run = true)
	GameEvents.level_completed_detail.connect(_on_level_completed)

func begin_run() -> void:
	bought_this_run = false

func _on_wave_completed(_wave: int) -> void:
	waves_survived += 1
	if waves_survived >= 10:
		unlock("ten_waves")
	save_progress()

func _on_level_completed(is_challenge: bool) -> void:
	unlock("first_stop")
	if not bought_this_run:
		unlock("careful_spending")
	if is_challenge:
		unlock("job_done")

func unlock(achievement_id: String) -> void:
	if achievement_id in unlocked_ids:
		return
	unlocked_ids.append(achievement_id)
	save_progress()

func load_progress() -> void:
	unlocked_ids.clear()
	waves_survived = 0
	var config := ConfigFile.new()
	if config.load(ProfileManager.profile_path("achievements.cfg")) == OK:
		waves_survived = int(config.get_value("progress", "waves_survived", 0))
		for value in config.get_value("progress", "unlocked_ids", []):
			unlocked_ids.append(String(value))

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "waves_survived", waves_survived)
	config.set_value("progress", "unlocked_ids", unlocked_ids)
	config.save(ProfileManager.profile_path("achievements.cfg"))
