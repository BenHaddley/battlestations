extends Node
## Global signal bus. Mirrors Unity's static UnityEvent on EnemySpawner —
## any enemy can announce its own destruction without a direct reference
## to the spawner tracking wave counts.

signal enemy_destroyed
## Emitted by every spider attack while it remains alive at the station.
## Arrival is not destruction: the wave remains active until defenders kill it.
signal station_attacked(damage: int)
signal wave_completed(wave_number: int)
signal purchase_made
signal level_completed_detail(is_challenge: bool)
