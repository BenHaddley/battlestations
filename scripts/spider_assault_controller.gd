extends Control
class_name SpiderAssaultController
## Reverse-mode challenge controller. The player spends regenerating Web to
## deploy existing spider archetypes from five entrances along the board roof.

const FONT := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")
const DialogueOverlayScript := preload("res://scripts/dialogue_overlay.gd")

class WebOrb extends Control:
	var filled := false
	var gaining := false

	func _init() -> void:
		custom_minimum_size = Vector2(17, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(is_filled: bool, is_gaining: bool = false) -> void:
		filled = is_filled
		gaining = is_gaining
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.38
		if gaining:
			draw_circle(center, radius + 3.0, Color(0.72, 0.31, 0.9, 0.25))
		draw_circle(center, radius, Color("782b91") if filled else Color("514952"))
		draw_arc(center, radius, 0.0, TAU, 20, Color("24102b"), 2.0, true)
		draw_line(center + Vector2(-radius * 0.7, 0), center + Vector2(radius * 0.7, 0), Color(0.9, 0.72, 0.96, 0.65), 1.0)
		draw_line(center + Vector2(0, -radius * 0.7), center + Vector2(0, radius * 0.7), Color(0.9, 0.72, 0.96, 0.65), 1.0)

const STARTING_WEB := 5.0
const MAX_WEB := 10.0
const WEB_REGEN_SECONDS := 2.4
const DURATION_SECONDS := 240.0
const SWARM_DURATION := 6.0
const SWARM_COOLDOWN := 45.0

const SPIDER_CARDS: Array[Dictionary] = [
	{"id":"generic", "name":"BASIC SPIDER", "role":"CHEAP ATTACKER", "description":"A reliable body for building a swarm.", "cost":1},
	{"id":"baby", "name":"FAST SPIDER", "role":"QUICK PRESSURE", "description":"Quick and agile. Great for rushing gaps.", "cost":2},
	{"id":"roller", "name":"TANK SPIDER", "role":"ABSORBS FIRE", "description":"Armoured and steady under defensive fire.", "cost":3},
	{"id":"rally", "name":"WEB SPITTER", "role":"SUPPORT", "description":"Rallies nearby spiders through dangerous lanes.", "cost":4},
	{"id":"sturdy", "name":"HEAVY SPIDER", "role":"BREAKTHROUGH", "description":"Slow, tough, and built for the final push.", "cost":5},
]

const ENTRANCES: Array[Dictionary] = [
	{"name":"TOP LEFT", "world":Vector2(-250, -425)},
	{"name":"CENTER LEFT", "world":Vector2(-125, -425)},
	{"name":"TOP CENTER", "world":Vector2(0, -425)},
	{"name":"CENTER RIGHT", "world":Vector2(125, -425)},
	{"name":"TOP RIGHT", "world":Vector2(250, -425)},
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
var hp_segments: Array[ColorRect] = []
var web_orbs: Array[WebOrb] = []
var selected_name_label: Label
var selected_detail_label: Label
var selected_cost_label: Label
var web_popup: Label
var previous_whole_web := floori(STARTING_WEB)
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
	_hide_normal_hud()
	_build_ui()
	station.health_changed.connect(_on_station_health_changed)
	station.defeated.connect(_on_station_destroyed)
	_show_intro()
	call_deferred("_position_entrances")

func _hide_normal_hud() -> void:
	# Normal play uses `the_new_ui.png` as a full-screen illustrated overlay on
	# top of the shared `the_new_map.png` world. Spider Assault supplies its own
	# faction panels, so hide both the live normal controls and that baked UI
	# overlay; the clean authored map remains visible underneath.
	for path in ["NewIllustratedUi", "LeftPanel", "HpRail", "RightPanel"]:
		var normal_panel: CanvasItem = main.menu.get_node_or_null(path) as CanvasItem
		if normal_panel:
			normal_panel.visible = false

func _process(delta: float) -> void:
	if get_tree().paused or not active or finished:
		return
	spawn_cooldown = maxf(0.0, spawn_cooldown - delta)
	time_remaining = maxf(0.0, time_remaining - delta)
	var regen_rate := (1.0 / WEB_REGEN_SECONDS) * (2.0 if swarm_remaining > 0.0 else 1.0)
	web = minf(MAX_WEB, web + regen_rate * delta)
	var whole_web := floori(web)
	if whole_web > previous_whole_web and web_popup:
		_show_web_popup()
	previous_whole_web = whole_web
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
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 8
	left.offset_top = 8
	left.offset_right = 342
	left.offset_bottom = -8
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	left.add_theme_stylebox_override("panel", _panel_style(Color("32133f"), Color("120917"), 7))
	add_child(left)
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 12)
	left_margin.add_theme_constant_override("margin_top", 17)
	left_margin.add_theme_constant_override("margin_right", 12)
	left_margin.add_theme_constant_override("margin_bottom", 16)
	left.add_child(left_margin)
	var nest := VBoxContainer.new()
	nest.add_theme_constant_override("separation", 6)
	left_margin.add_child(nest)
	var nest_header := _label("// SPIDER NEST //", 25, HORIZONTAL_ALIGNMENT_CENTER, Color("fff0c5"))
	nest_header.custom_minimum_size.y = 48
	nest.add_child(nest_header)
	for index in range(SPIDER_CARDS.size()):
		var card := _spider_card(index)
		spider_buttons.append(card)
		nest.add_child(card)
	feedback_label = _label("Pick a spider. Then pick a roof entrance.", 14, HORIZONTAL_ALIGNMENT_CENTER, Color("fff0c2"))
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size.y = 45
	nest.add_child(feedback_label)

	var right := PanelContainer.new()
	right.name = "AssaultStatus"
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -248
	right.offset_top = 8
	right.offset_right = -8
	right.offset_bottom = -8
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	right.add_theme_stylebox_override("panel", _panel_style(Color("ead7a4"), Color("291035"), 7))
	add_child(right)
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	right.add_child(right_margin)
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 8)
	right_margin.add_child(status)
	var assault_header := PanelContainer.new()
	assault_header.custom_minimum_size.y = 60
	assault_header.add_theme_stylebox_override("panel", _button_style(Color("4a1b58"), Color("120917")))
	assault_header.add_child(_label("SPIDER ASSAULT", 21, HORIZONTAL_ALIGNMENT_CENTER, Color("fff0c5")))
	status.add_child(assault_header)
	status.add_child(_label("OBJECTIVE", 16, HORIZONTAL_ALIGNMENT_CENTER, Color("563248")))
	status.add_child(_label("DESTROY THE STATION.", 17, HORIZONTAL_ALIGNMENT_CENTER, Color("7e1420")))
	status.add_child(_divider())
	hp_label = _label("STATION HP", 19, HORIZONTAL_ALIGNMENT_CENTER, Color("4b1920"))
	status.add_child(hp_label)
	var hp_row := HBoxContainer.new()
	hp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hp_row.add_theme_constant_override("separation", 3)
	status.add_child(hp_row)
	for segment_index in range(10):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(16, 24)
		hp_row.add_child(segment)
		hp_segments.append(segment)
	status.add_child(_label("WEB", 19, HORIZONTAL_ALIGNMENT_CENTER, Color("3e174c")))
	var web_row := HBoxContainer.new()
	web_row.alignment = BoxContainer.ALIGNMENT_CENTER
	web_row.add_theme_constant_override("separation", 2)
	status.add_child(web_row)
	for orb_index in range(int(MAX_WEB)):
		var orb := WebOrb.new()
		web_row.add_child(orb)
		web_orbs.append(orb)
	web_label = _label("", 18, HORIZONTAL_ALIGNMENT_CENTER, Color("3e174c"))
	status.add_child(web_label)
	web_popup = _label("+1 WEB", 18, HORIZONTAL_ALIGNMENT_CENTER, Color("8e36ad"))
	web_popup.modulate.a = 0.0
	status.add_child(web_popup)
	status.add_child(_divider())
	status.add_child(_label("TIME REMAINING", 17, HORIZONTAL_ALIGNMENT_CENTER, Color("563248")))
	timer_label = _label("", 30, HORIZONTAL_ALIGNMENT_CENTER, Color("291035"))
	status.add_child(timer_label)
	status.add_child(_divider())
	swarm_button = Button.new()
	swarm_button.text = "SWARM.\nREADY."
	swarm_button.custom_minimum_size = Vector2(0, 112)
	swarm_button.add_theme_font_override("font", FONT)
	swarm_button.add_theme_font_size_override("font_size", 27)
	swarm_button.add_theme_color_override("font_color", Color("fff0c5"))
	swarm_button.add_theme_color_override("font_hover_color", Color("fff7dc"))
	swarm_button.add_theme_color_override("font_disabled_color", Color("e8d6e9"))
	swarm_button.add_theme_stylebox_override("normal", _round_button_style(Color("70258a"), Color("1b0922")))
	swarm_button.add_theme_stylebox_override("hover", _round_button_style(Color("9b42b5"), Color("fff0a0")))
	swarm_button.add_theme_stylebox_override("disabled", _round_button_style(Color("4b3b50"), Color("211825")))
	swarm_button.pressed.connect(_activate_swarm)
	status.add_child(swarm_button)
	var pause := Button.new()
	pause.text = "PAUSE"
	pause.custom_minimum_size.y = 36
	pause.add_theme_font_override("font", FONT)
	pause.add_theme_font_size_override("font_size", 20)
	pause.add_theme_color_override("font_color", Color("2b172c"))
	pause.add_theme_color_override("font_hover_color", Color("6f2783"))
	pause.add_theme_stylebox_override("normal", _button_style(Color("d9c89d"), Color("3b2240")))
	pause.add_theme_stylebox_override("hover", _button_style(Color("f5e6bd"), Color("7f3196")))
	pause.pressed.connect(func() -> void: main.menu._toggle_pause())
	status.add_child(pause)

	for entrance in ENTRANCES:
		var marker := Button.new()
		marker.text = "\\ /\n%s" % String(entrance.name)
		marker.tooltip_text = "Spiders enter here."
		marker.custom_minimum_size = Vector2(100, 55)
		marker.size = Vector2(100, 55)
		marker.add_theme_font_override("font", FONT)
		marker.add_theme_font_size_override("font_size", 12)
		marker.add_theme_color_override("font_color", Color("fff0b0"))
		marker.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.035, 0.09, 0.94), Color("42244d")))
		marker.add_theme_stylebox_override("hover", _button_style(Color("6f2686"), Color("d890ef")))
		marker.add_theme_stylebox_override("disabled", _button_style(Color("3b2428"), Color("a62b35")))
		marker.pressed.connect(_deploy_at.bind(entrance))
		add_child(marker)
		entrance_buttons.append(marker)

	_build_selected_strip()

	_build_victory_overlay()
	_refresh_status()
	_select_spider(0)

