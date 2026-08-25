# Game Overview

[Wiki home](README.md)

## One-sentence pitch

Battle Stations is a railway-themed tower-defense game in which the player spends
currency to place and upgrade train-inspired defenses while waves of spiders follow a
fixed route across the board.

That wording describes the surviving prototype. A broader narrative, final title
treatment, audience, platform strategy, and complete win condition are not yet
documented.

## Implemented player loop

1. A wave begins after a five-second delay.
2. Spiders spawn at a rate and quantity that grow by wave.
3. Spiders travel through a sequence of hand-placed path markers.
4. The player clicks an empty plot to buy the selected defense.
5. A gun turret automatically targets spiders and fires homing bullets.
6. Killing a spider pays currency; reaching the end currently removes it without a
   player penalty.
7. The next wave starts five seconds after the current wave is cleared.

The build therefore has combat and an economy, but not yet a complete game loop:
there is no base health, loss, victory, restart flow, or visible wave status.

## Theme and content vocabulary

The surviving material consistently combines railways and spiders:

- Defenses and concepts include engines, gunner cars, Coal Cannon, Minigun,
  Ballast Blaster, Brake Van, Oil Tanker, Passenger Coach, and Slate Return.
- Enemies include a generic Spider plus Baby, Charger, Rally, Roller, Sturdy, Wolf,
  Jump, and Egg artwork.
- The playfield is a railway board with rail tiles, rocks, and breakable-looking
  board pieces.

Only the generic gun turret, a white-engine slow field, and a generic spider are
wired into active scenes. Roles implied by other names remain **inferred**, not
confirmed.

## Present scope

- Engine: Godot 4, GL Compatibility renderer.
- Main target in the roadmap: a browser-playable build.
- Active board count: one.
- Active enemy scene count: one.
- Active defense scenes: two, although the shop catalog is not configured in the
  checked-in scene or project settings.
- Multiplayer, train-car coupling, rail construction, and narrative progression are
  not present in the surviving implementation.
