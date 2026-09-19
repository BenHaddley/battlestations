extends Control
class_name UnitUpgradePanel
## Historical class name retained; the upgrade tree has been removed.

signal closed
signal sell_requested(unit: Node2D, convoy: Node2D, refund: int)

const BOARD_CELL := 65.5

var unit: Node2D
var convoy: Node2D
var unit_data: TowerData
var stats_label: Label
var title_label: Label
var preview: TextureRect
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
	title_label.text = "%s" % data.tower_name.to_upper()
	preview.texture = CarArt.icon_for(data)
	sell_button.text = "SELL\n+%d Δ" % int(round(CampaignManager.cost_of(data) * 0.5))
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
		if event is InputEventMouseButton and event.pressed:
			close_panel()
	)
	add_child(shade)

	var card := PanelContainer.new()
	card.position = Vector2(355, 185)
	card.size = Vector2(565, 310)
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
	title_label.add_theme_constant_override("outline_size", 5)
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

func _refresh() -> void:
	if not is_instance_valid(unit):
		return
	var bps: float = float(unit.get("bps")) if unit.get("bps") != null else 0.0
	var range_value: float = float(unit.get("targeting_range")) / BOARD_CELL if unit.get("targeting_range") != null else 0.0
	var damage: float = unit.damage_multiplier() if unit is Turret else 1.0
	var health := UnitHealth.of(unit)
	var health_line := "\nHP   %d / %d" % [ceili(health.hit_points), roundi(health.max_hit_points)] if health else ""
	if range_value > 0.0:
		stats_label.text = "DAMAGE   %.2fx\nFIRE RATE   %.2f/s\nRANGE   %.1f tiles%s" % [damage, bps, range_value, health_line]
	else:
		stats_label.text = "NO WEAPON\nSUPPORT CAR%s" % health_line

func _sell() -> void:
	if not is_instance_valid(unit) or unit_data == null:
		return
	var sold_unit := unit
	var sold_convoy := convoy
	var refund := int(round(CampaignManager.cost_of(unit_data) * 0.5))
	_close_current(false)
	sell_requested.emit(sold_unit, sold_convoy, refund)

func _action_button(label: String, color: Color) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = label
	button.add_theme_color_override("font_color", Color("fff0cf"))
	button.add_theme_color_override("font_outline_color", Color("24160d"))
	button.add_theme_constant_override("outline_size", 4)
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