func _spider_card(index: int) -> Button:
	var card_data := SPIDER_CARDS[index]
	var profile := EnemyRoster.by_id(String(card_data.id))
	var button := Button.new()
	button.custom_minimum_size.y = 82
	button.text = ""
	button.tooltip_text = "%s\nCost. %d Web.\n%s" % [String(card_data.name), int(card_data.cost), String(card_data.description)]
	button.add_theme_font_override("font", FONT)
	button.add_theme_stylebox_override("normal", _button_style(Color("f1dfb1"), Color("3a2240")))
	button.add_theme_stylebox_override("hover", _button_style(Color("fff0c4"), Color("9d45b3")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("b9aa9a"), Color("6e525b")))
	button.pressed.connect(_select_spider.bind(index))
	button.mouse_entered.connect(_hover_card.bind(button, true))
	button.mouse_exited.connect(_hover_card.bind(button, false))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 7
	row.offset_top = 7
	row.offset_right = -8
	row.offset_bottom = -7
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	button.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(58, 58)
	icon.texture = profile.get("walk_a")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override("separation", -2)
	row.add_child(copy)
	var name_label := _label(String(card_data.name), 17, HORIZONTAL_ALIGNMENT_LEFT, Color("2b1723"))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(name_label)
	var role_label := _label(String(card_data.role), 13, HORIZONTAL_ALIGNMENT_LEFT, Color("624656"))
	role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(role_label)
	var cost_label := _label("%d\nWEB" % int(card_data.cost), 15, HORIZONTAL_ALIGNMENT_CENTER, Color("632b76"))
	cost_label.custom_minimum_size.x = 44
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cost_label)
	return button

