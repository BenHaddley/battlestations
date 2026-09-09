extends "res://scripts/bullet.gd"
## Stop at the recipient rather than overshooting it on a long frame.

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return
	var destination := target.global_position
	rotation = (destination - global_position).angle()
	global_position = global_position.move_toward(destination, bullet_speed * delta)
	if global_position.is_equal_approx(destination):
		_apply_hit(target)
