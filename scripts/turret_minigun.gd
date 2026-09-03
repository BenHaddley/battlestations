extends "res://scripts/turret.gd"
## The "Chaingunner Car" from its infowiki card (#007) — filename kept as
## Minigun since that's just this scene's earlier working name. Bursts of 7
## pellets every 4 seconds (bps = 0.25); small muzzle offsets keep the burst
## visibly spread, per the card's "accuracy is all but slightly reduced."

const BURST_SIZE := 7
@export_range(0.03, 0.3, 0.01) var burst_interval := 0.09

var _bursting := false

func _shoot() -> void:
	if _bursting or bullet_scene == null or not is_instance_valid(target):
		return
	_bursting = true
	_fire_burst()

func _fire_burst() -> void:
	for index in range(BURST_SIZE):
		if not is_inside_tree() or not is_instance_valid(target):
			break
		_fire_burst_round(index)
		if index < BURST_SIZE - 1:
			await get_tree().create_timer(burst_interval, false).timeout
	_bursting = false

func _fire_burst_round(index: int) -> void:
	AudioFX.play(preload("res://assets/audio/sfx/turret_shoot_minigun.wav"), -12.0)
	_play_recoil(2.5)
	var aim := (target.global_position - firing_point.global_position).normalized()
	var across := aim.orthogonal()
	var spread := float(index - 3) * 10.0
	var bullet: Node2D = bullet_scene.instantiate()
	if bullet.get("bullet_damage") != null:
		bullet.set("bullet_damage", maxi(1, int(round(float(bullet.get("bullet_damage")) * float(get_meta("damage_multiplier", 1.0))))))
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = firing_point.global_position + across * spread
	bullet.set_target(target)
	var tracer := preload("res://scripts/comic_tracer.gd").new()
	get_tree().current_scene.add_child(tracer)
	tracer.configure(bullet.global_position, target.global_position + across * spread * 0.7)
