extends Node
## Global signal bus. Mirrors Unity's static UnityEvent on EnemySpawner —
## any enemy can announce its own destruction without a direct reference
## to the spawner tracking wave counts.

signal enemy_destroyed
## Fired only when an enemy reaches the end of its lane unharmed — distinct
## from enemy_destroyed (which fires for both kills and leaks, for wave
## bookkeeping) so the station can take damage only on a leak.
signal enemy_leaked
