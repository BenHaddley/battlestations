extends Control
class_name Menu
## HUD: compact unit shop and currency on the left, the STATION/BATTLE
## schedule and objectives on the right, HP rail in between. configure() is
## called once by Main after every referenced node exists, since Menu has no
## scene-level path to its battlefield siblings.

signal train_drag_started
signal train_drag_ended
signal train_drop_requested(tower_index: int, screen_position: Vector2, facing: int)
signal engine_drop_requested(screen_position: Vector2)
signal remove_requested(screen_position: Vector2)

@onready var currency_label: Label = $LeftPanel/Margin/VBox/CurrencyRow/HBox/CurrencyLabel
@onready var feedback_label: Label = $LeftPanel/Margin/VBox/FeedbackLabel
@onready var remove_button: Button = $LeftPanel/Margin/VBox/RemoveButton

@onready var gunner_button: Button = $LeftPanel/Margin/VBox/ScrollContainer/ShopList/GunnerRow
@onready var chaingunner_button: Button = $LeftPanel/Margin/VBox/ScrollContainer/ShopList/MinigunRow
@onready var ballast_button: Button = $LeftPanel/Margin/VBox/ScrollContainer/ShopList/BallastRow
@onready var passenger_button: Button = $LeftPanel/Margin/VBox/ScrollContainer/ShopList/PassengerRow
@onready var coal_cannon_button: Button = $LeftPanel/Margin/VBox/ScrollContainer/ShopList/CoalCannonRow
@onready var brake_van_button: Button = $LeftPanel/Margin/VBox/ScrollContainer/ShopList/BrakeVanRow
@onready var tender_button: Button = $LeftPanel/Margin/VBox/ScrollContainer/ShopList/TenderRow

@onready var speed_button: Button = $RightPanel/Margin/VBox/ControlsPanel/Margin/ControlsRow/SpeedButton
@onready var pause_button: Button = $RightPanel/Margin/VBox/ControlsPanel/Margin/ControlsRow/PauseButton

@onready var portrait: TextureRect = $RightPanel/Margin/VBox/PortraitPanel/Portrait

@onready var schedule_panel: PanelContainer = $RightPanel/Margin/VBox/SchedulePanel
@onready var phase_dots: Control = $RightPanel/Margin/VBox/SchedulePanel/Margin/VBox/PhaseDots
@onready var phase_label: Label = $RightPanel/Margin/VBox/SchedulePanel/Margin/VBox/PhaseLabel
@onready var phase_status: Label = $RightPanel/Margin/VBox/SchedulePanel/Margin/VBox/PhaseStatus
@onready var phase_instruction: Label = $RightPanel/Margin/VBox/SchedulePanel/Margin/VBox/PhaseInstruction
@onready var advance_button: Button = $RightPanel/Margin/VBox/SchedulePanel/Margin/VBox/AdvanceButton

@onready var hp_fill: HpGauge = $HpRail/Margin/VBox/HpFill

@onready var task_health: CheckBox = $RightPanel/Margin/VBox/TodoPanel/Margin/VBox/TaskHealth
@onready var task_no_leaks: CheckBox = $RightPanel/Margin/VBox/TodoPanel/Margin/VBox/TaskNoLeaks
@onready var task_train: CheckBox = $RightPanel/Margin/VBox/TodoPanel/Margin/VBox/TaskTrain

@export var normal_style: StyleBox
@export var selected_style: StyleBox
@export var unaffordable_style: StyleBox

const TOWER_BUTTONS := ["gunner_button", "chaingunner_button", "ballast_button", "passenger_button", "coal_cannon_button", "brake_van_button", "tender_button"]
static var ENGINE_COST: int = (preload("res://resources/game_balance.tres") as GameBalance).locomotive_cost
const ENGINE_ICON := preload("res://assets/sprites/engines/Steam Engine Black.png")

const SCHEDULE_STATION_COLOR := Color(0.32, 0.58, 0.86, 1)
const SCHEDULE_BATTLE_COLOR := Color(0.72, 0.16, 0.1, 1)

const PORTRAIT_STATION := preload("res://assets/sprites/ui/portrait/portrait_station.png")
const PORTRAIT_BATTLE := preload("res://assets/sprites/ui/portrait/portrait_battle.png")
const StationProgressPanelScene := preload("res://scenes/ui/StationProgressPanel.tscn")
const NEW_UI_TEXTURE := preload("res://assets/the_new_ui.png")
const PauseMenuScript := preload("res://scripts/pause_menu.gd")

