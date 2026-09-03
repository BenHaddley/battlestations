extends "res://scripts/turret.gd"
## Short-range shotgun car. Every spider in the close targeting circle is hit
## by one blast while five supplied ballast chunks spray toward the target.

const BLAST_DAMAGE := 2
const CHUNK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/projectiles/Ballast 1.png"),
	preload("res://assets/sprites/projectiles/Ballast 2.png"),
	preload("res://assets/sprites/projectiles/Ballast 3.png"),
	preload("res://assets/sprites/projectiles/Ballast 4.png"),
	preload("res://assets/sprites/projectiles/Ballast 5.png"),
]

func _shoot() -> void:
	if not is_instance_valid(target):
		return
	AudioFX.play(preload("res://assets/audio/sfx/turret_shoot_ballast.wav"), -2.0)
	_play_recoil(8.0)
	for body in targeting_area.get_overlapping_bodies():
		if body.has_method("take_damage") and global_position.distance_to(body.global_position) <= targeting_range:
			body.take_damage(BLAST_DAMAGE)
	_spawn_ballast_spray(target.global_position)

func _spawn_ballast_spray(target_position: Vector2) -> void:
	var direction := (target_position - global_position).normalized()
	var angle := direction.angle()
	for index in range(CHUNK_TEXTURES.size()):
		var chunk := Sprite2D.new()
		chunk.texture = CHUNK_TEXTURES[index]
		chunk.global_position = global_position
		chunk.scale = Vector2(0.028, 0.028)
		chunk.rotation = angle + randf_range(-0.42, 0.42)
		chunk.z_index = 60
		get_tree().current_scene.add_child(chunk)
		var flight := Vector2.RIGHT.rotated(chunk.rotation) * randf_range(115.0, 190.0)
		var tween := get_tree().create_tween().set_parallel(true)
		tween.tween_property(chunk, "global_position", chunk.global_position + flight, 0.22)
		tween.tween_property(chunk, "rotation", chunk.rotation + randf_range(-1.2, 1.2), 0.22)
		tween.tween_property(chunk, "modulate:a", 0.0, 0.22)
		tween.chain().tween_callback(chunk.queue_free)
