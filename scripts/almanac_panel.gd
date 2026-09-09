extends Control
class_name AlmanacPanel

signal closed
const TabIcon := preload("res://scripts/almanac_tab_icon.gd")
const Preview := preload("res://scripts/almanac_unit_preview.gd")
const FRAME := preload("res://assets/ui/almanac/frame.png")
const HEADING := preload("res://assets/fonts/DkCoolCrayon.ttf")
const BODY := preload("res://assets/fonts/ArchitectsDaughter-Regular.ttf")
const CATEGORIES := ["ENEMIES", "TRAIN CARS", "DEFENSES", "TRACKS"]
const INK := Color("281d12")
const MUTED := Color("6c6049")

var entries: Array[Dictionary] = []
var active_category := 0
var tab_buttons: Array[Button] = []
var tab_icons: Array[Control] = []
var tabs: GridContainer
var grid: GridContainer
var scroll: ScrollContainer
var counter: Label
var profile_label: Label
var detail: PanelContainer
var detail_box: VBoxContainer
var card_buttons: Array[Button] = []
var page: Control
var content: VBoxContainer
var back_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.025, 0.015, 0.93)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	page = Control.new()
	add_child(page)
	var background := TextureRect.new()
	background.texture = FRAME
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	page.add_child(content)
	var top := HBoxContainer.new()
	content.add_child(top)
	profile_label = _label("", 15, MUTED)
	profile_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(profile_label)
	back_button = _button("×  CLOSE", false)
	back_button.pressed.connect(close)
	top.add_child(back_button)
	var title := _label("ALMANAC", 54)
	title.add_theme_font_override("font", HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := _label("Units reveal their entries after appearing in a run.", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	tabs = GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 5)
	tabs.add_theme_constant_override("v_separation", 5)
	content.add_child(tabs)
	for index in range(CATEGORIES.size()):
		var button := _button(CATEGORIES[index], true)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 46
		button.pressed.connect(select_category.bind(index))
		tabs.add_child(button)
		tab_buttons.append(button)
		var icon := TabIcon.new()
		icon.category = index
		icon.position = Vector2(12, 8)
		icon.size = Vector2(30, 30)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		tab_icons.append(icon)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	content.add_child(scroll)
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 17
	bar.add_theme_stylebox_override("scroll", _style(Color("3b2a18"), Color("19120c")))
	bar.add_theme_stylebox_override("grabber", _style(Color("d9a33e"), INK))
	bar.add_theme_stylebox_override("grabber_highlight", _style(Color("ffce60"), INK))
	bar.add_theme_stylebox_override("grabber_pressed", _style(Color("f7bd46"), INK))
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	var note := _label("KNOW YOUR ENEMIES. BUILD A STRONGER TOMORROW.", 13, MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(note)
	counter = _label("", 17)
	footer.add_child(counter)
	_build_detail()
	resized.connect(_layout)
	_layout()
	visible = false

func open() -> void:
	DiscoveryTracker.load_discoveries()
	entries = _catalog()
	profile_label.text = ProfileManager.profile_name(ProfileManager.active_profile).to_upper()
	visible = true
	detail.hide()
	select_category(0)
	tab_buttons[0].grab_focus()

func close() -> void:
	visible = false
	detail.hide()
	closed.emit()

func select_category(index: int) -> void:
	active_category = clampi(index, 0, CATEGORIES.size() - 1)
	detail.hide()
	for i in range(tab_buttons.size()):
		tab_buttons[i].button_pressed = i == active_category
		tab_icons[i].color = INK if i == active_category else Color("b7ab91")
		tab_icons[i].queue_redraw()
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	card_buttons.clear()
	var found := 0
	var total := 0
	for entry in entries:
		if int(entry.category) != active_category:
			continue
		total += 1
		var seen := DiscoveryTracker.is_discovered(entry.id)
		if seen:
			found += 1
		_add_card(entry, seen)
	counter.text = "%d / %d DISCOVERED" % [found, total]
	scroll.scroll_vertical = 0

func _add_card(entry: Dictionary, seen: bool) -> void:
	var card := _button("", false)
	card.set_meta("content_id", entry.id)
	card.set_meta("revealed", seen)
	card.custom_minimum_size = Vector2(0, 100)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.disabled = not seen
	card.add_theme_stylebox_override("normal", _style(Color(0.96, 0.85, 0.62, 0.68), Color("87714b")))
	card.add_theme_stylebox_override("hover", _style(Color("ffe4a7"), Color("987034")))
	card.add_theme_stylebox_override("disabled", _style(Color(0.47, 0.43, 0.34, 0.48), Color("887752")))
	grid.add_child(card)
	card_buttons.append(card)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -12
	row.offset_top = 7
	row.offset_bottom = -7
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var preview := Preview.new()
	preview.custom_minimum_size = Vector2(90, 82)
	preview.configure(entry, seen)
	row.add_child(preview)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name_label := _label(String(entry.title).to_upper() if seen else "???", 21, INK if seen else MUTED)
	name_label.add_theme_font_override("font", HEADING)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(name_label)
	# Cards get the first sentence only; the full entry is behind the card.
	var card_text := String(entry.summary).split("\n")[0] if seen else "NOT YET DISCOVERED"
	var summary := _label(card_text, 15, INK if seen else MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(summary)
	for corner in [Vector2(5, 5), Vector2(-8, 5), Vector2(5, -8), Vector2(-8, -8)]:
		var rivet := Panel.new()
		rivet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rivet.add_theme_stylebox_override("panel", _style(Color("aa956d"), Color("524735")))
		rivet.size = Vector2(4, 4)
		if corner.x < 0:
			rivet.anchor_left = 1
			rivet.anchor_right = 1
		if corner.y < 0:
			rivet.anchor_top = 1
			rivet.anchor_bottom = 1
		rivet.position = corner
		card.add_child(rivet)
	if seen:
		card.pressed.connect(_show_detail.bind(entry))

func _build_detail() -> void:
	detail = PanelContainer.new()
	detail.add_theme_stylebox_override("panel", _style(Color("efdaad"), INK))
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	page.add_child(detail)
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 12)
	detail.add_child(detail_box)
	detail.hide()

func _show_detail(entry: Dictionary) -> void:
	if not DiscoveryTracker.is_discovered(entry.id):
		return
	for child in detail_box.get_children():
		detail_box.remove_child(child)
		child.queue_free()
	var heading := _label(String(entry.title).to_upper(), 30)
	heading.add_theme_font_override("font", HEADING)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_box.add_child(heading)
	var preview := Preview.new()
	preview.custom_minimum_size = Vector2(180, 180)
	preview.configure(entry, true)
	detail_box.add_child(preview)
	var description := _label(entry.summary + "\n\n" + entry.get("stats", ""), 19)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(description)
	var back := _button("BACK TO ENTRIES", false)
	back.pressed.connect(_close_detail)
	detail_box.add_child(back)
	detail.show()
	back.grab_focus()

func _close_detail() -> void:
	detail.hide()
	tab_buttons[active_category].grab_focus()

func _layout() -> void:
	if page == null:
		return
	var width := minf(size.x - 20, 1100)
	var height := minf(size.y - 16, 720)
	page.position = (size - Vector2(width, height)) * 0.5
	page.size = Vector2(width, height)
	content.position = Vector2(width * 0.065, height * 0.055)
	content.size = Vector2(width * 0.87, height * 0.88)
	grid.columns = 1 if width < 700 else 2
	tabs.columns = 2 if width < 700 else 4
	for icon in tab_icons:
		icon.visible = width >= 900 or (width >= 480 and width < 700)
	var detail_width := minf(width - 60, 620)
	detail.position = Vector2((width - detail_width) * 0.5, height * 0.18)
	detail.size = Vector2(detail_width, height * 0.68)

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if detail.visible:
			_close_detail()
		else:
			close()
		get_viewport().set_input_as_handled()

func _button(text: String, toggle: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = toggle
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", HEADING)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("dacbb1"))
	button.add_theme_color_override("font_hover_color", Color("fff1c2"))
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", Color("e7b442"))
	button.add_theme_stylebox_override("normal", _style(Color("303331"), Color("191b1a")))
	button.add_theme_stylebox_override("hover", _style(Color("4d4b3b"), Color("a38a58")))
	button.add_theme_stylebox_override("pressed", _style(Color("f1b83f"), Color("65451d")))
	var focus := _style(Color.TRANSPARENT, Color("e9a62d"))
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	return button

func _label(text: String, font_size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile in EnemyRoster.PROFILES:
		var summary: String = {"dots": "Changes form as it takes damage.", "charge": "Bursts forward at speed.", "rally": "Strengthens nearby spiders.", "armor": "Shrugs off repeated hits.", "enrage": "Enrages below half health.", "jump": "Moves only while jumping.", "hatch": "Hatches into smaller spiders."}.get(String(profile.ability), "A quick railway pest." if profile.id == "baby" else "A tough, slow-moving spider.")
		result.append({"id": "enemy:" + String(profile.id), "category": 0, "title": profile.name, "summary": summary, "profile": profile, "stats": "Base health: %d • Movement: ×%.2f\nHealth increases with campaign difficulty." % [profile.hp, profile.speed]})
	for tower in BuildManager.towers:
		var attacking := float(CarArt.for_tower(tower).get("range", 0)) > 0
		# The long authored description lives here rather than in the shop, which
		# only has room for the numbers and a one-line summary.
		result.append({"id": "tower:" + tower.tower_name.to_snake_case(), "category": 2 if attacking else 1, "title": tower.tower_name, "summary": UnitLore.for_tower(tower), "tower": tower, "stats": "Cost: Δ%d • Weight: %d • Health: %d" % [tower.cost, tower.weight, tower.health]})
	result.append({"id": "engine:steam", "category": 1, "title": "Steam Engine", "summary": "Carries your cars around the railway.", "texture": preload("res://assets/sprites/engines/Steam Engine 1.png"), "stats": "Purchase: Δ%d • Base capacity: %d" % [Menu.ENGINE_COST, (preload("res://resources/game_balance.tres") as GameBalance).carry_capacity]})
	for kind in ["straight", "curve", "end"]:
		var textures := {"straight": preload("res://assets/sprites/board/Rail Straight.png"), "curve": preload("res://assets/sprites/board/Rail Curve.png"), "end": preload("res://assets/sprites/board/Rail End.png")}
		result.append({"id": "track:" + kind, "category": 3, "title": {"straight": "Straight Rail", "curve": "Curved Rail", "end": "Buffer Stop"}[kind], "summary": {"straight": "Connects the line across a tile.", "curve": "Turns the railway around a corner.", "end": "Caps a dead-end rail extension."}[kind], "texture": textures[kind], "stats": "Expand your railway during STATIONS."})
	return result
