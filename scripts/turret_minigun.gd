extends "res://scripts/turret.gd"
## Five-shot burst car. The inherited fire timer is set to one burst every
## three seconds; small muzzle offsets keep the burst visibly spread.

const BURST_SIZE := 5

func _shoot() -> void:
	if bullet_scene == null or not is_instance_valid(target):
		return
	AudioFX.play(preload("res://assets/audio/sfx/turret_shoot.wav"), -4.0)
	var aim := (target.global_position - firing_point.global_position).normalized()
	var across := aim.orthogonal()
	for index in range(BURST_SIZE):
		var spread := float(index - 2) * 10.0
		var bullet: Node2D = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = firing_point.global_position + across * spread
		bullet.set_target(target)
		var tracer := preload("res://scripts/comic_tracer.gd").new()
		get_tree().current_scene.add_child(tracer)
		tracer.configure(bullet.global_position, target.global_position + across * spread * 0.7)
