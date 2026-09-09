extends Resource
class_name GameBalance
## Shared baseline tuning. Specialized car and spider values remain in their own
## catalog entries; this resource owns values used across whole game systems.

@export_group("Waves")
@export var base_enemies: int = 3
@export var base_spawn_rate: float = 0.4
@export var enemy_count_exponent: float = 1.15
@export var spawn_rate_exponent: float = 0.75
@export var spawn_rate_cap: float = 15.0
@export var journey_duration: float = 25.0
@export var station_phase_duration: float = 45.0

@export_group("Economy")
@export var early_generic_bounty: int = 18
@export var wave_bonus_base: int = 35
@export var wave_bonus_per_wave: int = 12
@export var passenger_income: int = 32
@export var passenger_income_interval: float = 8.0
@export var locomotive_cost: int = 325
## Provisional STATIONS rail price per tile (2026-09-09 notes); to be
## workshopped after playtesting. Removal refunds the same amount.
@export var rail_tile_cost: int = 50

@export_group("Train Damage")
## Workbook STEAM ENGINE health.
@export var engine_health: int = 300
## Provisional 2026-09-09 direction: about 25 damage per second per spider
## chewing on a blocked unit, applied in fixed ticks; several spiders stack
## linearly.
@export var bite_damage_per_second: float = 25.0
@export var bite_tick_seconds: float = 0.25
## A spider struck by a moving train takes about one Gunner bullet's worth
## (Bullet.tscn deals 20) and the train recoils a little. Each spider can be
## struck by the same unit only once per cooldown so ramming cannot replace
## the guns.
@export var impact_damage: int = 20
@export var impact_cooldown_seconds: float = 2.0
## Below this fraction of cruise speed a train nudges spiders aside without
## hurting them.
@export var impact_minimum_speed_fraction: float = 0.6
@export var impact_recoil_distance: float = 8.0
@export var impact_speed_retained: float = 0.35

@export_group("Train")
@export var cruise_speed: float = 46.0
@export var maximum_speed: float = 82.0
@export var minimum_speed: float = 14.0
@export var acceleration: float = 28.0
@export var deceleration: float = 34.0
@export var reverse_acceleration: float = 28.0
@export var carry_capacity: float = 1000.0
@export var tender_capacity_bonus: float = 500.0
@export var car_spacing: float = 94.0
@export var minimum_consist_clearance: float = 64.0
@export var attachment_radius: float = 76.0