var spawner: EnemySpawner
var station: Station
var trains: Array[Node2D] = []
var station_lost: bool = false
var dragging_tower: int = -1
var drag_facing: int = 1
var drag_preview: TextureRect
var removing_mode: bool = false

var _wave_start_health: int = -1
var _wave_start_enemy_count: int = 0
var _hovered_removable: Node2D = null
var station_progress_panel: StationProgressPanel
var speed_caption: Label
var pause_caption: Label
var pause_menu: PauseMenu
var wave_banner: Label
var _wave_banner_tween: Tween
var placement_banner: PanelContainer
var placement_banner_label: Label
var _placement_banner_tween: Tween

const HOVER_TINT := Color(1.0, 0.42, 0.34, 1.0)

func configure(enemy_spawner: EnemySpawner, defended_station: Station, active_trains: Array[Node2D]) -> void:
	spawner = enemy_spawner
	station = defended_station
	trains = active_trains
	spawner.wave_started.connect(func(wave: int) -> void:
		_wave_start_health = station.current_health if station else -1
		_wave_start_enemy_count = spawner.enemies_remaining()
		_show_wave_start_cue(wave)
	)
	station.defeated.connect(func() -> void: station_lost = true)
	PhaseManager.configure(spawner)

func _ready() -> void:
	pause_menu = PauseMenuScript.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.resumed.connect(_on_pause_menu_resumed)
	_install_new_ui_layout()
	_install_engine_shop_row()
	_install_station_progress_panel()
	_install_wave_banner()
	_install_placement_banner()
	_style_train_yard()
	for index in range(TOWER_BUTTONS.size()):
		var button: Button = get(TOWER_BUTTONS[index])
		var unlocked := CampaignManager.is_tower_unlocked(index)
		button.pressed.connect(_select_tower.bind(index))
		button.gui_input.connect(_on_tower_gui_input.bind(index))
		button.visible = true
		button.disabled = not unlocked or not CampaignManager.challenge_shop_enabled()
		if not CampaignManager.challenge_shop_enabled():
			_set_price_text(button, "FIXED")
			button.tooltip_text = "This challenge uses a fixed train."
			continue
		if unlocked:
			_set_price_text(button, "%d" % (BuildManager.towers[index].cost if index < BuildManager.towers.size() else 0))
		else:
			_set_price_text(button, "STOP %d" % CampaignManager.tower_unlock_level(index))
			button.tooltip_text = "%s. Unlocks at campaign stop %d." % [BuildManager.towers[index].tower_name, CampaignManager.tower_unlock_level(index)]
	remove_button.pressed.connect(_toggle_remove_mode)
	if not CampaignManager.challenge_train_edit_enabled():
		remove_button.disabled = true
		remove_button.text = "FIXED TRAIN"
		remove_button.tooltip_text = "This job card forbids changing the supplied train."
	speed_button.pressed.connect(_toggle_speed)
	pause_button.pressed.connect(_toggle_pause)
	station_progress_panel.skip_wait_pressed.connect(_on_advance_pressed)
	PhaseManager.phase_changed.connect(_on_phase_changed)
	_create_drag_preview()
	_on_phase_changed(PhaseManager.phase_label().to_lower())

func _install_wave_banner() -> void:
	wave_banner = Label.new()
	wave_banner.name = "WaveStartBanner"
	wave_banner.position = Vector2(430, 230)
	wave_banner.size = Vector2(420, 100)
	wave_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_banner.z_index = 500
	wave_banner.add_theme_font_size_override("font_size", 48)
	wave_banner.add_theme_color_override("font_color", Color("fff0c2"))
	wave_banner.add_theme_color_override("font_outline_color", Color("3a100c"))
	wave_banner.add_theme_constant_override("outline_size", 8)
	wave_banner.modulate.a = 0.0
	add_child(wave_banner)

