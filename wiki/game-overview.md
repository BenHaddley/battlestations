# Game Overview

[Wiki home](README.md)

## One-sentence pitch

Battle Stations is a lane-defense game in which a black steam engine automatically
patrols one generated railway; the player attaches armed cars to its trailing consist while spiders march
from the top of the courtyard toward the station below.

That wording describes the surviving prototype. A broader narrative, final title
treatment, audience, platform strategy, and complete win condition are not yet
documented.

## Implemented player loop

1. The player starts the next wave from the HUD.
2. Spiders spawn into one of seven fixed lanes and march straight downward.
3. The player drags a Gunner or Slomo car from the shop onto the moving engine or train.
4. A valid drop purchases and attaches the car at the tail. It follows the engine's
   recorded route through every turn; invalid drops spend nothing.
5. Gunner trains acquire spiders and fire homing bullets; Slomo trains pulse a
   movement debuff around themselves.
6. Kills pay currency. Leaks damage the station at the bottom of the board.
7. After the wave clears, the player chooses when to start the next one.

The build has combat, economy, station health, a loss condition, and visible wave
status. Victory, restart flow, and a finished progression structure remain open.

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
- Active mobile defense scenes: two, both available through drag-and-drop shop cards.
- Multiplayer, train-car coupling, rail construction, and narrative progression are
  not present in the surviving implementation.
