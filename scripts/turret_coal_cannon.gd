extends "res://scripts/turret.gd"
## Slow-firing splash car. All damage numbers live on the CoalCannonball
## projectile itself; the base Turret behavior (targeting, patrol, firing
## timer) is unchanged aside from its own shot sound.

func _shoot_sound() -> AudioStream:
	return preload("res://assets/audio/sfx/turret_shoot_coal_cannon.wav")

func _shoot_volume_db() -> float:
	return -3.0