func _show_wave_start_cue(wave: int) -> void:
	if wave_banner == null:
		return
	if _wave_banner_tween and _wave_banner_tween.is_valid():
		_wave_banner_tween.kill()
	wave_banner.text = "WAVE %d — DEFEND!" % wave
	wave_banner.modulate.a = 0.0
	wave_banner.scale = Vector2(0.88, 0.88)
	wave_banner.pivot_offset = wave_banner.size * 0.5
	_wave_banner_tween = create_tween()
	_wave_banner_tween.tween_property(wave_banner, "modulate:a", 1.0, 0.16)
	_wave_banner_tween.parallel().tween_property(wave_banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_wave_banner_tween.tween_interval(0.72)
	_wave_banner_tween.tween_property(wave_banner, "modulate:a", 0.0, 0.28)

func _install_placement_banner() -> void:
	# Placement feedback belongs over the playfield, not squeezed into the shop.
	feedback_label.visible = false
	feedback_label.custom_minimum_size = Vector2.ZERO
	placement_banner = PanelContainer.new()
	placement_banner.name = "PlacementBanner"
	placement_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	placement_banner.anchor_left = 0.5
	placement_banner.anchor_right = 0.5
	placement_banner.offset_left = -300.0
	placement_banner.offset_top = 18.0
	placement_banner.offset_right = 300.0
	placement_banner.offset_bottom = 64.0
	placement_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placement_banner.z_index = 510
	placement_banner.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.055, 0.045, 0.84)
	style.border_color = Color("e8c66d")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	placement_banner.add_theme_stylebox_override("panel", style)
	placement_banner_label = Label.new()
	placement_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placement_banner_label.add_theme_font_size_override("font_size", 19)
	placement_banner_label.add_theme_color_override("font_color", Color("fff3ca"))
	placement_banner_label.add_theme_color_override("font_outline_color", Color("1d0b08"))
	placement_banner_label.add_theme_constant_override("outline_size", 5)
	placement_banner.add_child(placement_banner_label)
	add_child(placement_banner)

## The supplied UI is a transparent illustrated frame. It sits behind live
## Controls, while the old opaque web panels are cleared so the authored
## cutouts remain visible and every button/label stays interactive.
func _install_new_ui_layout() -> void:
	var illustrated_frame := TextureRect.new()
	illustrated_frame.name = "NewIllustratedUi"
	illustrated_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	illustrated_frame.texture = NEW_UI_TEXTURE
	illustrated_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustrated_frame.stretch_mode = TextureRect.STRETCH_SCALE
	illustrated_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illustrated_frame.z_index = -90
	add_child(illustrated_frame)
	move_child(illustrated_frame, 0)

	var transparent := StyleBoxEmpty.new()
	var left_panel: PanelContainer = $LeftPanel
	var hp_panel: PanelContainer = $HpRail
	var right_panel: PanelContainer = $RightPanel
	left_panel.add_theme_stylebox_override("panel", transparent)
	hp_panel.add_theme_stylebox_override("panel", transparent)
	right_panel.add_theme_stylebox_override("panel", transparent)
	left_panel.position = Vector2(8.0, 7.0)
	left_panel.size = Vector2(342.0, 706.0)
	hp_panel.position = Vector2(932.0, 8.0)
	hp_panel.size = Vector2(66.0, 704.0)
	right_panel.position = Vector2(998.0, 7.0)
	right_panel.size = Vector2(274.0, 706.0)

	$BoardFrame.visible = false
	$LeftPanel/Frame.visible = false
	$HpRail/Frame.visible = false
	$RightPanel/Frame.visible = false
	$RightPanel/Margin/VBox/ControlsPanel/Frame.visible = false
	$RightPanel/Margin/VBox/PortraitPanel/Frame.visible = false
	$RightPanel/Margin/VBox/TodoPanel/Frame.visible = false

	var controls_panel: PanelContainer = $RightPanel/Margin/VBox/ControlsPanel
	var portrait_panel: PanelContainer = $RightPanel/Margin/VBox/PortraitPanel
	var todo_panel: PanelContainer = $RightPanel/Margin/VBox/TodoPanel
	var currency_panel: PanelContainer = $LeftPanel/Margin/VBox/CurrencyRow
	controls_panel.add_theme_stylebox_override("panel", transparent)
	portrait_panel.add_theme_stylebox_override("panel", transparent)
	todo_panel.add_theme_stylebox_override("panel", transparent)
	currency_panel.add_theme_stylebox_override("panel", transparent)
	controls_panel.custom_minimum_size.y = 64.0
	portrait_panel.custom_minimum_size.y = 184.0
	todo_panel.custom_minimum_size.y = 224.0

	# The authored lightning and pause symbols remain visible underneath these
	# invisible hit targets, so they behave as controls without doubled artwork.
	speed_button.flat = true
	pause_button.flat = true
	$RightPanel/Margin/VBox/ControlsPanel/Margin/ControlsRow/SpeedButton/Icon.visible = false
	$RightPanel/Margin/VBox/ControlsPanel/Margin/ControlsRow/PauseButton/Icon.visible = false
	$LeftPanel/Margin/VBox/CurrencyRow/HBox/Icon.visible = false
	# Invisible placeholders retain the exact space occupied by artwork already
	# present in the UI texture, preventing live content from colliding with it.
	$HpRail/Margin/VBox/HpLabel.modulate.a = 0.0
	$HpRail/Margin/VBox/HeartIcon.modulate.a = 0.0
	$RightPanel/Margin/VBox/TodoPanel/Margin/VBox/TodoHeader.modulate.a = 0.0
	$RightPanel/Margin/VBox/TodoPanel/Margin/VBox/TodoHeader.custom_minimum_size.y = 55.0
	_install_compact_hp_gauge(hp_panel)
	speed_caption = _add_control_caption(speed_button, "2X SPEED")
	pause_caption = _add_control_caption(pause_button, "PAUSE")
	feedback_label.add_theme_color_override("font_color", Color("ffe6a7"))
	feedback_label.add_theme_color_override("font_outline_color", Color("35140f"))
	feedback_label.add_theme_constant_override("outline_size", 3)
	feedback_label.custom_minimum_size.y = 24.0

