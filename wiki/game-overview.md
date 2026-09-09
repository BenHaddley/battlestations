# Game Overview and Design Brief

[Wiki home](README.md)

## Pitch

Battle Stations is a single-player railway lane-defense game. Mobile trains patrol
closed circuits through a spider-infested courtyard; the player couples specialized
combat, economy, and support cars, manages multiple engines, and protects the station.

## Player objective

Survive every wave at the current campaign stop without letting repeated spider
attacks reduce the station's 60 HP to zero. Clearing a stop unlocks another car and
advances to a new authored railway. Clearing all seven stops opens endless Open Rails.
Challenge cards remix these rules, including the reverse Spider Assault mode.

## Core loop

1. During the 45-second Station phase, buy cars or engines, edit consists, lay or
   lift rail for Δ50 a tile, and select a locomotive.
2. Press START WAVE or wait for departure. Spiders enter one of nine lanes.
3. Trains cruise automatically. Up boosts the selected engine; a short Down press
   slows it to a crawl and holding Down reverses it.
4. Combat cars attack automatically. The player changes coverage through train
   composition, route, direction, and speed. Spiders steer round trains when a
   neighbouring lane is clear and bite the unit blocking them when it is not; a
   destroyed car drops out of the train and a wrecked engine waits for a new
   locomotive.
5. Kills, wave bonuses, and Passenger Coaches generate Delta. Purchases are the main
   sink; invalid or overweight drops spend nothing.
6. Surviving spiders attack the station until killed. Clearing a wave returns to the
   Station phase; zero station HP pauses play and shows Game Over.

## Roster roles

- Gunner: reliable single-target damage.
- Chaingunner: slow-cadence seven-shot burst.
- Ballast Blaster: short-range group damage.
- Coal Cannon: heavy direct hit plus splash and knockback.
- Mail Carrier: rapid envelopes, each at a random spider within 5×5.
- Passenger Coach: recurring Delta income.
- Brake Van: caps a train and improves combat and braking performance.
- Tender: increases capacity when directly behind the engine.

The spider roster adds rush, charge, rally, armour, tank, enrage, jump, and hatch
behaviors. Detailed values live in [Systems and balance](systems-and-balance.md).

## Placement, progression, and failure

Every level grants one locomotive. Additional locomotives cost Δ325 and must be
dropped on free rail. Cars attach to the nearest valid train in an ordered consist
within its hard capacity budget. Trains cannot park; braking approaches a minimum
crawl. Campaign progress persists in Web storage. Failure can restart the current
level or return to the title. Cars currently have an in-run upgrade/sell panel;
permanent cross-run upgrades remain intentionally absent until baseline balance is stable.

## Design boundaries

- Target: Godot 4.7.2 Web, single player, 1280×720 logical viewport.
- Armed cars use the original swivelling behavior following playtest feedback.
- STATIONS rail building and spider avoidance/biting are in as proposed design; the
  Barrier Car, junction switching, and a discovery gallery are deferred.
- Asset authorship and release permission must be established before public release.
- Recovered facts, collaborator direction, and new decisions remain distinguished.
