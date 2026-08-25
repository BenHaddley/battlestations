extends Node
## Global signal bus. Mirrors Unity's static UnityEvent on EnemySpawner —
## any enemy can announce its own destruction without a direct reference
## to the spawner tracking wave counts.

signal enemy_destroyed