func _install_compact_hp_gauge(hp_panel: PanelContainer) -> void:
	# The authored UI contains the casing, label and heart. Cover only its baked
	# sample fill, then place a shorter live gauge inside the middle of the slot.
	$HpRail/Margin.visible = false
	var overlay_host := Control.new()
	overlay_host.name = "HpOverlayHost"
	overlay_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_panel.add_child(overlay_host)
	var baked_fill_mask := ColorRect.new()
	baked_fill_mask.name = "BakedHpFillMask"
	baked_fill_mask.position = Vector2(20.0, 58.0)
	baked_fill_mask.size = Vector2(27.0, 568.0)
	baked_fill_mask.color = Color("25130f")
	baked_fill_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_host.add_child(baked_fill_mask)

	hp_fill = HpGauge.new()
	hp_fill.name = "CompactHpFill"
	hp_fill.position = Vector2(14.0, 148.0)
	hp_fill.size = Vector2(39.0, 390.0)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_host.add_child(hp_fill)

func _add_control_caption(button: Button, caption_text: String) -> Label:
	var caption := Label.new()
	caption.name = "Caption"
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -20.0
	caption.offset_bottom = -3.0
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = caption_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf"))
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("fff0b0"))
	caption.add_theme_color_override("font_outline_color", Color("2b100e"))
	caption.add_theme_constant_override("outline_size", 3)
	button.add_child(caption)
	return caption

func _install_station_progress_panel() -> void:
	$RightPanel/Margin/VBox/SchedulePanel/Margin.visible = false
	$RightPanel/Margin/VBox/SchedulePanel/Frame.visible = false
	schedule_panel.custom_minimum_size.y = 148.0
	schedule_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	station_progress_panel = StationProgressPanelScene.instantiate()
	station_progress_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	schedule_panel.add_child(station_progress_panel)

