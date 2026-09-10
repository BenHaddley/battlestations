extends "res://scripts/turret.gd"
## Picks independently for every envelope; consecutive shots may pick the same spider.

func _process(delta: float) -> void:
	_patrol_track(delta)
	time_until_fire += delta
	var interval := 1.0 / (bps * attack_speed_multiplier)
	if time_until_fire >= interval:
		_shoot()
		# No banked volley when spiders enter an empty radius.
		time_until_fire = 0.0

func _find_target() -> Node2D:
	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("spiders"):
		var spider := node as Node2D
		if not is_instance_valid(spider) or spider.is_queued_for_deletion():
			continue
		var health := spider.get_node_or_null("Health") as Health
		if health != null and health.is_destroyed:
			continue
		if spider.has_method("protected_by_egg") and spider.protected_by_egg(global_position, targeting_range): continue
		if global_position.distance_squared_to(spider.global_position) <= targeting_range * targeting_range:
			candidates.append(spider)
	return null if candidates.is_empty() else candidates.pick_random()

func _shoot() -> void:
	target = _find_target()
	if not is_instance_valid(target):
		return
	# Aim at this shot's recipient before placing its projectile at the muzzle.
	turret_rotation_point.rotation = (target.global_position - global_position).angle() + PI * 0.5
	super._shoot()
