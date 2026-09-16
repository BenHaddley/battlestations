# Systems and Balance

[Wiki home](README.md)

The [September 10 playtest revision](sources/2026-09-10-playtest-revision.md) supersedes earlier inferred rules. STATIONS trains stop unless selected and manually piloted. BUILD TRACK hides trains and holds both automatic and manual departure until finished. The upgrade tree is removed. Mail Carrier fires at 2.625/s (12.5% slower), and all car colors remain artist-authored. Engine and chassis artwork is normalized to a 56-unit visible footprint inside a 65.5-unit tile.

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
| Generic bounty (including waves 1–3) | 12 |
| Specialist bounty | 8–38, with no campaign-level multiplier |
| Roller egg / hatched baby | 0 / 2 (four babies per egg) |
| Passenger Coach income | 32 every 8 seconds while coupled |
| Wave completion bonus | 35 + 12 × wave number |
| Rail tile (STATIONS only) | 50, refunded in full when lifted |
| Locomotive, or recovering a wrecked engine | 250 |

Dropping a shop car on a valid rail spends its `TowerData.cost`, but only after
`TrainConvoy.attach_car()` also confirms the target train has capacity — see
[Train weight and momentum](#train-weight-and-momentum). Invalid, off-track, or
over-capacity drops spend nothing. Coupled cars can also be selected for the active
information/sell panel. Currency sinks are purchases, locomotives, and rail
tiles; its only sources are spider bounties, wave-completion bonuses, Passenger Coach
income, and rail refunds.

### Documented balance direction

Gubgub's 2026-08-28 playtest found that spider bounties make Delta excessively
abundant in larger waves, eventually making car prices inconsequential. The intended
retune is to reduce kill income and make the player rely more heavily on Passenger
Coach income. Exact replacement values have not been supplied, so the implemented
values are an intentional first playtest baseline, not recovered canon or final approval.

## Placeable cars

The [September 16 reconciliation](sources/2026-09-16-roadmap-verification.md)
adopts the workbook's explicit costs, weights and Steam Engine capacity. Earlier
infowiki behavior remains where the workbook is silent; the September 10 playtest
revision retains precedence for combat behavior. These are implemented starting
values for playtesting, not a claim of final balance.

Eight cars can be dragged from the shop onto a train. Each has a `TowerData` resource
(`resources/*.tres`) carrying its cost, a one-line shop summary, and a `weight` — see
[Train weight and momentum](#train-weight-and-momentum) for what weight does. Five are
combat cars (they extend `scripts/turret.gd` or reimplement its targeting loop);
Passenger Coach, Brake Van, and Tender are non-combat utility cars.

| Car | Cost | Weight | Health | Rate of fire | Range | Damage |
|---|---:|---:|---:|---:|---:|---|
| Gunner Car | 150 | 150 | 200 | 0.45/s (≈2.2s) | 315 | 20 direct, single target |
| Chaingunner Car | 225 | 200 | 200 | 0.25/s (4s), 7-shot burst | 315 | 4 per pellet (7/burst) |
| Ballast Blaster | 200 | 175 | 200 | 0.45/s (≈2.2s) | 135 | 8 to every target in range |
| Coal Cannon | 300 | 225 | 225 | 0.22/s (≈4.5s) | 225 | 12 direct + 4 splash, knockback |
| Mail Carrier | 125 | 125 | 150 | 2.625/s | 225 | 4 per envelope, random recipient each shot |
| Passenger Coach | 100 | 125 | 175 | — | — | none — generates Delta |
| Brake Van | 175 | 0 | 200 | — | — | none — caps train, buffs it |
| Tender | 75 | 50 | 125 | — | — | none — +500 capacity behind the engine |

Health is the [asset workbook](asset-workbook.md) Health column, carried on each
`TowerData` (`health`) and installed on the coupled car by `UnitHealth`
(`scripts/unit_health.gd`); the Steam Engine's 300 lives in `game_balance.tres`. See
[Train damage](#train-damage-avoidance-biting-ramming-and-wrecks) for what wears it
down. Cost and weight now use the workbook wherever it gives a number. Tender weight
remains 50 and its carry bonus remains +500 because the workbook gives neither.

Range is the infowiki cards' `NxN` grid notation converted to the shipped world-unit
radius as `radius = (N / 2) * path_step` (`path_step = 65.5`) — this conversion factor
isn't stated on the cards themselves, so treat it as a judgment call, not a recovered
fact. Acquisition now measures that radius directly from the car (workbook priority
**Close**: the nearest live spider inside it). It previously used the car's physics
`TargetingArea`, which the placed car's 0.54 root scale shrank to roughly half the
documented radius, so guns acquired much later than their cards claimed. Placement
ghosts, the hovered-car ring and the information card all draw this same radius, and none
is drawn for a utility car. All four projectile cars fire a homing projectile toward
their locked target's current position each frame (Gunner Car 6000 u/s swept,
Chaingunner Car 1050 u/s, Coal Cannon's cannonball 480 u/s); Ballast Blaster instead
hits everyone already inside its own short range directly, with no travelling projectile.

**Gunner Car** (`scripts/turret.gd`, `scenes/Turret.tscn`) — the baseline single-target
car every other combat car's turret behavior is built on: acquire the nearest spider
within `targeting_range`, rotate to face it, fire on a timer.

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
handler refuse any further car for that train. It applies a non-stacking 1.25×
damage multiplier to all five attacking cars, including Coal Cannon direct and
splash damage and Ballast area damage. Projectile damage is rounded to the nearest
integer. Cadence is unchanged. The existing 15% braking-time reduction remains.
Removing or destroying the Brake Van clears its damage and braking bonuses and
uncaps the train; a car's own damage modifier is preserved.

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
| Carry capacity | 1200 |
| Tender capacity bonus (directly behind the engine only) | +500 |
| Forward acceleration | 28 world units/second² |
| Reverse acceleration | 28 world units/second² |
| Deceleration | 34 world units/second² |
| Brake Van braking multiplier | ×0.85 time factor |
| Car spacing | 88 world units |
| Minimum consist clearance | 64 world units |
| Attachment radius | 76 world units |

`TrainConvoy.attach_car()` checks `total_weight() + new_car.weight` against
`effective_capacity()` (1200, or 1700 with a Tender coupled as `followers[0]`)
*before* appending the car, and simply returns `false` — refusing the attachment
entirely, refunding its cost — if it would exceed capacity. There is no partial
weight penalty. During STATIONS a train is parked unless the player selects it
and holds Up/W (forward) or Down/S (reverse). Releasing the key parks it again.
During BATTLE it cruises automatically; Up boosts speed, a short Down slows it,
and holding Down reverses after braking. Only the selected train receives keyboard
commands. Its compact readout reports speed, capacity and health.

BUILD TRACK hides engines and cars, stops them, and holds departure until DONE
BUILDING. Hidden trains still occupy their rails, so construction cannot remove
track from underneath them.

Cars don't have independent physics. The engine and every car sample the closed
travelled rail tape at fixed distance offsets. Before advancing, the convoy validates the sampled
positions against `occupancy_distance`; it stops before self-overlap and refuses an
attachment whose tail would wrap into the engine. `occupancy_debug` draws the tested
clearance circles for route tuning.

That check deliberately **skips neighbouring vehicles**. Two cars either side of a
90° corner are closer in a straight line than their spacing along the rail — at
`car_spacing` 88 the gap falls to `√(44² + 44²) ≈ 62`, under the 64 clearance — but
that distance is a property of the corner, not a collision movement could avoid.
Rejecting it made the consist declare itself blocked, zero its speed and freeze for
the rest of the level. Only vehicles two or more apart in the consist are checked,
which is the case the guard exists for: a tail wrapping round a short loop into the
engine. The earlier 94 spacing cleared the same corner by 2.5 units, so this was
always latent rather than introduced by tightening the spacing.

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
Δ250. Each purchased engine is an independent train that can be selected and driven.
Clicking an engine marks it with a ring and an `ENGINE n · weight / capacity` tag,
and the compact readout at the top of the board lists weight, capacity and engine HP;
all three refresh every frame, so coupling, selling, losing a Tender or taking bites
shows at once.

## Rail building during STATIONS

Implemented from the [2026-09-09 notes](sources/2026-09-09-rail-building-and-train-collision-notes.md)
in `scripts/rail_builder.gd` and `scripts/track_renderer.gd`. The notes settle the
gesture and the provisional price; the rules below for joining, rerouting, removal
and persistence are **proposed design**, recorded in [Open questions](open-questions.md)
until the designer confirms them.

| Rule | Implemented behaviour |
|---|---|
| When | STATION only. The plus signs, join markers and right-click removal vanish the moment a wave starts and return when it clears. |
| Laying | Hover any rail tile; plus signs appear on its empty orthogonal neighbours. A click lays one tile connected only to the tile you hovered, for **Δ50**, charged only after the tile exists. The hover stays anchored on the new tile so a run can be laid click by click. |
| Refusals | Insufficient Delta, a tile that already holds rail, a tile not touching the hovered rail, or a non-adjacent/already-connected join each produce a specific banner and change nothing. |
| Dead ends | A tile with one connection is drawn with the supplied `Rail End` buffer stop. Trains enter open spurs and engines may be placed on them. The leading end of the consist stops at the buffer, waits 0.65 seconds, then the whole consist reverses. |
| Joining | Hover either of two adjacent, unconnected rails to show a blue join ring between them. Clicking connects them for free, including two authored loops or a player-built bridge to another circuit. A gap must first be filled with new tiles (Δ50 each). Diagonal, distant and duplicate joins are refused. Live trains follow the joined graph; authored starting rings stay intact. |
| Rerouting | A join closes a cycle. If that cycle leaves a train's ring at one cell, returns at another, and its player-built part is longer than the stretch it bypasses, the ring adopts the detour and the bypassed stretch stays as a siding. Shortcuts, lobes that touch the ring at a single cell, and detours through sidings never change a route. |
| Navigation | Live trains retain a tape of the actual rail edges under their consist. New branches can be taken at junctions without rebinding a closed route. Facing eases across corners while positions remain on rails. |
| New engines | Drop an engine on any free connected rail edge, including an open spur. A closed circuit is not required. |
| Removing | Right-click a tile you laid to lift it for a full **Δ50** refund. Authored rail, rail a train is standing on, and any removal that would strand track or leave a ring with no way round are refused. Lifting any tile of an adopted detour drops the whole detour from the ring, restoring the original stretch; the other detour tiles remain as spurs. |
| Persistence | Built rail is run-local. It survives every wave of the level and is reset with the level whenever the scene reloads: restart, replay from Level Select, continuing a save, or the next campaign stop. |
| Art | Every cell is drawn from its connection set — straight, curve, buffer stop, and for junctions one piece per rail pair — so junctions and crossings refresh as soon as a neighbour changes. |

## Train damage: avoidance, biting, ramming and wrecks

Implemented from the same notes in `scripts/enemy_movement.gd`, `scripts/unit_health.gd`
and `scripts/train_convoy.gd`. The bite rate, ramming damage and recoil are the
notes' provisional figures; the tick, stacking, search-distance and destruction rules
are proposed design.

| Parameter | Default |
|---|---:|
| Bite damage | 25 per second per spider, applied every 0.25 s (6.25 per tick); several spiders stack linearly |
| Look-ahead | 130 units; contact 56 units; unit corridor half-width 34 units |
| Detour search | up to 3 lanes each side, nearest clear lane first, the side away from the unit tried first |
| Ramming damage | 20 (one Gunner bullet) per spider per unit, 2 s cooldown, only above 60% of cruise speed |
| Recoil | train speed cut to 35% and nudged 8 units back |
| Engine health | 300 |

- Every engine and coupled car is an obstacle. A spider that sees one ahead in its
  corridor first looks for a clear lane to its left or right and steps into it
  cardinally at a grid row, then continues down the new lane. Empty rail never blocks a spider.
- When no lane within reach is clear and the unit is in contact, the spider stops and
  bites, showing fangs toward its target; the bitten unit flashes, shows a jaws marker
  and a health bar. A bite pins the entire consist until its attackers are cleared or their target is destroyed.
- A spider whose target drives away, is destroyed or becomes a wreck resumes walking
  the next physics frame; a sidestep that cannot complete within 3 s is abandoned. A
  frozen spider therefore cannot hold a wave open.
- A destroyed car is removed and the consist closes the gap on its own. Whatever it
  gave — firepower, income, the Tender's capacity, the Brake Van's cap and buffs — goes
  with it. A train left over capacity keeps its cars but cannot couple more.
- A destroyed engine becomes a **wreck**: the train stops, its surviving cars keep
  firing where they stand, spiders walk past the rubble, and nothing can be coupled.
  Dropping a locomotive from the Train Yard onto the wreck (Δ250) restores full engine
  health and the train rolls again.
- Ramming is incidental: the per-spider cooldown and the recoil mean parking on a
  spider never out-damages a gun.

The planned **Barrier Car** (workbook health 1250, two tiles) is not implemented;
the obstacle rules above are what it would plug into.

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
| Charger | 2 | 7 | ×1.00 | Stampedes at ×2.10 until its first car impact: 250 damage and a full train stop, then normal movement |
| Rally Spider | 3 | wave baseline + 2 | ×1.15 | First spider of each wave after introduction; no aura or buff |
| Roller | 4 | 10 | ×1.15 | Pushes a separate egg one tile ahead; egg has targeting priority over the roller |
| Sturdy Spider | 4 | 16 | ×0.62 | Large, slow health tank |
| Wolf Spider | 5 | 12 | ×1.05 | Enrages below half HP, swaps to angry art, and moves ×1.55 faster |
| Jump Spider | 6 | 10 | ×1.10 | Hops two tiles in 0.75 seconds, clearing trains and evading airborne hits |
| Spider Egg | 4, with Roller | 18 | pusher speed | Destroying the shell releases four counted Baby Spiders; a surviving egg remains where its pusher dropped it |

The selection pool is weighted toward the baseline spider and unlocks by campaign
level. This keeps the first level readable and adds counters gradually rather than
placing every special enemy into the opening wave.

### Specialist counterplay

| Threat | Readable tell | Available counterplay |
|---|---|---|
| Baby / Charger | Small fast body; Charger shows speed streaks before its burst | Broad route coverage, Chaingunner bursts, and short-range Ballast groups |
| Rally | First in the wave | A slightly tougher, faster ordinary target |
| Roller | Visible egg ahead of the pusher | Break the egg, then clear its babies and the exposed roller |
| Sturdy | Large slow body | Concentrated Gunner/Coal fire; low speed gives more circuit passes |
| Wolf | Angry artwork below half HP | Burst damage around enrage; manage engine speed to retain coverage |
| Jump | Enlarged jump state and `BLOCK` on airborne hits | Sustained or burst fire resumes when its short jump ends |
| Egg | A separate shell one tile ahead of a Roller | Destroy it, then clear the four babies it releases |

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

### Station clock and the START WAVE control

`PhaseManager` runs the 45-second departure countdown only while nothing owns the
clock. Two holds exist: `paused` (set by the level-complete flow and Spider Assault,
which also disables the wave button) and `dialogue_hold` (set by Duck and Daisy while
a lesson or a STATION objective is open, which only stops the automatic countdown).
The button reads `START WAVE n` in every STATION window from the first wave onward,
`WAVE n UNDERWAY` during BATTLE, and `LEVEL COMPLETE` once the final wave clears;
`request_wave_start()` refuses a second press while a wave runs and refuses entirely
after the level is finished, so a wave can never start twice or underneath the
level-complete card. Up/Down/W/S drive trains only while the board is the active
surface: no HUD control can hold keyboard focus, and the arrow keys are consumed
before interface focus navigation whenever no card or dialogue is open.

## Duck and Daisy lessons

`scripts/tutorial_director.gd` keys every lesson and records completion per profile
in `tutorial.cfg`, so a fresh profile sees the opening again, a continued save is
introduced to every car it has unlocked, and a skipped lesson never nags twice.
Objectives highlight the control or unit involved (a pulsing frame around a shop row
or the START WAVE button, a ring around an engine or car, with an arrow from the
objective tag) and advance when the player performs the action. Guided tasks are set
only when the wallet, capacity and trains on the board allow them; otherwise the
lesson is information only. Lessons hold the departure clock but never remove the
player's START WAVE control: starting a wave over an open objective skips that lesson.
Battle events (first bite, first destroyed car, first wreck) are explained at the next
STATION rather than mid-wave. The pause card's **REPLAY DUCK & DAISY LESSONS** forgets
the profile's progress; New Game does the same.

| Lesson | When | Objective |
|---|---|---|
| Opening | Boiler Room, new profile or New Game | couple a Gunner, then START WAVE |
| Payout, driving, rails, car information | first STATION after a wave, once each | drive with Up/Down, lay a rail tile, open a car's information card |
| One per car (Gunner … Mail Carrier) | the first STATION on a level where it is unlocked | couple one, when affordable |
| Biting, destroyed car, wreck | first STATION after the event | none |
| Final wave, level ending | as before | none |

## Provenance

These formulas originated in the archived Unity scripts and were carried into the
Godot port. Scene values can override script defaults; this page records the effective
checked-in configuration where one exists.