func _position_entrances() -> void:
	var transform := get_viewport().get_canvas_transform()
	for index in range(mini(entrance_buttons.size(), ENTRANCES.size())):
		var screen_point: Vector2 = transform * Vector2(ENTRANCES[index].world)
		entrance_buttons[index].position = Vector2(screen_point.x - entrance_buttons[index].size.x * 0.5, 62.0)

func _build_selected_strip() -> void:
	var strip := PanelContainer.new()
	strip.name = "SelectedSpiderStrip"
	strip.anchor_left = 0.255
	strip.anchor_right = 0.735
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_left = 8
	strip.offset_right = -8
	strip.offset_top = -62
	strip.offset_bottom = -8
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", _panel_style(Color(0.94, 0.86, 0.69, 0.96), Color("35143e"), 4))
	add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	strip.add_child(row)
	selected_name_label = _label("", 19, HORIZONTAL_ALIGNMENT_LEFT, Color("3b1745"))
	selected_name_label.custom_minimum_size.x = 145
	row.add_child(selected_name_label)
	selected_detail_label = _label("", 14, HORIZONTAL_ALIGNMENT_LEFT, Color("3a2a31"))
	selected_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(selected_detail_label)
	selected_cost_label = _label("", 18, HORIZONTAL_ALIGNMENT_CENTER, Color("6f2783"))
	selected_cost_label.custom_minimum_size.x = 72
	row.add_child(selected_cost_label)

