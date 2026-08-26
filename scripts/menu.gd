extends Control
class_name Menu
## HUD: compact unit shop and currency on the left, the STATION/BATTLE
## schedule and objectives on the right, HP rail in between. configure() is
## called once by Main after every referenced node exists, since Menu has no
## scene-level path to its battlefield siblings.

signal train_drag_started
signal train_drag_ended
signal train_drop_requested(tower_index: int, screen_position: Vector2)
signal remove_requested(screen_position: Vector2)

@onready var currency_label: Label = $LeftPanel/Margin/VBox/CurrencyRow/HBox/CurrencyLabel
@onready var feedback_label: Label = $LeftPanel/Margin/VBox/FeedbackLabel
@onready var remove_button: Button = $LeftPanel/Margin/VBox/RemoveButton

@onready var gunner_button: Button = $LeftPanel/Margin/VBox/ShopList/GunnerRow
@onready var slomo_button: Button = $LeftPanel/Margin/VBox/ShopList/SlomoRow
@onready var minigun_button: Button = $LeftPanel/Margin/VBox/ShopList/MinigunRow
@onready var ballast_button: Button = $LeftPanel/Margin/VBox/ShopList/BallastRow
@onready var passenger_button: Button = $LeftPanel/Margin/VBox/ShopList/PassengerRow
@onready var coal_cannon_button: Button = $LeftPanel/Margin/VBox/ShopList/CoalCannonRow
@onready var brake_van_button: Button = $LeftPanel/Margin/VBox/ShopList/BrakeVanRow
@onready var chaingun_button: Button = $LeftPanel/Margin/VBox/ShopList/ChaingunRow
@onready var tender_button: Button = $LeftPanel/Margin/VBox/ShopList/TenderRow

@onready var speed_button: Button = $RightPanel/Margin/VBox/ControlsRow/SpeedButton
@onready var pause_button: Button = $RightPanel/Margin/VBox/ControlsRow/PauseButton

@onready var schedule_panel: PanelContainer = $RightPanel/Margin/VBox/SchedulePanel
@onready var phase_dots: Control = $RightPanel/Margin/VBox/SchedulePanel/Margin/VBox/PhaseDots
@onready var phase_label: Label = $RightPanel/Margin/VBox/SchedulePanel/Margin/VBox/PhaseLabel
@onready var phase_status: Label = $RightPanel/Margin/VBox/SchedulePanel/Margin/VBox/PhaseStatus
@onready var advance_button: Button = $RightPanel/Margin/VBox/SchedulePanel/Margin/VBox/AdvanceButton

@onready var hp_fill: TextureRect = $HpRail/Margin/VBox/HpFill

@onready var task_health: CheckBox = $RightPanel/Margin/VBox/TodoPanel/Margin/VBox/TaskHealth
@onready var task_no_leaks: CheckBox = $RightPanel/Margin/VBox/TodoPanel/Margin/VBox/TaskNoLeaks
@onready var task_train: CheckBox = $RightPanel/Margin/VBox/TodoPanel/Margin/VBox/TaskTrain

@export var normal_style: StyleBox
@export var selected_style: StyleBox

const TOWER_BUTTONS := ["gunner_button", "slomo_button", "minigun_button", "ballast_button", "passenger_button", "coal_cannon_button", "brake_van_button", "chaingun_button", "tender_button"]

const SCHEDULE_STATION_COLOR := Color(0.6, 0.71, 0.78, 1)
const SCHEDULE_BATTLE_COLOR := Color(0.78, 0.36, 0.24, 1)

const HP_SHEET := preload("res://assets/sprites/ui/hp/hp_variants.png")
const HP_FRAME_WIDTH := 39.2
const HP_FRAME_HEIGHT := 140.0

var spawner: EnemySpawner
var station: Station
var trains: Array[Node2D] = []
var station_lost: bool = false
var dragging_tower: int = -1
var drag_preview: TextureRect
var removing_mode: bool = false

var _wave_start_health: int = -1
var _hp_frame_100: Texture2D
var _hp_frame_75: Texture2D
var _hp_frame_50: Texture2D
var _hp_frame_25: Texture2D
var _hp_frame_0: Texture2D

func configure(enemy_spawner: EnemySpawner, defended_station: Station, active_trains: Array[Node2D]) -> void:
	spawner = enemy_spawner
	station = defended_station
	trains = active_trains
	spawner.wave_started.connect(func(_wave: int) -> void:
		_wave_start_health = station.current_health if station else -1
	)
	station.defeated.connect(func() -> void: station_lost = true)
	PhaseManager.configure(spawner)