## The infowiki roster is presented as a compact tray of physical train pieces.
## Keeping this styling here also means adding a documented TowerData entry only
## requires adding its button path above; it cannot silently inherit the old,
## oversized web-shop treatment.
func _style_train_yard() -> void:
	var shop_list: VBoxContainer = $LeftPanel/Margin/VBox/ScrollContainer/ShopList
	shop_list.add_theme_constant_override("separation", 3)
	remove_button.custom_minimum_size.y = 38
	remove_button.add_theme_font_size_override("font_size", 20)

	for index in range(TOWER_BUTTONS.size()):
		var button: Button = get(TOWER_BUTTONS[index])
		button.custom_minimum_size.y = 65
		button.add_theme_stylebox_override("normal", _train_yard_row_style(index, false))
		button.add_theme_stylebox_override("hover", _train_yard_row_style(index, true))

		var icon := button.find_child("Icon", true, false) as TextureRect
		if icon:
			# A Container owns its children's transforms, so rotating the original
			# TextureRect gets silently reset. Draw a non-container-owned copy over
			# the card instead, which gives the mockup its horizontal, oversized cars.
			icon.visible = false
			var tray_icon := TextureRect.new()
			tray_icon.name = "TrayIcon"
			tray_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tray_icon.texture = icon.texture
			tray_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tray_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tray_icon.position = Vector2(9, -13)
			tray_icon.size = Vector2(91, 91)
			tray_icon.pivot_offset = tray_icon.size * 0.5
			tray_icon.rotation = (-PI / 2.0) + deg_to_rad([-2.0, 1.5, -1.0, 2.0, -1.5, 1.0, -2.0][index])
			button.add_child(tray_icon)

		var name_label := button.find_child("NameLabel", true, false) as Label
		if name_label:
			name_label.visible = false

		var price_pill := button.find_child("PricePill", true, false) as PanelContainer
		if price_pill:
			price_pill.custom_minimum_size = Vector2(82, 52)
			price_pill.add_theme_stylebox_override("panel", _train_yard_price_style(index))

		var price_label := button.find_child("PriceLabel", true, false) as Label
		if price_label:
			price_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9))
			price_label.add_theme_color_override("font_outline_color", Color(0.08, 0.055, 0.035))
			price_label.add_theme_constant_override("outline_size", 3)
			price_label.add_theme_font_size_override("font_size", 22)

