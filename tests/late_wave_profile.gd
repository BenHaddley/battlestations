extends Node
## Repeatable CPU-side stress probe for the configured 15-spider/second cap.
## This is not a substitute for the release browser profile: it deliberately
## excludes rendering, audio, and JavaScript/WASM overhead.

const EnemyScene := preload("res://scenes/Enemy.tscn")
const ACTIVE_SPIDERS := 225 # Fifteen seconds of backlog at the configured cap.
const SIMULATION_FRAMES := 120

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var enemies: Array[EnemyMovement] = []
	for index in range(ACTIVE_SPIDERS):
		var enemy: EnemyMovement = EnemyScene.instantiate()
		add_child(enemy)
		enemy.global_position = Vector2(float(index % 9) * 65.5, -425.0 - float(index / 9) * 4.0)
		enemy.configure_archetype(EnemyRoster.PROFILES[0], 160, 6)
		enemy.configure_lane(380.0, 25.0)
		enemies.append(enemy)

	var started := Time.get_ticks_usec()
	for _frame in range(SIMULATION_FRAMES):
		for enemy in enemies:
			enemy._physics_process(1.0 / 60.0)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var average_ms := elapsed_ms / float(SIMULATION_FRAMES)
	print("LATE WAVE CPU PROFILE: %d spiders, %.3f ms/frame, %.1f simulated spiders/sec" % [ACTIVE_SPIDERS, average_ms, ACTIVE_SPIDERS * 60.0])
	get_tree().quit(0)
