extends "res://scripts/turret.gd"
## The "Chaingunner Car" from its infowiki card (#007) — filename kept as
## Minigun since that's just this scene's earlier working name. Bursts of 7
## pellets every 4 seconds (bps = 0.25); small muzzle offsets keep the burst
## visibly spread, per the card's "accuracy is all but slightly reduced."

const BURST_SIZE := 7

func _shoot() -> void:
	if bullet_scene == null or not is_instance_valid(target):
		return
	AudioFX.play(preload("res://assets/audio/sfx/turret_shoot.wav"), -4.0)
	var aim := (target.global_position - firing_point.global_position).normalized()
	var across := aim.orthogonal()
	for index in range(BURST_SIZE):
		var spread := float(index - 3) * 10.0
		var bullet: Node2D = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = firing_point.global_position + across * spread
		bullet.set_target(target)
		var tracer := preload("res://scripts/comic_tracer.gd").new()
		get_tree().current_scene.add_child(tracer)
		tracer.configure(bullet.global_position, target.global_position + across * spread * 0.7)
