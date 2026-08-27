extends Control
class_name SpiderAssaultController
## Reverse-mode challenge controller. The player spends regenerating Web to
## deploy existing spider archetypes from four entrances around the station.

const FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")
const DialogueOverlayScript := preload("res://scripts/dialogue_overlay.gd")

const STARTING_WEB := 5.0
const MAX_WEB := 10.0
const WEB_REGEN_SECONDS := 2.4
const DURATION_SECONDS := 240.0
const SWARM_DURATION := 6.0
const SWARM_COOLDOWN := 45.0

const SPIDER_CARDS: Array[Dictionary] = [
	{"id":"generic", "name":"BASIC", "role":"RELIABLE", "cost":1},
	{"id":"baby", "name":"FAST", "role":"RUNNER", "cost":2},
	{"id":"roller", "name":"ARMOURED", "role":"BLOCKS HITS", "cost":3},
	{"id":"sturdy", "name":"HEAVY", "role":"TOUGH", "cost":5},
	{"id":"rally", "name":"SPECIAL", "role":"RALLIES", "cost":6},
]

const ENTRANCES: Array[Dictionary] = [
	{"name":"NORTH TUNNEL", "world":Vector2(-150, -425)},
	{"name":"EAST VENT", "world":Vector2(270, 30)},
	{"name":"SOUTH TUNNEL", "world":Vector2(255, 310)},
	{"name":"MAINTENANCE", "world":Vector2(-270, 60)},
]

var main: Node
var spawner: EnemySpawner
var station: Station
var convoys: Array[Node2D] = []
var web := STARTING_WEB
var time_remaining := DURATION_SECONDS
var selected_spider := 0
var spawn_cooldown := 0.0
var swarm_remaining := 0.0
var swarm_cooldown_remaining := 0.0
var active := false
var finished := false
var intro_index := 0

var web_label: Label
var timer_label: Label
var hp_label: Label
var feedback_label: Label
var swarm_button: Button
var spider_buttons: Array[Button] = []
var entrance_buttons: Array[Button] = []
var dialogue: DialogueOverlay
var victory_overlay: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 420

func configure(game: Node, enemy_spawner: EnemySpawner, target_station: Station, active_convoys: Array[Node2D]) -> void:
	main = game
	spawner = enemy_spawner
	station = target_station
	convoys = active_convoys
	# Disable the normal station-to-battle clock. Every spider in this challenge
	# must come from the player's Spider Nest rather than an automatic wave.
	PhaseManager.paused = true
	_build_ui()
	station.health_changed.connect(_on_station_health_changed)
	station.defeated.connect(_on_station_destroyed)
	_show_intro()
	call_deferred("_position_entrances")

func _process(delta: float) -> void:
	if get_tree().paused or not active or finished:
		return
	spawn_cooldown = maxf(0.0, spawn_cooldown - delta)
	time_remaining = maxf(0.0, time_remaining - delta)
	var regen_rate := (1.0 / WEB_REGEN_SECONDS) * (2.0 if swarm_remaining > 0.0 else 1.0)
	web = minf(MAX_WEB, web + regen_rate * delta)
	if swarm_remaining > 0.0:
		swarm_remaining = maxf(0.0, swarm_remaining - delta)
		if swarm_remaining <= 0.0:
			_set_assault_speed(1.0)
	else:
		swarm_cooldown_remaining = maxf(0.0, swarm_cooldown_remaining - delta)
	_update_defense_pressure()
	_refresh_status()
	if time_remaining <= 0.0:
		_fail_assault()