func _ready() -> void:
	_hp_frame_100 = _hp_atlas(0)
	_hp_frame_75 = _hp_atlas(1)
	_hp_frame_50 = _hp_atlas(2)
	_hp_frame_25 = _hp_atlas(3)
	_hp_frame_0 = _hp_atlas(4)
	hp_fill.texture = _hp_frame_100
	for index in range(TOWER_BUTTONS.size()):
		var button: Button = get(TOWER_BUTTONS[index])
		button.pressed.connect(_select_tower.bind(index))
		button.gui_input.connect(_on_tower_gui_input.bind(index))
		_set_price_text(button, BuildManager.towers[index].cost if index < BuildManager.towers.size() else 0)
	remove_button.pressed.connect(_toggle_remove_mode)
	speed_button.pressed.connect(_toggle_speed)
	pause_button.pressed.connect(_toggle_pause)
	advance_button.pressed.connect(_on_advance_pressed)
	PhaseManager.phase_changed.connect(_on_phase_changed)
	_create_drag_preview()
	_on_phase_changed(PhaseManager.phase_label().to_lower())

func _hp_atlas(frame_index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = HP_SHEET
	atlas.region = Rect2(frame_index * HP_FRAME_WIDTH, 0, HP_FRAME_WIDTH, HP_FRAME_HEIGHT)
	return atlas

func _set_price_text(button: Button, cost: int) -> void:
	var label: Label = button.find_child("PriceLabel", true, false)
	if label:
		label.text = "%d" % cost

func _input(event: InputEvent) -> void:
	if removing_mode:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			remove_requested.emit(event.position)
			removing_mode = false
			remove_button.text = "X     REMOVE     X"
		return
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
	for index in range(TOWER_BUTTONS.size()):
		_style_tower_button(get(TOWER_BUTTONS[index]), index)

	if station:
		_refresh_hp_rail()

	if spawner:
		phase_status.text = PhaseManager.status_text()
		var is_battle: bool = PhaseManager.phase == PhaseManager.Phase.BATTLE
		var display_index: int = spawner.current_wave if is_battle else spawner.current_wave + 1
		phase_dots.refresh(display_index, is_battle)
		if station_lost:
			advance_button.disabled = true
			advance_button.text = "STATION LOST"
		elif is_battle:
			advance_button.disabled = true
			advance_button.text = "IN PROGRESS"
		else:
			advance_button.disabled = false
			advance_button.text = "SKIP WAIT"
		_refresh_objectives()

func _refresh_hp_rail() -> void:
	var fraction: float = float(station.current_health) / float(maxi(station.max_health, 1))
	if fraction >= 0.9:
		hp_fill.texture = _hp_frame_100
	elif fraction >= 0.6:
		hp_fill.texture = _hp_frame_75
	elif fraction >= 0.35:
		hp_fill.texture = _hp_frame_50
	elif fraction > 0.0:
		hp_fill.texture = _hp_frame_25
	else:
		hp_fill.texture = _hp_frame_0

func _refresh_objectives() -> void:
	task_health.button_pressed = station and station.current_health >= station.max_health * 0.5
	task_no_leaks.button_pressed = station and _wave_start_health >= 0 and station.current_health >= _wave_start_health
	var best_car_count := 0
	for train in trains:
		if is_instance_valid(train):
			best_car_count = maxi(best_car_count, train.car_count())
	task_train.button_pressed = best_car_count >= 3

func _on_phase_changed(phase_name: String) -> void:
	var is_battle: bool = phase_name == "battle"
	phase_label.text = "BATTLE" if is_battle else "STATION"
	schedule_panel.add_theme_stylebox_override("panel", _schedule_style(is_battle))

func _schedule_style(is_battle: bool) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = SCHEDULE_BATTLE_COLOR if is_battle else SCHEDULE_STATION_COLOR
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.08, 0.06, 0.04, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _on_advance_pressed() -> void:
	if spawner and spawner.can_start_next_wave():
		spawner.start_next_wave()

## Arms remove mode rather than removing on this same click — the button
## press and the follow-up battlefield click are two separate input events,
## but without the deferred arm below, the click that presses this button
## would immediately also count as the "click a car" click.
func _toggle_remove_mode() -> void:
	if removing_mode:
		removing_mode = false
		remove_button.text = "X     REMOVE     X"
	else:
		remove_button.text = "X  CLICK A CAR  X"
		call_deferred("_arm_remove_mode")

func _arm_remove_mode() -> void:
	removing_mode = true

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

func _on_tower_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		BuildManager.set_selected_tower(index)
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
	feedback_label.text = message
	feedback_label.modulate = Color(0.1, 0.45, 0.2) if success else Color(0.55, 0.12, 0.08)

## Selection is shown as a glowing style rather than the disabled state.
## Buttons stay clickable even when unaffordable — Plot already blocks and
## explains the actual purchase, and disabling here would also block
## previewing or pre-selecting a defense while saving up for it.
func _style_tower_button(button: Button, index: int) -> void:
	if index >= BuildManager.towers.size() or not normal_style or not selected_style:
		return
	var is_selected: bool = BuildManager.selected_tower == index
	button.add_theme_stylebox_override("normal", selected_style if is_selected else normal_style)
