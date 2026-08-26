extends Control
class_name UnitUpgradePanel

signal closed
signal sell_requested(unit: Node2D, convoy: Node2D, refund: int)

const BRANCHES := [
	{"name": "DAMAGE", "color": Color("a9362d"), "nodes": [["Rapid Fire", "+25% Fire Rate"], ["Armor Piercing", "+2 Pierce"], ["Overclock", "+50% Fire Rate"], ["High Caliber", "+50% Damage"]]},
	{"name": "CONTROL", "color": Color("617b32"), "nodes": [["Freeze Rounds", "Slows enemies 20%"], ["Longer Reach", "+1.5 Range"], ["Targeting AI", "+25% Range"], ["Electro Field", "Chains to 2 enemies"]]},
	{"name": "SUPPORT", "color": Color("376a82"), "nodes": [["Supply Link", "+10% Fire Rate"], ["Repair Pulse", "Repairs nearby cars"], ["Overcharge", "+10% Damage"], ["Cargo Hold", "+15% train HP"]]},
]
const COSTS := [120, 180, 300, 400]

var unit: Node2D
var convoy: Node2D
var unit_data: TowerData
var selected_branch := 0
var selected_level := 0
var node_buttons: Array[Button] = []
var stats_label: Label
var title_label: Label
var preview: TextureRect
var upgrade_button: Button
var sell_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false

func open_for(selected_unit: Node2D, selected_convoy: Node2D, data: TowerData) -> void:
	_close_current(false)
	unit = selected_unit
	convoy = selected_convoy
	unit_data = data
	unit.modulate = Color(1.25, 1.15, 0.35, 1.0)
	title_label.text = "%s UPGRADES" % data.tower_name.to_upper()
	preview.texture = data.icon
	sell_button.text = "SELL\n+%d Δ" % int(round(data.cost * 0.5))
	visible = true
	_refresh()

func close_panel() -> void:
	_close_current(true)

func _close_current(emit_signal: bool) -> void:
	if is_instance_valid(unit):
		unit.modulate = Color.WHITE
	unit = null
	convoy = null
	unit_data = null
	visible = false
	if emit_signal:
		closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.025, 0.02, 0.3)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: close_panel()
	)
	add_child(shade)

	var card := PanelContainer.new()
	card.position = Vector2(355, 14)
	card.size = Vector2(565, 692)
	card.add_theme_stylebox_override("panel", _style(Color("efdbad"), Color("24160d"), 6, 12))
	add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := PanelContainer.new()
	header.custom_minimum_size.y = 44
	header.add_theme_stylebox_override("panel", _style(Color("a9362d"), Color("24160d"), 4, 4))
	root.add_child(header)
	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color("fff0cf"))
	title_label.add_theme_color_override("font_outline_color", Color("35150e"))
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title_label)

	var summary := HBoxContainer.new()
	summary.custom_minimum_size.y = 104
	summary.add_theme_constant_override("separation", 12)
	root.add_child(summary)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(185, 108)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.rotation = -0.025
	summary.add_child(preview)
	var stats_card := PanelContainer.new()
	stats_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_card.add_theme_stylebox_override("panel", _style(Color("f6e7c3"), Color("422516"), 3, 5))
	summary.add_child(stats_card)
	stats_label = Label.new()
	stats_label.add_theme_color_override("font_color", Color("2d1b10"))
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_card.add_child(stats_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 7)
	root.add_child(columns)
	for branch_index in range(BRANCHES.size()):
		columns.add_child(_make_branch(branch_index))

	var actions := HBoxContainer.new()
	actions.custom_minimum_size.y = 48
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)
	sell_button = _action_button("SELL", Color("a9362d"))
	sell_button.pressed.connect(_sell)
	actions.add_child(sell_button)
	var close := _action_button("CLOSE", Color("b88e58"))
	close.pressed.connect(close_panel)
	actions.add_child(close)
	upgrade_button = _action_button("UPGRADE", Color("477d45"))
	upgrade_button.pressed.connect(_buy_selected)
	actions.add_child(upgrade_button)

func _make_branch(branch_index: int) -> Control:
	var branch: Dictionary = BRANCHES[branch_index]
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	var heading := Label.new()
	heading.custom_minimum_size.y = 32
	heading.text = branch.name
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("fff2d4"))
	heading.add_theme_color_override("font_outline_color", Color("22150d"))
	heading.add_theme_constant_override("outline_size", 2)
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_stylebox_override("normal", _style(branch.color, Color("24160d"), 3, 3))
	box.add_child(heading)
	for level in range(4):
		var info: Array = branch.nodes[level]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 68)
		button.text = "%s\n%s\n◆ %d" % [info[0], info[1], COSTS[level]]
		button.add_theme_font_size_override("font_size", 13)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_select_node.bind(branch_index, level))
		button.set_meta("branch", branch_index)
		button.set_meta("level", level)
		node_buttons.append(button)
		box.add_child(button)
		if level < 3:
			var arrow := Label.new()
			arrow.custom_minimum_size.y = 12
			arrow.text = "↓"
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow.add_theme_color_override("font_color", branch.color)
			box.add_child(arrow)
	return box