func _build_ui() -> void:
	var left := PanelContainer.new()
	left.name = "SpiderNest"
	left.position = Vector2(8, 7)
	left.size = Vector2(342, 706)
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	left.add_theme_stylebox_override("panel", _panel_style(Color("733622")))
	add_child(left)
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 18)
	left_margin.add_theme_constant_override("margin_top", 17)
	left_margin.add_theme_constant_override("margin_right", 18)
	left_margin.add_theme_constant_override("margin_bottom", 16)
	left.add_child(left_margin)
	var nest := VBoxContainer.new()
	nest.add_theme_constant_override("separation", 8)
	left_margin.add_child(nest)
	nest.add_child(_label("SPIDER NEST", 34, HORIZONTAL_ALIGNMENT_CENTER, Color("ffe29a")))
	web_label = _label("", 25, HORIZONTAL_ALIGNMENT_CENTER, Color("8ee7dc"))
	nest.add_child(web_label)
	for index in range(SPIDER_CARDS.size()):
		var card := _spider_card(index)
		spider_buttons.append(card)
		nest.add_child(card)
	feedback_label = _label("Pick a spider, then an entrance.", 17, HORIZONTAL_ALIGNMENT_CENTER, Color("fff0c2"))
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size.y = 45
	nest.add_child(feedback_label)
	swarm_button = Button.new()
	swarm_button.text = "🕸  SWARM"
	swarm_button.custom_minimum_size.y = 56
	swarm_button.add_theme_font_override("font", FONT)
	swarm_button.add_theme_font_size_override("font_size", 28)
	swarm_button.add_theme_stylebox_override("normal", _button_style(Color("771e42"), Color("160a0e")))
	swarm_button.add_theme_stylebox_override("hover", _button_style(Color("a62e5e"), Color("ffe17a")))
	swarm_button.pressed.connect(_activate_swarm)
	nest.add_child(swarm_button)

	var right := PanelContainer.new()
	right.name = "AssaultStatus"
	right.position = Vector2(998, 350)
	right.size = Vector2(274, 363)
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	right.add_theme_stylebox_override("panel", _panel_style(Color("5d1c19")))
	add_child(right)
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	right.add_child(right_margin)
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 11)
	right_margin.add_child(status)
	status.add_child(_label("SPIDER ASSAULT", 29, HORIZONTAL_ALIGNMENT_CENTER, Color("ffcf72")))
	status.add_child(_label("DESTROY THE STATION", 20, HORIZONTAL_ALIGNMENT_CENTER, Color("fff2d0")))
	hp_label = _label("", 22, HORIZONTAL_ALIGNMENT_CENTER, Color("ff7770"))
	status.add_child(hp_label)
	timer_label = _label("", 24, HORIZONTAL_ALIGNMENT_CENTER, Color("fff0be"))
	status.add_child(timer_label)
	var instructions := _label("Choose a spider. Choose an entrance. Time the swarm between trains.", 17, HORIZONTAL_ALIGNMENT_CENTER, Color("e9d5b3"))
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size.y = 82
	status.add_child(instructions)
	var pause := Button.new()
	pause.text = "PAUSE"
	pause.custom_minimum_size.y = 42
	pause.add_theme_font_override("font", FONT)
	pause.add_theme_font_size_override("font_size", 20)
	pause.pressed.connect(func() -> void: main.menu._toggle_pause())
	status.add_child(pause)

	for entrance in ENTRANCES:
		var marker := Button.new()
		marker.text = "🕸\n%s" % String(entrance.name)
		marker.custom_minimum_size = Vector2(122, 48)
		marker.size = Vector2(122, 48)
		marker.add_theme_font_override("font", FONT)
		marker.add_theme_font_size_override("font_size", 13)
		marker.add_theme_color_override("font_color", Color("fff0b0"))
		marker.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.08, 0.09, 0.88), Color("d94d4b")))
		marker.add_theme_stylebox_override("hover", _button_style(Color("68253a"), Color("fff080")))
		marker.pressed.connect(_deploy_at.bind(entrance))
		add_child(marker)
		entrance_buttons.append(marker)

	_build_victory_overlay()
	_refresh_status()
	_select_spider(0)

func _spider_card(index: int) -> Button:
	var card_data := SPIDER_CARDS[index]
	var profile := EnemyRoster.by_id(String(card_data.id))
	var button := Button.new()
	button.custom_minimum_size.y = 82
	button.text = "      %s. %s.  %d WEB" % [String(card_data.name), String(card_data.role), int(card_data.cost)]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_stylebox_override("normal", _button_style(Color("ead18f"), Color("16100c")))
	button.add_theme_stylebox_override("hover", _button_style(Color("ffe47f"), Color("23c9c4")))
	button.pressed.connect(_select_spider.bind(index))
	var icon := TextureRect.new()
	icon.position = Vector2(7, 8)
	icon.size = Vector2(62, 62)
	icon.texture = profile.get("walk_a")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	return button

func _position_entrances() -> void:
	var transform := get_viewport().get_canvas_transform()
	for index in range(mini(entrance_buttons.size(), ENTRANCES.size())):
		var screen_point: Vector2 = transform * Vector2(ENTRANCES[index].world)
		entrance_buttons[index].position = screen_point - entrance_buttons[index].size * 0.5

func _select_spider(index: int) -> void:
	selected_spider = clampi(index, 0, SPIDER_CARDS.size() - 1)
	for button_index in range(spider_buttons.size()):
		spider_buttons[button_index].modulate = Color("fff093") if button_index == selected_spider else Color.WHITE
	feedback_label.text = "%s selected. Pick an entrance." % String(SPIDER_CARDS[selected_spider].name)

func _deploy_at(entrance: Dictionary) -> void:
	if not active or finished or spawn_cooldown > 0.0:
		return
	var card := SPIDER_CARDS[selected_spider]
	var cost := float(card.cost)
	if web + 0.001 < cost:
		feedback_label.text = "Not enough Web."
		return
	web -= cost
	spawn_cooldown = 0.16 if swarm_remaining > 0.0 else 0.45
	var destination := station.global_position + Vector2(0, -38)
	var enemy := spawner.spawn_controlled_spider(String(card.id), Vector2(entrance.world), destination, swarm_remaining > 0.0)
	feedback_label.text = "%s released from %s." % [String(card.name), String(entrance.name)] if enemy else "That entrance is blocked."
	_refresh_status()

