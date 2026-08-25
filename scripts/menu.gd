extends Control
class_name Menu
## HUD: battle status on the left, the selected defense's details on the
## right. configure() is called once by Main after every referenced node
## exists, since Menu has no scene-level path to its battlefield siblings.

@onready var health_label: Label = $LeftPanel/Margin/VBox/HealthLabel
@onready var currency_label: Label = $LeftPanel/Margin/VBox/CurrencyLabel
@onready var wave_label: Label = $LeftPanel/Margin/VBox/WaveLabel
@onready var spiders_label: Label = $LeftPanel/Margin/VBox/SpidersLabel
@onready var gunner_button: Button = $LeftPanel/Margin/VBox/GunnerButton
@onready var slomo_button: Button = $LeftPanel/Margin/VBox/SlomoButton
@onready var next_wave_button: Button = $LeftPanel/Margin/VBox/NextWaveButton

@onready var name_label: Label = $RightPanel/Margin/VBox/NameLabel
@onready var cost_label: Label = $RightPanel/Margin/VBox/CostLabel
@onready var summary_label: Label = $RightPanel/Margin/VBox/SummaryLabel

@export var normal_style: StyleBox
@export var selected_style: StyleBox

var spawner: EnemySpawner
var station: Station
var station_lost: bool = false

func configure(enemy_spawner: EnemySpawner, defended_station: Station) -> void:
	spawner = enemy_spawner
	station = defended_station
	station.defeated.connect(func() -> void: station_lost = true)

func _ready() -> void:
	gunner_button.pressed.connect(_select_tower.bind(0))
	slomo_button.pressed.connect(_select_tower.bind(1))
	next_wave_button.pressed.connect(_on_next_wave_pressed)
	_refresh_selection()

func _process(_delta: float) -> void:
	currency_label.text = "$ Funds  %d" % LevelManager.currency
	_style_tower_button(gunner_button, 0)
	_style_tower_button(slomo_button, 1)

	if station:
		health_label.text = "♥ Station  %d/%d" % [station.current_health, station.max_health]

	if spawner:
		wave_label.text = "Wave  %d" % spawner.current_wave
		spiders_label.text = "🕷 %d remaining" % spawner.enemies_remaining()
		if station_lost:
			next_wave_button.disabled = true
			next_wave_button.text = "STATION LOST"
		else:
			next_wave_button.disabled = not spawner.can_start_next_wave()
			next_wave_button.text = "NEXT WAVE" if spawner.can_start_next_wave() else "WAVE IN PROGRESS"

func _on_next_wave_pressed() -> void:
	if spawner:
		spawner.start_next_wave()

func _select_tower(index: int) -> void:
	BuildManager.set_selected_tower(index)
	_refresh_selection()

func _refresh_selection() -> void:
	var selected := BuildManager.get_selected_tower()
	if selected:
		name_label.text = selected.tower_name
		cost_label.text = "$%d" % selected.cost
		summary_label.text = selected.summary
	else:
		name_label.text = "None"
		cost_label.text = ""
		summary_label.text = ""

## Selection is shown as a glowing style rather than the disabled state.
## Buttons stay clickable even when unaffordable — Plot already blocks and
## explains the actual purchase, and disabling here would also block
## previewing or pre-selecting a defense while saving up for it.
func _style_tower_button(button: Button, index: int) -> void:
	if index >= BuildManager.towers.size() or not normal_style or not selected_style:
		return
	var is_selected: bool = BuildManager.selected_tower == index
	button.add_theme_stylebox_override("normal", selected_style if is_selected else normal_style)
