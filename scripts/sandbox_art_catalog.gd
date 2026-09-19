extends RefCounted
class_name SandboxArtCatalog

const ART_PATH := "res://assets/sprites/units/ai_drafts/"
const NAMES := ["DIESEL ENGINE", "TURBINE COACH", "GREENHOUSE", "STEEL DRIVER", "CLIQUE CAR", "CROSSFIRE CAR", "BARRIER CAR", "THUMPER", "SCAPEGOAT", "VELOCITY VAN", "MINI VAN", "THROTTLE ROCKET", "WEB WHACKER", "JACKHAMMER"]
const PAIRED := ["GREENHOUSE", "STEEL DRIVER", "CLIQUE CAR", "CROSSFIRE CAR", "THUMPER", "WEB WHACKER", "JACKHAMMER"]
const CarScript := preload("res://scripts/sandbox_art_car.gd")

static func create_towers() -> Array[TowerData]:
	var result: Array[TowerData] = []
	for title in NAMES:
		var paired: bool = title in PAIRED
		var base := load(ART_PATH + title + (" B.png" if paired else ".png")) as Texture2D
		var root := Node2D.new()
		root.set_script(CarScript)
		root.name = title.to_pascal_case()
		root.z_index = 20
		var chassis := Sprite2D.new()
		chassis.name = "Base"
		chassis.texture = base
		# Scale at rendering time; keep original PNG pixels untouched.
		var height := 160.0 if title == "BARRIER CAR" else 110.0
		chassis.scale = Vector2.ONE * height / base.get_height()
		root.add_child(chassis)
		chassis.owner = root
		if paired:
			var pivot := Node2D.new()
			pivot.name = "RotationPoint"
			pivot.rotation = PI
			root.add_child(pivot)
			pivot.owner = root
			var top := Sprite2D.new()
			top.name = "Top"
			top.texture = load(ART_PATH + title + " A.png")
			top.scale = chassis.scale
			top.rotation = -PI * 0.5
			pivot.add_child(top)
			top.owner = root
		var data := TowerData.new()
		data.tower_name = title.capitalize()
		data.icon = base
		data.cost = 0
		data.weight = 0
		data.health = 200
		data.summary = "Art prototype: rides on trains for visual review. No attacks or special abilities; placeholder health and footprint."
		data.scene = PackedScene.new()
		data.scene.pack(root)
		root.free()
		result.append(data)
	return result
