extends Node
## Autoload. STATION/BATTLE phase clock. STATION is the build/rest window
## between waves; BATTLE is an active wave. STATION always ends by starting
## the next wave — either its departure timer running out, or the player
## forcing it early via the START WAVE button.

signal phase_changed(phase_name: String)

enum Phase { STATION, BATTLE }

@export var station_duration: float = 45.0

var phase: Phase = Phase.STATION
var phase_timer: float = station_duration
var rail_building_enabled: bool = true
## Set by CampaignManager while the level-complete overlay is up (and by
## Spider Assault for its whole run), so the station clock can never start a
## wave the player has not been shown the newly unlocked roster for.
var paused: bool = false
## Held by Duck and Daisy while a lesson is on screen or a station-phase
## objective is still open. Unlike `paused`, the player may still start the
## wave by hand; only the automatic departure countdown waits.
var dialogue_hold: bool = false
var build_hold: bool = false

var _spawner: EnemySpawner

func _ready() -> void:
	var balance: GameBalance = load("res://resources/game_balance.tres")
	if balance:
		station_duration = balance.station_phase_duration
		phase_timer = station_duration

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
	dialogue_hold = false
	build_hold = false
	_spawner = null

func _process(delta: float) -> void:
	if not clock_running():
		return
	phase_timer = maxf(0.0, phase_timer - delta)
	if phase_timer <= 0.0 and _spawner.can_start_next_wave():
		_spawner.start_next_wave()

func clock_running() -> bool:
	return not paused and not build_hold and not dialogue_hold and phase == Phase.STATION and is_instance_valid(_spawner)

## True whenever the player is allowed to start the next wave by hand: the
## station window is open, no overlay owns the clock, and the spawner is idle.
func can_start_wave() -> bool:
	return not paused and not build_hold and phase == Phase.STATION and is_instance_valid(_spawner) and _spawner.can_start_next_wave()

## Starts the next wave from a player action. Returns false when nothing
## happened, so a double-click or a stale button can never queue two waves.
func request_wave_start() -> bool:
	if not can_start_wave():
		return false
	_spawner.start_next_wave()
	return true

func _on_wave_started(_wave_number: int) -> void:
	phase = Phase.BATTLE
	rail_building_enabled = false
	phase_changed.emit("battle")

func _on_wave_cleared(_wave_number: int) -> void:
	phase = Phase.STATION
	phase_timer = station_duration
	rail_building_enabled = true
	phase_changed.emit("station")

func is_station() -> bool:
	return phase == Phase.STATION

func status_text() -> String:
	if not is_instance_valid(_spawner):
		return ""
	if phase == Phase.BATTLE:
		return "%d SPIDERS LEFT" % _spawner.enemies_remaining()
	if dialogue_hold or build_hold:
		return "DEPARTURE HELD"
	var seconds: int = int(ceil(phase_timer))
	return "DEPARTURE %02d:%02d" % [seconds / 60, seconds % 60]

func phase_label() -> String:
	return "BATTLE" if phase == Phase.BATTLE else "STATION"
