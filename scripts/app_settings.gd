extends Node

var music_percent := 80.0
var sfx_percent := 80.0
var default_game_speed := 1.0

func _ready() -> void:
	_ensure_buses()
	load_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(ProfileManager.profile_path("settings.cfg")) == OK:
		var legacy_volume := float(config.get_value("audio", "master_volume", 80.0))
		music_percent = float(config.get_value("audio", "music_percent", legacy_volume))
		sfx_percent = float(config.get_value("audio", "sfx_percent", legacy_volume))
		default_game_speed = float(config.get_value("game", "default_speed", 1.0))
	apply()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_percent", music_percent)
	config.set_value("audio", "sfx_percent", sfx_percent)
	config.set_value("game", "default_speed", default_game_speed)
	config.save(ProfileManager.profile_path("settings.cfg"))
	apply()

func apply() -> void:
	_set_bus("Music", music_percent)
	_set_bus("SFX", sfx_percent)

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _set_bus(bus_name: String, percent: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clampf(percent, 0.0, 100.0) / 100.0, 0.0001)))
