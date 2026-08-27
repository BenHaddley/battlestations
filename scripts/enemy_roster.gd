extends RefCounted
class_name EnemyRoster
## Existing spider artwork promoted into gameplay archetypes. unlock_level is
## zero-based campaign progress, keeping level one focused on the generic form.

const PROFILES: Array[Dictionary] = [
	{"id":"generic", "name":"Dotted Spider", "unlock_level":0, "weight":8, "hp":5, "speed":1.0, "bounty":45, "scale":0.095, "ability":"dots", "walk_a":preload("res://assets/sprites/spiders/Spider walk 2-1.png"), "walk_b":preload("res://assets/sprites/spiders/Spider walk 2-2.png"), "death":preload("res://assets/sprites/spiders/Spider Die 1.png")},
	{"id":"baby", "name":"Baby Spider", "unlock_level":1, "weight":5, "hp":3, "speed":1.45, "bounty":35, "scale":0.160, "ability":"", "walk_a":preload("res://assets/sprites/spiders/Baby 1.png"), "walk_b":preload("res://assets/sprites/spiders/Baby 2.png"), "death":preload("res://assets/sprites/spiders/Baby Die.png")},
	{"id":"charger", "name":"Charger", "unlock_level":1, "weight":3, "hp":7, "speed":1.0, "bounty":70, "scale":0.090, "ability":"charge", "walk_a":preload("res://assets/sprites/spiders/Charger 1.png"), "walk_b":preload("res://assets/sprites/spiders/Charger 2.png"), "death":preload("res://assets/sprites/spiders/Charger Die.png")},
	{"id":"rally", "name":"Rally Spider", "unlock_level":2, "weight":2, "hp":8, "speed":0.85, "bounty":90, "scale":0.090, "ability":"rally", "walk_a":preload("res://assets/sprites/spiders/Rally 1.png"), "walk_b":preload("res://assets/sprites/spiders/Rally 2.png"), "death":preload("res://assets/sprites/spiders/Rally Die.png")},
	{"id":"roller", "name":"Roller", "unlock_level":3, "weight":3, "hp":10, "speed":1.15, "bounty":100, "scale":0.092, "ability":"armor", "walk_a":preload("res://assets/sprites/spiders/Roller 1.png"), "walk_b":preload("res://assets/sprites/spiders/Roller 2.png"), "death":preload("res://assets/sprites/spiders/Roller Die.png")},
	{"id":"sturdy", "name":"Sturdy Spider", "unlock_level":3, "weight":3, "hp":16, "speed":0.62, "bounty":125, "scale":0.105, "ability":"", "walk_a":preload("res://assets/sprites/spiders/Sturdy 1.png"), "walk_b":preload("res://assets/sprites/spiders/Sturdy 2.png"), "death":preload("res://assets/sprites/spiders/Sturdy Die.png")},
	{"id":"wolf", "name":"Wolf Spider", "unlock_level":4, "weight":2, "hp":12, "speed":1.05, "bounty":140, "scale":0.100, "ability":"enrage", "walk_a":preload("res://assets/sprites/spiders/Wolf 1.png"), "walk_b":preload("res://assets/sprites/spiders/Wolf 2.png"), "rage_a":preload("res://assets/sprites/spiders/Wolf Anfy 1.png"), "rage_b":preload("res://assets/sprites/spiders/Wolf Angy 2.png"), "death":preload("res://assets/sprites/spiders/Wolf Die.png")},
	{"id":"jump", "name":"Jump Spider", "unlock_level":5, "weight":2, "hp":10, "speed":1.1, "bounty":150, "scale":0.095, "ability":"jump", "walk_a":preload("res://assets/sprites/spiders/Spider Jump 1.png"), "walk_b":preload("res://assets/sprites/spiders/Spider Jump 2.png"), "death":preload("res://assets/sprites/spiders/Spider Jump Die.png")},
	{"id":"egg", "name":"Spider Egg", "unlock_level":6, "weight":2, "hp":18, "speed":0.48, "bounty":175, "scale":0.105, "ability":"hatch", "walk_a":preload("res://assets/sprites/spiders/Spider Egg 1.png"), "walk_b":preload("res://assets/sprites/spiders/Spider Egg 2.png"), "break":preload("res://assets/sprites/spiders/Spider Egg Break.png"), "baby_a":preload("res://assets/sprites/spiders/Baby 1.png"), "baby_b":preload("res://assets/sprites/spiders/Baby 2.png"), "death":preload("res://assets/sprites/spiders/Baby Die.png")},
]

static func available(campaign_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile in PROFILES:
		if int(profile.unlock_level) <= campaign_level:
			for _copy in range(int(profile.weight)):
				result.append(profile)
	return result

static func pick(campaign_level: int) -> Dictionary:
	var pool := available(campaign_level)
	return pool.pick_random() if not pool.is_empty() else PROFILES[0]

static func by_id(profile_id: String) -> Dictionary:
	for profile in PROFILES:
		if String(profile.id) == profile_id:
			return profile
	return {}
