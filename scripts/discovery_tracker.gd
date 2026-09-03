extends Node

var discovered_ids: Array[String] = []

func _ready() -> void:
	load_discoveries()

func discover(content_id: String) -> void:
	if content_id.is_empty() or content_id in discovered_ids:
		return
	discovered_ids.append(content_id)
	save_discoveries()

func is_discovered(content_id: String) -> bool:
	return content_id in discovered_ids

func load_discoveries() -> void:
	discovered_ids.clear()
	var config := ConfigFile.new()
	if config.load(ProfileManager.profile_path("discoveries.cfg")) == OK:
		for value in config.get_value("almanac", "ids", []):
			discovered_ids.append(String(value))

func save_discoveries() -> void:
	var config := ConfigFile.new()
	config.set_value("almanac", "ids", discovered_ids)
	config.save(ProfileManager.profile_path("discoveries.cfg"))
