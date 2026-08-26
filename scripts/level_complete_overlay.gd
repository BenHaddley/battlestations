extends Control
class_name LevelCompleteOverlay
## Full-screen dimmer + centered card shown when a campaign level's final
## wave clears. Built entirely at runtime (no .tscn), same pattern as
## unit_upgrade_panel.gd. main.gd creates this once and connects it to
## CampaignManager.level_completed.

signal continue_pressed

var _title_label: Label
var _subtitle_label: Label
var _reward_label: Label
var _continue_button: Button

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 300)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.93, 0.87, 0.72, 1)
	card_style.border_width_left = 7
	card_style.border_width_top = 6
	card_style.border_width_right = 7
	card_style.border_width_bottom = 8
	card_style.border_color = Color(0.1, 0.07, 0.045, 1)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_right = 6
	card_style.corner_radius_bottom_left = 10
	card.add_theme_stylebox_override("panel", card_style)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.pivot_offset = card.custom_minimum_size * 0.5
	card.position = Vector2(640, 360) - card.custom_minimum_size * 0.5
	add_child(card)

	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var frame_script: Script = load("res://scripts/hand_drawn_frame.gd")
	frame.set_script(frame_script)
	card.add_child(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.06, 0.05, 0.03, 1))
	_title_label.add_theme_color_override("font_outline_color", Color(0.42, 0.1, 0.06, 0.85))
	_title_label.add_theme_constant_override("outline_size", 2)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.add_theme_color_override("font_color", Color(0.18, 0.12, 0.07, 1))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_subtitle_label)

	var reward_panel := PanelContainer.new()
	var reward_style := StyleBoxFlat.new()
	reward_style.bg_color = Color(0.6, 0.82, 0.72, 1)
	reward_style.border_width_left = 3
	reward_style.border_width_top = 3
	reward_style.border_width_right = 3
	reward_style.border_width_bottom = 3
	reward_style.border_color = Color(0.08, 0.06, 0.04, 1)
	reward_style.corner_radius_top_left = 4
	reward_style.corner_radius_top_right = 8
	reward_style.corner_radius_bottom_right = 4
	reward_style.corner_radius_bottom_left = 8
	reward_panel.add_theme_stylebox_override("panel", reward_style)
	vbox.add_child(reward_panel)

	_reward_label = Label.new()
	_reward_label.add_theme_font_size_override("font_size", 17)
	_reward_label.add_theme_color_override("font_color", Color(0.06, 0.05, 0.03, 1))
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.custom_minimum_size = Vector2(0, 34)
	_reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_panel.add_child(_reward_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	_continue_button = Button.new()
	_continue_button.text = "CONTINUE"
	_continue_button.custom_minimum_size = Vector2(0, 46)
	_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_continue_button.add_theme_font_size_override("font_size", 20)
	_continue_button.add_theme_color_override("font_color", Color(1, 0.94, 0.88, 1))
	_continue_button.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.015, 0.9))
	_continue_button.add_theme_constant_override("outline_size", 2)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.43, 0.055, 0.045, 1)
	button_style.border_width_left = 4
	button_style.border_width_top = 4
	button_style.border_width_right = 5
	button_style.border_width_bottom = 4
	button_style.border_color = Color(0.06, 0.025, 0.018, 1)
	button_style.corner_radius_top_left = 2
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_right = 2
	button_style.corner_radius_bottom_left = 4
	_continue_button.add_theme_stylebox_override("normal", button_style)
	_continue_button.add_theme_stylebox_override("hover", button_style)
	_continue_button.pressed.connect(_on_continue_pressed)
	vbox.add_child(_continue_button)

func show_for(level: LevelData, is_finale: bool) -> void:
	if is_finale:
		_title_label.text = "CAMPAIGN COMPLETE"
		_subtitle_label.text = "Every car is unlocked. The rails stay open — waves keep coming in Open Rails mode."
		_reward_label.text = "FULL ROSTER UNLOCKED"
		_reward_label.get_parent().visible = true
	else:
		_title_label.text = "LEVEL COMPLETE"
		_subtitle_label.text = "%s cleared." % level.level_name
		if level.new_tower_index >= 0 and level.new_tower_index < BuildManager.towers.size():
			var reward: TowerData = BuildManager.towers[level.new_tower_index]
			_reward_label.text = "NEW UNIT UNLOCKED: %s" % reward.tower_name
			_reward_label.get_parent().visible = true
		else:
			_reward_label.get_parent().visible = false
	visible = true

func _on_continue_pressed() -> void:
	visible = false
	continue_pressed.emit()