func _select_node(branch: int, level: int) -> void:
	selected_branch = branch
	selected_level = level
	_refresh()

func _buy_selected() -> void:
	if not is_instance_valid(unit): return
	var levels: Array = _levels()
	if selected_level != int(levels[selected_branch]): return
	var cost: int = COSTS[selected_level]
	if not LevelManager.spend_currency(cost): return
	levels[selected_branch] = selected_level + 1
	unit.set_meta("upgrade_levels", levels)
	_apply_upgrade(selected_branch, selected_level)
	_refresh()

func _apply_upgrade(branch: int, level: int) -> void:
	if branch == 0:
		if level == 0 and unit.get("bps") != null: unit.set("bps", float(unit.get("bps")) * 1.25)
		elif level == 1: unit.set_meta("pierce", int(unit.get_meta("pierce", 0)) + 2)
		elif level == 2 and unit.get("bps") != null: unit.set("bps", float(unit.get("bps")) * 1.5)
		elif level == 3: unit.set_meta("damage_multiplier", float(unit.get_meta("damage_multiplier", 1.0)) * 1.5)
	elif branch == 1:
		if level == 0: unit.set_meta("slow_fraction", 0.2)
		elif level == 1 and unit.get("targeting_range") != null: unit.set("targeting_range", float(unit.get("targeting_range")) + 135.0)
		elif level == 2 and unit.get("targeting_range") != null: unit.set("targeting_range", float(unit.get("targeting_range")) * 1.25)
		elif level == 3: unit.set_meta("chain_targets", 2)
	else:
		if level == 0 and unit.get("attack_speed_multiplier") != null: unit.set("attack_speed_multiplier", float(unit.get("attack_speed_multiplier")) * 1.1)
		elif level == 1: unit.set_meta("repair_pulse", true)
		elif level == 2: unit.set_meta("damage_multiplier", float(unit.get_meta("damage_multiplier", 1.0)) * 1.1)
		elif level == 3: unit.set_meta("train_hp_bonus", 0.15)

func _levels() -> Array:
	if not is_instance_valid(unit): return [0, 0, 0]
	var existing = unit.get_meta("upgrade_levels", [0, 0, 0])
	return existing.duplicate()

func _refresh() -> void:
	if not is_instance_valid(unit): return
	var levels := _levels()
	var bps: float = float(unit.get("bps")) if unit.get("bps") != null else 0.0
	var range_value: float = float(unit.get("targeting_range")) / 90.0 if unit.get("targeting_range") != null else 0.0
	var damage := float(unit.get_meta("damage_multiplier", 1.0))
	stats_label.text = "DAMAGE   %.1fx\nFIRE RATE   %.2f/s\nRANGE   %.1f tiles" % [damage, bps, range_value]
	for button in node_buttons:
		var branch := int(button.get_meta("branch"))
		var level := int(button.get_meta("level"))
		var owned := level < int(levels[branch])
		var available := level == int(levels[branch])
		var selected := branch == selected_branch and level == selected_level
		var color: Color = BRANCHES[branch].color
		if owned: color = Color("66945b")
		elif not available: color = Color("746d62")
		elif selected: color = color.lightened(0.2)
		button.disabled = not available
		button.modulate = Color.WHITE if (owned or available) else Color(0.7, 0.7, 0.7, 0.82)
		button.add_theme_stylebox_override("normal", _style(color, Color("24160d"), 3, 3))
		button.add_theme_stylebox_override("disabled", _style(color.darkened(0.25), Color("24160d"), 3, 3))
	upgrade_button.disabled = selected_level != int(levels[selected_branch]) or LevelManager.currency < COSTS[selected_level]
	upgrade_button.text = "UPGRADE  ◆%d" % COSTS[selected_level]

func _sell() -> void:
	if not is_instance_valid(unit) or unit_data == null: return
	var sold_unit := unit
	var sold_convoy := convoy
	var refund := int(round(unit_data.cost * 0.5))
	_close_current(false)
	sell_requested.emit(sold_unit, sold_convoy, refund)

func _action_button(label: String, color: Color) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = label
	button.add_theme_color_override("font_color", Color("fff0cf"))
	button.add_theme_color_override("font_outline_color", Color("24160d"))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_stylebox_override("normal", _style(color, Color("24160d"), 4, 5))
	return button

func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = maxi(1, radius - 2)
	style.corner_radius_bottom_left = maxi(1, radius - 3)
	style.corner_radius_bottom_right = radius + 1
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style
