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
