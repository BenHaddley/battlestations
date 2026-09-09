extends RefCounted
class_name UnitLore
## The authored long-form description for each car.
##
## These paragraphs came from the shop rows' `tooltip_text` in Main.tscn, where
## Godot rendered them as a banner across the whole screen. This is now the
## source of truth and the Almanac reads it; Menu clears those scene tooltips
## at startup, so the copies still sitting in Main.tscn never render and should
## be deleted the next time that scene is edited. The Train Yard shows only
## what a purchase decision needs: name, price, weight, health, range and the
## one-line `TowerData.summary`.

const ENTRIES := {
	"Gunner Car": "Fires pellets at spiders within its range at a consistent rate.\n\nThis is your most basic attacking unit in the game, and a very reliable way of stopping the spider onslaught.",
	"Chaingunner Car": "Shoots large bursts of 7 pellets, with a cooldown of 4 seconds between each burst.\n\nThe spread of the burst means accuracy is slightly reduced, so not every shot will hit its mark. In exchange there is potential to hit multiple spiders rather than a single target.",
	"Ballast Blaster": "Fires a shotgun blast of ballast at any spiders within its short radius. The radius of the blast is 3 tiles wide.\n\nA very good burst option for spiders getting too close to the station for comfort.",
	"Passenger Coach": "Your main form of currency generation. Spawns the in-game currency 'Delta'.\n\nWithout this unit, building a hearty defense will likely be difficult if you are only relying on the consistent, but weak, passive income you are given during each level.",
	"Coal Cannon": "Fires a powerful cannonball at a slow rate. Blasts spiders within its range for high damage.\n\nThe coal dust thrown out from the impact deals minimal damage to spiders in a 3x3 area surrounding the impact point.",
	"Brake Van": "Caps off the train it is hooked up to, meaning no other cars can be added to that train once a Brake Van is attached.\n\nHowever, capping off the train grants all attacking units in it a significant increase in attack power. It also slightly decreases the time it takes to start moving and to come to a stop.",
	"Tender": "This car is meant to be placed directly behind a Steam Engine in a train. If it is, the maximum pull capacity is increased by 500 units.\n\nIf it is not placed directly behind the engine, this effect will not be activated. The Tender also matches the colour of the Steam Engine's paint job, for consistency's sake.",
	"Mail Carrier": "Flings letters rapidly at random spiders within its range.\n\nEvery envelope picks its own recipient, so a Mail Carrier spreads light damage across a crowd rather than concentrating it on one spider.",
}

static func for_tower(tower: TowerData) -> String:
	if tower == null:
		return ""
	return String(ENTRIES.get(tower.tower_name, tower.summary))
