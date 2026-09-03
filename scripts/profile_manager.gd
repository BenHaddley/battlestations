extends Node
## Three lightweight save slots. Feature-specific systems ask for profile_path()
## so campaign, discoveries, achievements, and tutorial state stay isolated.

const ACTIVE_PATH := "user://active_profile.cfg"
const SLOT_COUNT := 3
var active_profile := 1

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(ACTIVE_PATH) == OK:
		active_profile = clampi(int(config.get_value("profiles", "active", 1)), 1, SLOT_COUNT)
	_ensure_profile_dir(active_profile)
	_migrate_legacy_profile_one()

func profile_path(file_name: String, slot: int = active_profile) -> String:
	return "user://profile_%d/%s" % [clampi(slot, 1, SLOT_COUNT), file_name]

func select_profile(slot: int) -> void:
	active_profile = clampi(slot, 1, SLOT_COUNT)
	_ensure_profile_dir(active_profile)
	var config := ConfigFile.new()
	config.set_value("profiles", "active", active_profile)
	config.save(ACTIVE_PATH)

func profile_name(slot: int) -> String:
	var config := ConfigFile.new()
	if config.load(profile_path("profile.cfg", slot)) == OK:
		return String(config.get_value("profile", "name", "Profile %d" % slot))
	return "Profile %d" % slot

func rename_profile(slot: int, new_name: String) -> void:
	_ensure_profile_dir(slot)
	var config := ConfigFile.new()
	config.set_value("profile", "name", new_name.strip_edges().left(24) if not new_name.strip_edges().is_empty() else "Profile %d" % slot)
	config.save(profile_path("profile.cfg", slot))

func delete_profile(slot: int) -> void:
	var dir_path := ProjectSettings.globalize_path("user://profile_%d" % clampi(slot, 1, SLOT_COUNT))
	if DirAccess.dir_exists_absolute(dir_path):
		_remove_directory_contents(dir_path)
	_ensure_profile_dir(slot)

func progress_summary(slot: int) -> String:
	var config := ConfigFile.new()
	if config.load(profile_path("campaign_progress.cfg", slot)) != OK:
		return "EMPTY"
	var complete := bool(config.get_value("campaign", "campaign_complete", false))
	var index := int(config.get_value("campaign", "current_level_index", 0))
	return "CAMPAIGN COMPLETE" if complete else "MISSION %d" % (index + 1)

func _ensure_profile_dir(slot: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://profile_%d" % clampi(slot, 1, SLOT_COUNT)))

func _remove_directory_contents(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	for child_name in dir.get_directories():
		_remove_directory_contents(path.path_join(child_name))
		dir.remove(child_name)

func _migrate_legacy_profile_one() -> void:
	# Preserve saves made before profile slots existed. Copy only into an empty
	# slot-one destination, leaving both the old save and newer slot data intact.
	if DisplayServer.get_name() == "headless":
		return
	var slot_path := ProjectSettings.globalize_path("user://profile_1")
	if not DirAccess.dir_exists_absolute(slot_path):
		return
	var legacy_files := {
		"user://campaign_progress.cfg": "campaign_progress.cfg",
		"user://battle_stations_tutorial.cfg": "tutorial.cfg",
		"user://battle_stations_settings.cfg": "settings.cfg",
	}
	for source in legacy_files:
		var destination := profile_path(String(legacy_files[source]), 1)
		if FileAccess.file_exists(source) and not FileAccess.file_exists(destination):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))
