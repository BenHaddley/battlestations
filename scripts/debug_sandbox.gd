extends Node2D
## Lightweight unit lab. Run this scene directly; it deliberately bypasses
## campaign progression, prices, waves, and train placement restrictions.

const EnemyScene := preload("res://scenes/Enemy.tscn")
const CAR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
const SPIDER_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O]

var _last_car: Node2D
var _spawned: Array[Node] = []
var _status: Label

func _ready() -> void:
	_build_background()
	_build_help()
	_status.text = "Unit lab ready — move the mouse, then press a spawn key."

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var car_index := CAR_KEYS.find(event.keycode)
	if car_index >= 0:
		_spawn_car(car_index)
		return
	var spider_index := SPIDER_KEYS.find(event.keycode)
	if spider_index >= 0:
		_spawn_spider(spider_index)
		return
	match event.keycode:
		KEY_F:
			if is_instance_valid(_last_car) and _last_car.has_method("set_fixed_facing"):
				_last_car.set_fixed_facing(-int(_last_car.get("fixed_direction_facing")))
				_status.text = "Flipped the last directional gun car."
		KEY_V:
			if is_instance_valid(_last_car) and _last_car.has_method("set_fixed_direction_enabled"):
				_last_car.set_fixed_direction_enabled(not bool(_last_car.get("fixed_direction_enabled")))
				_status.text = "Toggled static/swivel mode on the last gun car."
		KEY_C:
			_clear_lab()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _spawn_car(index: int) -> void:
	if index >= BuildManager.towers.size():
		return
	var data: TowerData = BuildManager.towers[index]
	if data == null or data.scene == null:
		return
	var car: Node2D = data.scene.instantiate()
	add_child(car)
	car.global_position = get_viewport().get_mouse_position()
	if car.has_method("set_convoy_transform"):
		car.set_convoy_transform(car.global_position, Vector2.UP)
	_spawned.append(car)
	_last_car = car
	_status.text = "Spawned %s. F flips; V compares static and swivel modes." % data.tower_name

func _spawn_spider(index: int) -> void:
	if index >= EnemyRoster.PROFILES.size():
		return
	var spider: EnemyMovement = EnemyScene.instantiate()
	add_child(spider)
	spider.global_position = get_viewport().get_mouse_position()
	spider.configure_archetype(EnemyRoster.PROFILES[index], 1, 0)
	spider.configure_route(Vector2(spider.global_position.x, 680.0), 18.0)
	_spawned.append(spider)
	_status.text = "Spawned %s; it will travel toward the bottom test boundary." % EnemyRoster.PROFILES[index].name

func _clear_lab() -> void:
	for item in _spawned:
		if is_instance_valid(item):
			item.queue_free()
	_spawned.clear()
	_last_car = null
	_status.text = "Lab cleared."

func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("17232b")
	background.size = Vector2(1280, 720)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -100
	add_child(background)
	for y in range(110, 720, 90):
		var rail := Line2D.new()
		rail.default_color = Color("765b42")
		rail.width = 5.0
		rail.points = PackedVector2Array([Vector2(0, y), Vector2(1280, y)])
		rail.z_index = -90
		add_child(rail)

func _build_help() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 12)
	panel.size = Vector2(1252, 82)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 200
	var box := VBoxContainer.new()
	panel.add_child(box)
	var help := Label.new()
	help.text = "DEBUG UNIT LAB  |  Cars: 1–7  |  Spiders: Q W E R T Y U I O  |  F: flip last gun  |  V: static/swivel  |  C: clear  |  Esc: menu"
	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 5)
	box.add_child(help)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color("f2ce75"))
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 4)
	box.add_child(_status)
	add_child(panel)
