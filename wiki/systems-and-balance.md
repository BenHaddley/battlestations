# Systems and Balance

[Wiki home](README.md)

Values on this page are **implemented defaults** from the active GDScript and scenes,
not claims of final balance.

Shared wave, economy, and train tuning lives in the inspectable
`resources/game_balance.tres` resource. Individual car and spider catalog entries
retain their mechanic-specific values.

## Economy

The currency is named **Delta** (`Δ`) throughout the HUD, per the
[Passenger Coach infowiki card](infowiki-cards.md#003--passenger-coach).

| Parameter | Default |
|---|---:|
| Campaign starting currency | 300–600, by level |
| Generic early-wave bounty (waves 1–3) | 18 |
| Specialist bounty | 8–45, plus 8 per campaign level |
| Passenger Coach income | 32 every 8 seconds while coupled |
| Wave completion bonus | 35 + 12 × wave number |

Dropping a shop car on a valid rail spends its `TowerData.cost`, but only after
`TrainConvoy.attach_car()` also confirms the target train has capacity — see
[Train weight and momentum](#train-weight-and-momentum). Invalid, off-track, or
over-capacity drops spend nothing. Coupled cars can also be selected for the active
upgrade/sell panel. Currency sinks are purchases and upgrades; its
only sources are spider bounties, wave-completion bonuses, and Passenger Coach income.

### Documented balance direction

Gubgub's 2026-08-28 playtest found that spider bounties make Delta excessively
abundant in larger waves, eventually making car prices inconsequential. The intended
retune is to reduce kill income and make the player rely more heavily on Passenger
Coach income. Exact replacement values have not been supplied, so the implemented
values are an intentional first playtest baseline, not recovered canon or final approval.

## Placeable cars

[Infowiki unit cards](infowiki-cards.md) is the authoritative design source for these
cars' cost, range, weight, and role — the numbers below are adopted from it wholesale,
not shipped independently. The roster is deliberately exactly the cards documented
there: Slomo (no card in the recovered folder) and an earlier standalone Chaingun car
(redundant with the Chaingunner Car card below) were both removed rather than kept
alongside it.

Six cars can be dragged from the shop onto a train. Each has a `TowerData` resource
(`resources/*.tres`) carrying its cost, a one-line shop summary, and a `weight` — see
[Train weight and momentum](#train-weight-and-momentum) for what weight does. Four are
combat cars (they extend `scripts/turret.gd` or reimplement its targeting loop);
Passenger Coach, Brake Van, and Tender are non-combat utility cars.

| Car | Cost | Weight | Rate of fire | Range | Damage |
|---|---:|---:|---:|---:|---|
| Gunner Car | 150 | 150 | 0.45/s (≈2.2s) | 315 | 1 direct, single target |
| Chaingunner Car | 275 | 200 | 0.25/s (4s), 7-shot burst | 315 | 1 per pellet (7/burst) |
| Ballast Blaster | 200 | 200 | 0.45/s (≈2.2s) | 135 | 2 to every target in range |
| Coal Cannon | 300 | 225 | 0.22/s (≈4.5s) | 225 | 3 direct + 1 splash |
| Passenger Coach | 50 | 125 | — | — | none — generates Delta |
| Brake Van | 250 | 0 | — | — | none — caps train, buffs it |
| Tender | 50 | 50 | — | — | none — +500 capacity behind the engine |

Range is the infowiki cards' `NxN` grid notation converted to the shipped world-unit
radius as `radius = (N / 2) * path_step` (`path_step = 65.5`) — this conversion factor
isn't stated on the cards themselves, so treat it as a judgment call, not a recovered
fact. All four combat cars fire a homing projectile that flies at a fixed speed toward
its locked target's current position each frame (Gunner Car 900 u/s, Chaingunner Car
1050 u/s, Coal Cannon's cannonball 480 u/s); Ballast Blaster instead hits everyone
already inside its own short range directly, with no travelling projectile.

**Gunner Car** (`scripts/turret.gd`, `scenes/Turret.tscn`) — the baseline single-target
car every other combat car's turret behavior is built on: acquire the nearest enemy
overlapping its `TargetingArea`, rotate to face it, fire on a timer.

**Chaingunner Car** (`scripts/turret_minigun.gd`, extends Turret — filenames kept as
Minigun, its earlier working name, per its infowiki card) — overrides `_shoot()` to
fire a 7-bullet spread (`BURST_SIZE = 7`) in one burst every 4 seconds instead of the
base single-shot timer, each bullet dealing the normal 1 damage.

**Ballast Blaster** (`scripts/turret_ballast.gd`, extends Turret) — overrides
`_shoot()` entirely: instead of spawning a projectile, it deals a flat
`BLAST_DAMAGE = 2` to every body currently inside its 135-unit `TargetingArea`, with a
five-chunk ballast-debris visual spray toward the original target. Effectively a
short-range shotgun that hits a cluster rather than one target.

**Coal Cannon** (`scripts/turret_coal_cannon.gd` + `scripts/coal_cannonball.gd`) — the
slowest-firing car (≈4.5s between shots). Its cannonball deals `direct_damage = 3` to
whatever it hits, then queries the physics space for every other enemy within
`splash_radius = 140` world units of the impact point and deals `splash_damage = 1` to
each of them.

**Passenger Coach** (`scripts/passenger_coach.gd`) — no weapon and no targeting. While
attached and visible, it accumulates delta time and calls
`LevelManager.increase_currency(32)` every `income_interval = 8` seconds, with a
floating `+Δ32` popup on each payout.

**Brake Van** (`scripts/brake_van.gd`) — no weapon. `weight = 0.0`, so it never counts
toward its train's carry capacity. The moment one is attached, `TrainConvoy.attach_car()`
sets that train's `capped` flag, which makes both `can_attach_at()` and the drop
handler refuse any further car for that train; applies `attack_speed_bonus = 1.2`
to every other car currently on it by writing directly to each car's
`attack_speed_multiplier` (read by `Turret`'s fire-rate check as
`bps * attack_speed_multiplier`); and improves braking by 15%
(`brake_time_multiplier`) for as long as it's attached. Removing the Brake Van
clears the cap and resets every other car's attack and braking multipliers.

**Tender** (`scripts/tender.gd`) — no weapon. Adds its own 50 weight like any other
car, but `TrainConvoy.effective_capacity()` also checks whether it's specifically
`followers[0]` — coupled directly behind the engine — and only then grants its card's
+500 capacity bonus. A Tender anywhere else in the train has no special effect.

## Train weight and momentum

Every train is one `TrainConvoy` instance (`scripts/train_convoy.gd`) with its own
engine and its own attached cars — see [Multiple trains](#multiple-trains) below for
how many exist. Weight follows the infowiki Steam Engine card's (#001) **Carry
Capacity** model — a hard budget, not the soft speed-penalty threshold this section
used to describe. A train's total weight is the sum of every attached car's `weight`
(all matching their infowiki cards now — see [Placeable cars](#placeable-cars)).

| Parameter | Default |
|---|---:|
| Cruise / boosted max speed | 46 / 82 world units/second |
| Carry capacity | 1000 |
| Tender capacity bonus (directly behind the engine only) | +500 |
| Forward acceleration | 28 world units/second² |
| Reverse acceleration | 28 world units/second² |
| Deceleration | 34 world units/second² |
| Brake Van braking multiplier | ×0.85 time factor |
| Car spacing | 94 world units |
| Minimum consist clearance | 64 world units |
| Attachment radius | 76 world units |

`TrainConvoy.attach_car()` checks `total_weight() + new_car.weight` against
`effective_capacity()` (1000, or 1500 with a Tender coupled as `followers[0]`)
*before* appending the car, and simply returns `false` — refusing the attachment
entirely, refunding its cost — if it would exceed capacity. There is no partial
weight penalty. Each train cruises automatically and can be selected to open a
custom-drawn locomotive control stand. Its REV/N/FWD reverser is separate from the
six-position BRAKE/COAST/POWER 1/POWER 2/POWER 3/FULL throttle. BRAKE targets zero,
COAST restores automatic cruise, and the four power steps interpolate from cruise
to configured maximum speed in the requested direction. Signed speed still uses
separate acceleration, deceleration and reverse-acceleration values; an opposite
direction always brakes through zero instead of flipping instantly. The stand reads
actual velocity for its speed bars and movement-direction lamp, independently of
the requested controls.

Gubgub's latest **documented** direction differs from that implementation. The full
control stand obscures combat at the bottom of the board and should be condensed;
the suggested input is Up to increase forward speed and Down for reverse. Manual
engine control is meant primarily to exceed normal cruise speed. An engine should
be able to slow dramatically but probably never stop completely, because parking a
train in one ideal position undermines the movement strategy. Both the control
scheme and exact minimum/maximum speeds still require a final specification.

Cars don't have independent physics. The engine and every car sample the closed
route at fixed distance offsets. Before advancing, the convoy validates all sampled
positions against `occupancy_distance`; it stops before self-overlap and refuses an
attachment whose tail would wrap into the engine. `occupancy_debug` draws the tested
clearance circles for route tuning.

## Multiple trains

`main.gd` generates `starting_trains` (2–4, default 2) separate routes and spawns one
`TrainConvoy` per route. Each receives a randomly selected authored engine livery
without replacement, so they're never visually ambiguous even bare. Track generation
retries up to `max_generation_attempts` (default 6) times until it produces at least
two usable, fully connected routes that between them cover every spider lane; a
`push_error` makes a failed generation loudly visible in testing rather than shipping
a broken board silently. Only the first train starts with one free car (a Gunner);
every other train opens as a bare engine. Dropping a shop car targets whichever
train's attachment radius is nearest the drop point and isn't capped — see
`_find_attachable_convoy()`. Active drag motion and release are handled before UI
controls can consume the event, making drops reliable across the full viewport.

Campaign levels are deterministic rather than procedurally placed. The ten supplied
red-line track reference sheets have been transcribed onto the live 9×12 grid in
`TrackRenderer.generate_campaign_layout()`. The seven current stops deliberately
progress through simple paired rectangles, three-loop boards, stacked and nested
loops, four independent circuits, offset irregular circuits, and finally the dense
outer-and-comb layout. Each closed circuit receives one train. The post-campaign
**Open Rails** level keeps calling `generate_layout()`, so the existing automatic
track generator remains playable and available for later modes.

The acquisition model is implemented: campaign levels grant one starting engine,
and a locomotive can be dragged from the Train Yard onto an empty rail stretch for
Δ325. Each purchased engine is an independent train that can be selected and driven.

## Documented combat movement direction

Gubgub considers the current swivelling armed cars outdated. Future conventional
shooting cars should fire in one fixed direction, giving the player a reason to move
and orient engines around the board. Revised unit drawings are pending, so the
current rotating-turret implementation remains an intentional placeholder.

Ordinary trains should not deal collision damage. A spider threatened by a normal-
speed train moves one tile backward or sideways before impact. A distinct future
engine concept may carry only one car and travel fast enough to damage spiders by
ramming; it has no finished assets or detailed stats.

A planned **Barrier Car** is a heavy, two-tile-long divider that behaves as a wall.
If a train blocks a spider and no route around it exists within three blocks, the
spider attacks the train by biting it; enough damage destroys an individual car.
Health, bite cadence, path-search interpretation, placement restrictions, and what
happens to a consist after a middle car is destroyed remain unspecified.

## Removing cars

Pressing REMOVE arms a one-shot "click a car" mode (the arm is deferred by one frame
so the button's own click can't immediately count as the car click). The next
left-click anywhere is checked against every train's attached cars; whichever one is
within `attachment_radius` of the click is detached. Because every car's position is
always resampled from its train's route-distance offsets rather than stored independently,
removing a car from the middle of a train doesn't need any special "reconnect"
logic — the cars behind it are simply resampled at their new route-distance next
frame, which is now a shorter physical gap, so they visually snap forward on their
own. Removing a Brake Van clears its train's cap and resets the attack-speed bonus it
had granted.

## Enemies and route

### Enemy roster

The campaign now introduces the complete supplied spider-art roster. All archetypes
share lane movement, collision, slowing, hit feedback, and death handling, but have
distinct authored stats and abilities:

| Enemy | Campaign introduction | Base HP | Speed | Role and ability |
|---|---:|---:|---:|---|
| Dotted Spider | 1 | 5–15 | ×1.00 | Baseline enemy; transforms through the supplied one-to-six-dot art every two HP |
| Baby Spider | 2 | 3 | ×1.45 | Small, fragile rush enemy |
| Charger | 2 | 7 | ×1.00 | Periodically charges at ×2.10 speed |
| Rally Spider | 3 | 8 | ×0.85 | Gives nearby spiders a short ×1.25 movement boost |
| Roller | 4 | 10 | ×1.15 | Armoured; completely blocks every third incoming hit |
| Sturdy Spider | 4 | 16 | ×0.62 | Large, slow health tank |
| Wolf Spider | 5 | 12 | ×1.05 | Enrages below half HP, swaps to angry art, and moves ×1.55 faster |
| Jump Spider | 6 | 10 | ×1.10 | Periodically jumps, moving ×1.80 faster and evading damage while airborne |
| Spider Egg | 7 | 18 | ×0.48 | Slow shell that breaks at half HP and hatches into a fast Baby form |

The selection pool is weighted toward the baseline spider and unlocks by campaign
level. This keeps the first level readable and adds counters gradually rather than
placing every special enemy into the opening wave.

### Specialist counterplay

| Threat | Readable tell | Available counterplay |
|---|---|---|
| Baby / Charger | Small fast body; Charger shows speed streaks before its burst | Broad route coverage, Chaingunner bursts, and short-range Ballast groups |
| Rally | Green circular aura | Prioritize the Rally spider with direct fire or splash clustered followers |
| Roller | `BLOCK` appears every third hit | Coal Cannon's heavy hit and Ballast group damage reduce wasted pellet cadence |
| Sturdy | Large slow body | Concentrated Gunner/Coal fire; low speed gives more circuit passes |
| Wolf | Angry artwork below half HP | Burst damage around enrage; manage engine speed to retain coverage |
| Jump | Enlarged jump state and `BLOCK` on airborne hits | Sustained or burst fire resumes when its short jump ends |
| Egg | Break frame at half HP, followed by fast Baby animation | Focus it before hatching or maintain downstream rapid-fire coverage |

Every specialist enters after the baseline Gunner is taught, while campaign car
unlocks progressively add burst, area, splash, economy, and capacity options.

The active generic spider has 15 HP and a bounty of 25 (see the Economy table above —
this is deliberately lower than Passenger Coach's passive income). Its unslowed speed is derived
from the configured lane length so it takes about 25 seconds to travel from spawn to the station,
and therefore remains stable when a larger board changes those coordinates.

Spider durability is also the wave difficulty ladder. Wave 1 starts with the one-dot,
5 HP form; waves 2–6 introduce 7, 9, 11, 13, and 15 HP forms respectively. Wave 6+
uses the full six-dot spider. During combat one dot disappears after each pair of
one-damage hits until the final one-dot form, which takes five hits to kill. Each
stage change has a short squash and paper-puff transformation beat.
It uses one 1500×1500 source frame at a normalized visual scale rather than the
combined 3000×1500 sheet. Each spawn is assigned uniformly to one of nine fixed
columns on the new 9×12 courtyard and travels straight from the top to the bottom,
following a Plants-vs.-Zombies-style lane model. Reaching the station changes it to
a persistent attack state. It stops, remains targetable, and deals one station damage
every 2.25 seconds after a 0.55-second windup. It counts as alive until killed, so a
wave cannot clear while attackers remain at the station. Station HP defaults to 60.

## Waves

| Parameter | Default |
|---|---:|
| First wave | 1 |
| Base enemies | 3 |
| Base spawn rate | 0.4/second |
| Station/build interval | 45 seconds |
| Count exponent | 1.15 |
| Spawn-rate exponent | 0.75 |
| Spawn-rate cap | 15/second |

For wave `W`:

```text
enemy count = 3 + round(2 × max(W - 1, 0)^1.15)
spawn rate  = min(0.4 × W^0.75, 15) enemies/second
```

| Wave | Enemies | Spawn rate/sec |
|---:|---:|---:|
| 1 | 3 | 0.40 |
| 2 | 5 | 0.67 |
| 3 | 7 | 0.91 |
| 4 | 10 | 1.13 |
| 5 | 13 | 1.34 |
| 6 | 16 | 1.53 |
| 7 | 19 | 1.72 |
| 8 | 22 | 1.90 |
| 9 | 25 | 2.08 |
| 10 | 28 | 2.25 |

Enemy archetypes come from the campaign-unlocked weighted roster. In debug builds,
F8 starts wave 10 when the spawner is idle. Completed waves print `WAVE TELEMETRY`
with starting/ending Delta, income, spending, net change, and kills.

## Provenance

These formulas originated in the archived Unity scripts and were carried into the
Godot port. Scene values can override script defaults; this page records the effective
checked-in configuration where one exists.