func _hover_card(button: Button, hovering: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * (1.018 if hovering else 1.0), 0.08)

func _show_web_popup() -> void:
	web_popup.modulate.a = 1.0
	web_popup.position.y = 2.0
	var tween := web_popup.create_tween().set_parallel(true)
	tween.tween_property(web_popup, "modulate:a", 0.0, 0.65)
	tween.tween_property(web_popup, "position:y", -7.0, 0.65)

func _select_spider(index: int) -> void:
	selected_spider = clampi(index, 0, SPIDER_CARDS.size() - 1)
	for button_index in range(spider_buttons.size()):
		spider_buttons[button_index].modulate = Color("d9a8f2") if button_index == selected_spider else Color.WHITE
	var selected := SPIDER_CARDS[selected_spider]
	selected_name_label.text = String(selected.name)
	selected_detail_label.text = String(selected.description)
	selected_cost_label.text = "%d WEB" % int(selected.cost)
	feedback_label.text = "%s selected. Pick a glowing roof entrance." % String(selected.name)
	_refresh_status()

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
		web_label.text = "%d / %d" % [floori(web), int(MAX_WEB)]
	for orb_index in range(web_orbs.size()):
		web_orbs[orb_index].set_state(orb_index < floori(web), orb_index == floori(web) and web < MAX_WEB)
	if hp_label and station:
		hp_label.text = "STATION HP  %d OF %d" % [station.current_health, station.max_health]
		var hp_fraction := float(station.current_health) / maxf(float(station.max_health), 1.0)
		var lit_segments := ceili(hp_fraction * hp_segments.size())
		for segment_index in range(hp_segments.size()):
			hp_segments[segment_index].color = Color("bd2636") if segment_index < lit_segments else Color("372d31")
	if timer_label:
		var seconds := ceili(time_remaining)
		timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
		timer_label.add_theme_color_override("font_color", Color("b51625") if seconds <= 30 else Color("c26920") if seconds <= 60 else Color("291035"))
	var selected_cost := float(SPIDER_CARDS[selected_spider].cost)
	var affordable := web + 0.001 >= selected_cost
	for button_index in range(spider_buttons.size()):
		var card_affordable := web + 0.001 >= float(SPIDER_CARDS[button_index].cost)
		spider_buttons[button_index].self_modulate = Color.WHITE if card_affordable else Color(0.62, 0.58, 0.6, 1.0)
	for entrance_index in range(entrance_buttons.size()):
		var entrance_button := entrance_buttons[entrance_index]
		entrance_button.disabled = not active or finished or not affordable or spawn_cooldown > 0.0
		entrance_button.text = ("\\ /\n%s" if affordable else "X\n%s") % String(ENTRANCES[entrance_index].name)
		if active and affordable and spawn_cooldown <= 0.0:
			var pulse := 1.0 + 0.018 * (sin(Time.get_ticks_msec() / 180.0 + entrance_index) + 1.0)
			entrance_button.scale = Vector2.ONE * pulse
		else:
			entrance_button.scale = Vector2.ONE
	if swarm_button:
		if swarm_remaining > 0.0:
			swarm_button.text = "SWARM.\n%d" % ceili(swarm_remaining)
			swarm_button.disabled = true
		elif swarm_cooldown_remaining > 0.0:
			swarm_button.text = "COOLDOWN.\n00:%02d" % ceili(swarm_cooldown_remaining)
			swarm_button.disabled = true
		else:
			swarm_button.text = "SWARM.\nREADY."
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
	dialogue.show_entry({"speaker":"Duck", "text":"Wait, the spiders are only coming from the roof this time."})

func _advance_intro() -> void:
	intro_index += 1
	if intro_index == 1:
		dialogue.show_entry({"speaker":"Daisy", "text":"Pick a spider, then send it through one of the roof nests."})
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

func _divider() -> HSeparator:
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 5)
	divider.add_theme_color_override("separator", Color("563248"))
	return divider

func _panel_style(color: Color, border := Color("1b0d09"), width := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
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

func _round_button_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := _button_style(color, border)
	style.set_corner_radius_all(46)
	style.set_border_width_all(6)
	return style
