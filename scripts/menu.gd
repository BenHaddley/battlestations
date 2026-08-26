extends Control
class_name Menu
## HUD: battle status on the left, the selected defense's details on the
## right. configure() is called once by Main after every referenced node
## exists, since Menu has no scene-level path to its battlefield siblings.

signal train_drag_started
signal train_drag_ended
signal train_drop_requested(tower_index: int, screen_position: Vector2)

@onready var health_label: Label = $LeftPanel/Margin/VBox/HealthLabel
@onready var currency_label: Label = $LeftPanel/Margin/VBox/CurrencyLabel
@onready var wave_label: Label = $LeftPanel/Margin/VBox/WaveLabel
@onready var spiders_label: Label = $LeftPanel/Margin/VBox/SpidersLabel
@onready var train_label: Label = $LeftPanel/Margin/VBox/TrainLabel
@onready var gunner_button: Button = $LeftPanel/Margin/VBox/GunnerButton
@onready var slomo_button: Button = $LeftPanel/Margin/VBox/SlomoButton
@onready var next_wave_button: Button = $LeftPanel/Margin/VBox/NextWaveButton
@onready var speed_button: Button = $RightPanel/Margin/VBox/TransportControls/SpeedButton
@onready var pause_button: Button = $RightPanel/Margin/VBox/TransportControls/PauseButton
@onready var station_bar: ProgressBar = $StationBar
@onready var station_bar_label: Label = $StationBar/Label

@onready var name_label: Label = $RightPanel/Margin/VBox/NameLabel
@onready var cost_label: Label = $RightPanel/Margin/VBox/CostLabel
@onready var summary_label: Label = $RightPanel/Margin/VBox/SummaryLabel
@onready var car_preview: TextureRect = $RightPanel/Margin/VBox/CarPreview

@export var normal_style: StyleBox
@export var selected_style: StyleBox

var spawner: EnemySpawner
var station: Station
var convoy: Node2D
var station_lost: bool = false
var dragging_tower: int = -1
var drag_preview: TextureRect

func configure(enemy_spawner: EnemySpawner, defended_station: Station, active_convoy: Node2D) -> void:
	spawner = enemy_spawner
	station = defended_station
	convoy = active_convoy
	station.defeated.connect(func() -> void: station_lost = true)

func _ready() -> void:
	gunner_button.pressed.connect(_select_tower.bind(0))
	slomo_button.pressed.connect(_select_tower.bind(1))
	gunner_button.gui_input.connect(_on_tower_gui_input.bind(0))
	slomo_button.gui_input.connect(_on_tower_gui_input.bind(1))
	next_wave_button.pressed.connect(_on_next_wave_pressed)
	speed_button.pressed.connect(_toggle_speed)
	pause_button.pressed.connect(_toggle_pause)
	_create_drag_preview()
	_refresh_selection()

func _input(event: InputEvent) -> void:
	if dragging_tower < 0:
		return
	if event is InputEventMouseMotion:
		_position_drag_preview(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		train_drop_requested.emit(dragging_tower, event.position)
		dragging_tower = -1
		drag_preview.visible = false
		train_drag_ended.emit()

func _process(_delta: float) -> void:
	currency_label.text = "%d" % LevelManager.currency
	_style_tower_button(gunner_button, 0)
	_style_tower_button(slomo_button, 1)

	if station:
		health_label.text = "♥ Station  %d/%d" % [station.current_health, station.max_health]
		station_bar.max_value = station.max_health
		station_bar.value = station.current_health
		station_bar_label.text = "%d / %d" % [station.current_health, station.max_health]

	if spawner:
		wave_label.text = "Wave  %d" % spawner.current_wave
		spiders_label.text = "🕷 %d remaining" % spawner.enemies_remaining()
		if station_lost:
			next_wave_button.disabled = true
			next_wave_button.text = "STATION LOST"
		else:
			next_wave_button.disabled = not spawner.can_start_next_wave()
			next_wave_button.text = "NEXT WAVE" if spawner.can_start_next_wave() else "WAVE IN PROGRESS"
	if convoy and convoy.has_method("car_count"):
		train_label.text = "TRAIN  1 engine + %d cars" % convoy.car_count()

func _on_next_wave_pressed() -> void:
	if spawner:
		spawner.start_next_wave()

func _toggle_speed() -> void:
	Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else 1.0
	speed_button.tooltip_text = "Return to normal speed" if Engine.time_scale > 1.5 else "Run at double speed"
	speed_button.modulate = Color(1.0, 0.82, 0.38) if Engine.time_scale > 1.5 else Color.WHITE

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.tooltip_text = "Resume" if get_tree().paused else "Pause"
	pause_button.modulate = Color(1.0, 0.82, 0.38) if get_tree().paused else Color.WHITE

func _select_tower(index: int) -> void:
	BuildManager.set_selected_tower(index)
	_refresh_selection()

func _on_tower_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		BuildManager.set_selected_tower(index)
		_refresh_selection()
		dragging_tower = index
		var tower := BuildManager.get_selected_tower()
		drag_preview.texture = tower.icon if tower else null
		drag_preview.visible = true
		_position_drag_preview(event.global_position)
		train_drag_started.emit()

func _create_drag_preview() -> void:
	drag_preview = TextureRect.new()
	drag_preview.custom_minimum_size = Vector2(72, 72)
	drag_preview.size = Vector2(72, 72)
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.modulate = Color(1, 1, 1, 0.82)
	drag_preview.z_index = 200
	drag_preview.visible = false
	add_child(drag_preview)

func _position_drag_preview(screen_position: Vector2) -> void:
	drag_preview.position = screen_position - drag_preview.size * 0.5

func show_placement_feedback(message: String, success: bool) -> void:
	var hint: Label = $RightPanel/Margin/VBox/HintLabel
	hint.text = message
	hint.modulate = Color(0.65, 1.0, 0.7) if success else Color(1.0, 0.58, 0.45)

func _refresh_selection() -> void:
	var selected := BuildManager.get_selected_tower()
	if selected:
		name_label.text = selected.tower_name
		cost_label.text = "$%d" % selected.cost
		summary_label.text = selected.summary
		car_preview.texture = selected.icon
	else:
		name_label.text = "None"
		cost_label.text = ""
		summary_label.text = ""
		car_preview.texture = null

## Selection is shown as a glowing style rather than the disabled state.
## Buttons stay clickable even when unaffordable — Plot already blocks and
## explains the actual purchase, and disabling here would also block
## previewing or pre-selecting a defense while saving up for it.
func _style_tower_button(button: Button, index: int) -> void:
	if index >= BuildManager.towers.size() or not normal_style or not selected_style:
		return
	var is_selected: bool = BuildManager.selected_tower == index
	button.add_theme_stylebox_override("normal", selected_style if is_selected else normal_style)