func _activate_swarm() -> void:
	if not active or finished or swarm_cooldown_remaining > 0.0 or swarm_remaining > 0.0:
		return
	swarm_remaining = SWARM_DURATION
	swarm_cooldown_remaining = SWARM_COOLDOWN
	_set_assault_speed(1.6)
	feedback_label.text = "SWARM. Move, move, move."

func _set_assault_speed(multiplier: float) -> void:
	for spider in get_tree().get_nodes_in_group("spiders"):
		if spider.get_meta("player_deployed", false):
			spider.set("assault_speed_multiplier", multiplier)

func _update_defense_pressure() -> void:
	var elapsed_fraction := 1.0 - time_remaining / DURATION_SECONDS
	for convoy in convoys:
		if not is_instance_valid(convoy):
			continue
		if not convoy.has_meta("assault_base_cruise"):
			convoy.set_meta("assault_base_cruise", convoy.cruise_speed)
			convoy.set_meta("assault_base_max", convoy.max_speed)
		convoy.cruise_speed = float(convoy.get_meta("assault_base_cruise")) * lerpf(0.8, 1.35, elapsed_fraction)
		convoy.max_speed = float(convoy.get_meta("assault_base_max")) * lerpf(0.8, 1.35, elapsed_fraction)

func _refresh_status() -> void:
	if web_label:
		web_label.text = "WEB  %d OF %d" % [floori(web), int(MAX_WEB)]
	if hp_label and station:
		hp_label.text = "STATION HP  %d OF %d" % [station.current_health, station.max_health]
	if timer_label:
		var seconds := ceili(time_remaining)
		timer_label.text = "TIME  %02d:%02d" % [seconds / 60, seconds % 60]
	if swarm_button:
		if swarm_remaining > 0.0:
			swarm_button.text = "SWARM  %d" % ceili(swarm_remaining)
			swarm_button.disabled = true
		elif swarm_cooldown_remaining > 0.0:
			swarm_button.text = "SWARM  %d" % ceili(swarm_cooldown_remaining)
			swarm_button.disabled = true
		else:
			swarm_button.text = "🕸  SWARM"
			swarm_button.disabled = false

func _on_station_health_changed(_current: int, _maximum: int) -> void:
	_refresh_status()

func _on_station_destroyed() -> void:
	if finished:
		return
	finished = true
	active = false
	get_tree().paused = true
	victory_overlay.visible = true

func _fail_assault() -> void:
	if finished:
		return
	finished = true
	active = false
	main.trigger_failure()

func _show_intro() -> void:
	active = false
	dialogue = DialogueOverlayScript.new()
	add_child(dialogue)
	dialogue.advance_requested.connect(_advance_intro)
	dialogue.skip_requested.connect(_finish_intro)
	dialogue.show_entry({"speaker":"Duck", "text":"Wait, we are playing as the spiders."})

func _advance_intro() -> void:
	intro_index += 1
	if intro_index == 1:
		dialogue.show_entry({"speaker":"Daisy", "text":"Apparently someone thought that was a good idea."})
	else:
		_finish_intro()

func _finish_intro() -> void:
	dialogue.visible = false
	PhaseManager.paused = true
	active = true

func _build_victory_overlay() -> void:
	victory_overlay = ColorRect.new()
	victory_overlay.name = "VictoryOverlay"
	victory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_overlay.color = Color(0.03, 0.055, 0.035, 0.9)
	victory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	victory_overlay.z_index = 850
	victory_overlay.visible = false
	victory_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(victory_overlay)
	var card := PanelContainer.new()
	card.position = Vector2(380, 150)
	card.size = Vector2(520, 420)
	card.add_theme_stylebox_override("panel", _panel_style(Color("d8bb76")))
	victory_overlay.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 35)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	box.add_child(_label("STATION OVERRUN", 48, HORIZONTAL_ALIGNMENT_CENTER, Color("7d1717")))
	box.add_child(_label("The spiders are celebrating on the railway. Duck is pretending this was the plan.", 24, HORIZONTAL_ALIGNMENT_CENTER, Color("2a180e")))
	var icon := TextureRect.new()
	icon.texture = EnemyRoster.by_id("rally").walk_a
	icon.custom_minimum_size = Vector2(0, 120)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var again := Button.new()
	again.text = "PLAY SPIDER ASSAULT AGAIN"
	again.custom_minimum_size.y = 52
	again.add_theme_font_override("font", FONT)
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(_retry)
	box.add_child(again)
	var menu_button := Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.custom_minimum_size.y = 48
	menu_button.add_theme_font_override("font", FONT)
	menu_button.add_theme_font_size_override("font_size", 22)
	menu_button.pressed.connect(_main_menu)
	box.add_child(menu_button)

func _retry() -> void:
	CampaignManager.reset_for_current_level()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _main_menu() -> void:
	CampaignManager.clear_challenge()
	PhaseManager.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _label(text: String, size: int, alignment: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("1b0d09")
	style.set_border_width_all(8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 3
	return style

func _button_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(4)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 2
	return style
