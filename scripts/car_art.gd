extends RefCounted
class_name CarArt
## One source of truth for how a car looks off the rails. Every shop row,
## drag preview, placement ghost, almanac card and upgrade portrait renders
## the same chassis/turret pair the placed car uses, so a car can never look
## different in the Train Yard from how it looks once coupled.

const PLACED_SCALE := 0.54

## {"base": Texture2D, "base_scale": Vector2, "base_rotation": float,
##  "top": Texture2D or null, "top_scale": Vector2, "range": float}
## Scales already include the placed-car root scale so a ghost drawn at
## world scale matches the coupled car exactly. Results are cached on the
## BuildManager autoload (not in a static) so they are released at exit.
static func for_tower(tower: TowerData) -> Dictionary:
	if tower == null:
		return {}
	var _cache: Dictionary = BuildManager.car_art_cache
	if _cache.has(tower):
		return _cache[tower]
	var art := {"base": tower.icon, "base_scale": Vector2(0.0918, 0.0918), "base_rotation": 0.0, "top": null, "top_scale": Vector2(0.0918, 0.0918), "range": 0.0}
	if tower.scene:
		var instance: Node = tower.scene.instantiate()
		var base := instance.get_node_or_null("Base") as Sprite2D
		if base == null:
			base = instance.get_node_or_null("Sprite2D") as Sprite2D
		if base and base.texture:
			art.base = base.texture
			art.base_scale = base.scale * PLACED_SCALE
			art.base_rotation = base.rotation
		var top := instance.get_node_or_null("RotationPoint/Top") as Sprite2D
		if top and top.texture:
			art.top = top.texture
			art.top_scale = top.scale * PLACED_SCALE
		# Only attacking cars expose targeting_range; utility cars report 0 so
		# no radius is ever drawn for a coach, van or tender.
		var range_value = instance.get("targeting_range")
		if range_value != null:
			art.range = float(range_value)
		instance.free()
	_cache[tower] = art
	return art

## Flattened chassis+turret image for TextureRect/Button icons. Utility cars
## simply return their single sprite.
static func icon_for(tower: TowerData) -> Texture2D:
	if tower == null:
		return null
	var _icon_cache: Dictionary = BuildManager.car_icon_cache
	if _icon_cache.has(tower):
		return _icon_cache[tower]
	var art := for_tower(tower)
	var base: Texture2D = art.get("base")
	var top: Texture2D = art.get("top")
	var icon: Texture2D = base if base else tower.icon
	if base and top:
		var base_image: Image = base.get_image()
		var top_image: Image = top.get_image()
		if base_image and top_image:
			var composite := base_image.duplicate() as Image
			if composite.is_compressed():
				composite.decompress()
			var overlay := top_image.duplicate() as Image
			if overlay.is_compressed():
				overlay.decompress()
			overlay.convert(composite.get_format())
			# Turret art points up in its source; a coupled car's idle gun
			# points down the line, so flip it before laying it over the chassis.
			overlay.rotate_180()
			var top_ratio := (Vector2(art.top_scale) / Vector2(art.base_scale))
			var target := Vector2i(roundi(overlay.get_width() * top_ratio.x), roundi(overlay.get_height() * top_ratio.y))
			if target.x > 0 and target.y > 0 and target != overlay.get_size():
				overlay.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
			var offset := (composite.get_size() - overlay.get_size()) / 2
			composite.blend_rect(overlay, Rect2i(Vector2i.ZERO, overlay.get_size()), offset)
			icon = ImageTexture.create_from_image(composite)
	_icon_cache[tower] = icon
	return icon
