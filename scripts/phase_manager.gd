extends Node
## Autoload. STATION/BATTLE phase clock. STATION is the build/rest window
## between waves; BATTLE is an active wave. STATION always ends by starting
## the next wave — either its departure timer running out, or the player
## forcing it early via the existing NEXT WAVE button.

signal phase_changed(phase_name: String)

enum Phase { STATION, BATTLE }

@export var station_duration: float = 45.0

var phase: Phase = Phase.STATION
var phase_timer: float = station_duration
var rail_building_enabled: bool = true
## Set by CampaignManager while the level-complete overlay is up, so the
## station clock can't auto-start a wave the player hasn't seen the newly
## unlocked roster for yet. Also checked by Menu's SKIP WAIT handler.
var paused: bool = false

var _spawner: EnemySpawner

func configure(spawner: EnemySpawner) -> void:
	_spawner = spawner
	_spawner.wave_started.connect(_on_wave_started)
	_spawner.wave_cleared.connect(_on_wave_cleared)

## Restores a clean STATION state. Scene reload resets everything scene-owned
## for free, but this autoload's state survives — call this before the new
## scene's _ready() chain runs (see CampaignManager.reset_for_current_level).
func reset() -> void:
	phase = Phase.STATION
	phase_timer = station_duration
	rail_building_enabled = true
	paused = false

func _process(delta: float) -> void:
	if paused or phase != Phase.STATION or _spawner == null:
		return
	phase_timer = maxf(0.0, phase_timer - delta)
	if phase_timer <= 0.0 and _spawner.can_start_next_wave():
		_spawner.start_next_wave()

func _on_wave_started(_wave_number: int) -> void:
	phase = Phase.BATTLE
	rail_building_enabled = false
	phase_changed.emit("battle")

func _on_wave_cleared(_wave_number: int) -> void:
	phase = Phase.STATION
	phase_timer = station_duration
	rail_building_enabled = true
	phase_changed.emit("station")

func status_text() -> String:
	if _spawner == null:
		return ""
	if phase == Phase.BATTLE:
		return "%d SPIDERS LEFT" % _spawner.enemies_remaining()
	var seconds: int = int(ceil(phase_timer))
	return "DEPARTURE %02d:%02d" % [seconds / 60, seconds % 60]

func phase_label() -> String:
	return "BATTLE" if phase == Phase.BATTLE else "STATION"