func _train_yard_row_style(index: int, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var paper_colors := [
		Color("f3dfaa"), Color("ead39b"), Color("f1dda7"),
		Color("e8ce91"), Color("f0d9a0"), Color("e5ca8e"), Color("efd8a1")
	]
	style.bg_color = paper_colors[index % paper_colors.size()].lightened(0.08 if hovered else 0.0)
	style.border_color = Color("24160d")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 2 + (index % 2)
	style.corner_radius_top_right = 5 - (index % 2)
	style.corner_radius_bottom_left = 5 - (index % 2)
	style.corner_radius_bottom_right = 2 + (index % 2)
	style.content_margin_left = 7
	style.content_margin_right = 5
	return style

func _train_yard_price_style(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("72a77e") if index % 2 == 0 else Color("659b72")
	style.border_color = Color("24160d")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	return style

func _set_price_text(button: Button, value: String) -> void:
	var label: Label = button.find_child("PriceLabel", true, false)
	if label:
		label.text = value

## Unhandled rather than plain _input — a click the REMOVE button itself
## already consumed (e.g. pressing it again to cancel) must not also count
## as a "click a car" attempt.
func _input(event: InputEvent) -> void:
	if dragging_tower == -1:
		return
	if event is InputEventMouseMotion:
		_position_drag_preview(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# The two fixed-direction gun cars can be flipped without releasing the
		# left-button drag. The preview pivots in place, so placement stays stable.
		if dragging_tower == 0 or dragging_tower == 1:
			drag_facing *= -1
			drag_preview.scale.x = float(drag_facing)
			show_placement_feedback("Facing %s — right-click again to flip." % ("left" if drag_facing < 0 else "right"), true)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging_tower == -2:
			engine_drop_requested.emit(event.position)
		else:
			train_drop_requested.emit(dragging_tower, event.position, drag_facing)
		dragging_tower = -1
		drag_preview.visible = false
		drag_preview.scale = Vector2.ONE
		train_drag_ended.emit()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if removing_mode:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			remove_requested.emit(event.position)
			_exit_remove_mode()
		return

func _process(_delta: float) -> void:
	currency_label.text = "Δ%d" % LevelManager.currency
	for index in range(TOWER_BUTTONS.size()):
		_style_tower_button(get(TOWER_BUTTONS[index]), index)

	if station:
		_refresh_hp_rail()

	if removing_mode:
		_refresh_remove_hover()

	if spawner:
		var live_status := PhaseManager.status_text()
		var is_battle: bool = PhaseManager.phase == PhaseManager.Phase.BATTLE
		var total_waves := spawner.wave_target if spawner.wave_target > 0 else 7
		var journey_progress := float(spawner.current_wave) / float(total_waves)
		if is_battle:
			var wave_fraction := 0.0
			if _wave_start_enemy_count > 0:
				wave_fraction = 1.0 - float(spawner.enemies_remaining()) / float(_wave_start_enemy_count)
			journey_progress = (float(spawner.current_wave - 1) + wave_fraction) / float(total_waves)
		# One node is the departure point, followed by one checkpoint per wave.
		station_progress_panel.set_progress_fraction(journey_progress, total_waves + 1)
		station_progress_panel.set_phase("BATTLE" if is_battle else "STATION", live_status, "DEFEND • FIRE • SURVIVE" if is_battle else "PREPARE • BUY • COUPLE")
		if station_lost:
			station_progress_panel.set_button_state("STATION LOST", true)
		elif PhaseManager.paused:
			station_progress_panel.set_button_state("LEVEL COMPLETE", true)
		elif is_battle:
			station_progress_panel.set_button_state("IN PROGRESS", true)
		else:
			station_progress_panel.set_button_state("SKIP WAIT", false)
		_refresh_objectives()

func _refresh_hp_rail() -> void:
	var fraction: float = float(station.current_health) / float(maxi(station.max_health, 1))
	hp_fill.set_fraction(fraction)

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
	if station_progress_panel:
		station_progress_panel.set_phase("BATTLE" if is_battle else "STATION", PhaseManager.status_text(), "DEFEND • FIRE • SURVIVE" if is_battle else "PREPARE • BUY • COUPLE")
	portrait.texture = PORTRAIT_BATTLE if is_battle else PORTRAIT_STATION

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
	if spawner and not PhaseManager.paused and spawner.can_start_next_wave():
		spawner.start_next_wave()

## Arms remove mode rather than removing on this same click — the button
## press and the follow-up battlefield click are two separate input events,
## but without the deferred arm below, the click that presses this button
## would immediately also count as the "click a car" click.
func _toggle_remove_mode() -> void:
	if removing_mode:
		_exit_remove_mode()
	else:
		remove_button.text = "CLICK A CAR"
		remove_button.modulate = Color(1.3, 0.55, 0.5, 1)
		call_deferred("_arm_remove_mode")

func _arm_remove_mode() -> void:
	removing_mode = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func _exit_remove_mode() -> void:
	removing_mode = false
	remove_button.text = "REMOVE UNIT"
	remove_button.modulate = Color.WHITE
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_set_hovered_removable(null)

## Tints whichever attached car is nearest the cursor (within its train's own
## attachment radius) so the player can see exactly what a click will remove
## before committing to it.
func _refresh_remove_hover() -> void:
	var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
	var nearest: Node2D = null
	var nearest_distance := INF
	for train in trains:
		if not is_instance_valid(train):
			continue
		var radius: float = train.get("attachment_radius")
		var followers: Array = train.get("followers")
		if followers == null:
			continue
		for car in followers:
			if not is_instance_valid(car):
				continue
			var distance: float = car.global_position.distance_to(world_position)
			if distance <= radius and distance < nearest_distance:
				nearest_distance = distance
				nearest = car
	_set_hovered_removable(nearest)

func _set_hovered_removable(car: Node2D) -> void:
	if _hovered_removable == car:
		return
	if is_instance_valid(_hovered_removable):
		_hovered_removable.modulate = Color.WHITE
	_hovered_removable = car
	if is_instance_valid(_hovered_removable):
		_hovered_removable.modulate = HOVER_TINT

func _toggle_speed() -> void:
	AudioFX.play_cue(&"ui")
	Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else 1.0
	speed_button.tooltip_text = "Return to normal speed" if Engine.time_scale > 1.5 else "Run at double speed"
	speed_button.modulate = Color(1.0, 0.82, 0.38) if Engine.time_scale > 1.5 else Color.WHITE
	if speed_caption:
		speed_caption.text = "1X NORMAL" if Engine.time_scale > 1.5 else "2X SPEED"

func _toggle_pause() -> void:
	AudioFX.play_cue(&"ui")
	if pause_menu.visible:
		pause_menu.close()
	else:
		pause_menu.open()
	pause_button.tooltip_text = "Resume" if pause_menu.visible else "Pause"
	pause_button.modulate = Color(1.0, 0.82, 0.38) if pause_menu.visible else Color.WHITE
	if pause_caption:
		pause_caption.text = "RESUME" if pause_menu.visible else "PAUSE"

func _on_pause_menu_resumed() -> void:
	pause_button.tooltip_text = "Pause"
	pause_button.modulate = Color.WHITE
	if pause_caption:
		pause_caption.text = "PAUSE"

func _select_tower(index: int) -> void:
	BuildManager.set_selected_tower(index)

func _on_tower_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		BuildManager.set_selected_tower(index)
		dragging_tower = index
		var tower := BuildManager.get_selected_tower()
		drag_preview.texture = tower.icon if tower else null
		drag_facing = 1
		drag_preview.scale = Vector2.ONE
		drag_preview.visible = true
		_position_drag_preview(event.global_position)
		train_drag_started.emit()

func _install_engine_shop_row() -> void:
	var shop_list: VBoxContainer = $LeftPanel/Margin/VBox/ScrollContainer/ShopList
	var button := Button.new()
	button.name = "EngineRow"
	button.text = "LOCOMOTIVE                         Δ%d" % ENGINE_COST
	button.tooltip_text = "Drag onto an empty stretch of railway to start an independent train."
	button.custom_minimum_size.y = 65
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _train_yard_row_style(7, false))
	button.add_theme_stylebox_override("hover", _train_yard_row_style(7, true))
	button.gui_input.connect(_on_engine_gui_input)
	shop_list.add_child(button)
	shop_list.move_child(button, 0)

func _on_engine_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging_tower = -2
		drag_facing = 1
		drag_preview.texture = ENGINE_ICON
		drag_preview.scale = Vector2.ONE
		drag_preview.visible = true
		_position_drag_preview(event.global_position)
		train_drag_started.emit()

func _create_drag_preview() -> void:
	drag_preview = TextureRect.new()
	drag_preview.custom_minimum_size = Vector2(72, 72)
	drag_preview.size = Vector2(72, 72)
	drag_preview.pivot_offset = drag_preview.size * 0.5
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
	if placement_banner == null or placement_banner_label == null:
		return
	placement_banner_label.text = message
	var style := placement_banner.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color("77d496") if success else Color("e46f59")
	if _placement_banner_tween and _placement_banner_tween.is_valid():
		_placement_banner_tween.kill()
	placement_banner.modulate.a = 0.0
	_placement_banner_tween = create_tween()
	_placement_banner_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_placement_banner_tween.tween_property(placement_banner, "modulate:a", 1.0, 0.12)
	_placement_banner_tween.tween_interval(2.2)
	_placement_banner_tween.tween_property(placement_banner, "modulate:a", 0.0, 0.28)

## Selection is shown as a glowing style rather than the disabled state.
## Buttons stay clickable even when unaffordable — Plot already blocks and
## explains the actual purchase, and disabling here would also block
## previewing or pre-selecting a defense while saving up for it.
func _style_tower_button(button: Button, index: int) -> void:
	if index >= BuildManager.towers.size():
		return
	var unlocked := CampaignManager.is_tower_unlocked(index)
	var is_selected: bool = BuildManager.selected_tower == index
	var affordable := LevelManager.currency >= BuildManager.towers[index].cost
	var style_state := "locked" if not unlocked else ("selected" if is_selected else ("ready" if affordable else "poor"))
	if String(button.get_meta("train_yard_style_state", "")) == style_state:
		return
	button.set_meta("train_yard_style_state", style_state)
	if not unlocked:
		button.disabled = true
		# Keep the supplied turret drawing readable. The muted card and STOP label
		# communicate locking without blacking out the art itself.
		button.modulate = Color(0.82, 0.82, 0.82, 1.0)
		button.add_theme_stylebox_override("disabled", _locked_train_yard_style(index))
		return
	var style := _train_yard_row_style(index, is_selected)
	if is_selected:
		style.border_color = Color("19cfd0")
		style.set_border_width_all(4)
	elif not affordable:
		style.bg_color = style.bg_color.darkened(0.22)
	button.add_theme_stylebox_override("normal", style)
	button.modulate = Color(1, 1, 1, 1) if (is_selected or affordable) else Color(1, 1, 1, 0.72)

func _locked_train_yard_style(index: int) -> StyleBoxFlat:
	var style := _train_yard_row_style(index, false)
	style.bg_color = Color("9a765d")
	style.border_color = Color("352018")
	return style
