extends Control
## Draws visual resources only: no live enemies/turrets, AI, audio or discovery side effects.

var layers: Array[Dictionary] = []
var bounds := Rect2(-50, -50, 100, 100)
var category := 0
var unknown := false
var clock := 0.0

func configure(entry: Dictionary, revealed: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	category = int(entry.get("category", 0))
	unknown = not revealed
	if unknown:
		return
	if entry.has("tower"):
		var tower: TowerData = entry.tower
		var art := CarArt.for_tower(tower)
		var instance := tower.scene.instantiate()
		var base_angle := float(art.base_rotation)
		var top_angle := PI
		if instance is Turret:
			# Evaluate the same idle orientation as a placed car without entering
			# the scene tree or running combat/ready side effects.
			instance.train_chassis = instance.get_node("Base")
			instance.turret_rotation_point = instance.get_node("RotationPoint")
			instance._face_direction(Vector2.DOWN)
			base_angle = instance.train_chassis.rotation
			top_angle = instance.turret_rotation_point.rotation + instance.get_node("RotationPoint/Top").rotation
		_add_layer(art.base, Vector2(art.base_scale), base_angle)
		if art.top:
			_add_layer(art.top, Vector2(art.top_scale), top_angle)
		instance.free()
	elif entry.has("profile"):
		var profile: Dictionary = entry.profile
		var frames: Array = EnemyMovement.DOT_STAGE_TEXTURES[0] if profile.id == "generic" else [profile.walk_a, profile.walk_b]
		_add_layer(frames[0], Vector2.ONE * float(profile.scale), 0.0, frames[1])
	else:
		_add_layer(entry.get("texture"), Vector2.ONE * 0.1, 0.0)
	if not layers.is_empty():
		bounds = layers[0].bounds
		for layer in layers:
			bounds = bounds.merge(layer.bounds)
	set_process(entry.has("profile"))

func _add_layer(texture: Texture2D, sprite_scale: Vector2, angle: float, alternate: Texture2D = null) -> void:
	if texture == null:
		return
	var transform := Transform2D(angle, sprite_scale, 0.0, Vector2.ZERO)
	var used := Rect2(Vector2.ZERO, texture.get_size())
	var pixels := texture.get_image()
	if pixels:
		if pixels.is_compressed():
			pixels.decompress()
		used = Rect2(pixels.get_used_rect())
	used.position -= texture.get_size() * 0.5
	layers.append({"texture": texture, "alternate": alternate, "scale": sprite_scale, "angle": angle, "bounds": transform * used})

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	if unknown:
		var center := size * 0.5
		var ink := Color("706449")
		# Generic sealed entry, never the hidden unit's actual artwork.
		if category == 0:
			draw_circle(center, 15.0, ink)
			draw_circle(center + Vector2(0, -16), 9.0, ink)
			for side in [-1, 1]:
				for y in [-12, -3, 6, 15]:
					draw_polyline(PackedVector2Array([center + Vector2(side * 9, y), center + Vector2(side * 24, y - 7), center + Vector2(side * 28, y + 7)]), ink, 4.0, true)
		else:
			draw_style_box(_seal_style(ink), Rect2(center - Vector2(19, 19), Vector2(38, 38)))
			draw_arc(center + Vector2(0, -17), 11, PI, TAU, 20, ink, 5, true)
			draw_circle(center, 4, Color("bcaa83"))
		return
	if layers.is_empty():
		return
	var factor := minf((size.x - 14.0) / maxf(bounds.size.x, 1.0), (size.y - 14.0) / maxf(bounds.size.y, 1.0))
	var origin := size * 0.5 - bounds.get_center() * factor
	for layer in layers:
		var texture: Texture2D = layer.texture
		if layer.alternate != null and int(clock * 4.0) % 2 == 1:
			texture = layer.alternate
		draw_set_transform(origin, float(layer.angle), Vector2(layer.scale) * factor)
		draw_texture(texture, -texture.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO)

func _seal_style(ink: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ink
	style.set_corner_radius_all(5)
	return style
