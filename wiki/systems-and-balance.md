# Systems and Balance

[Wiki home](README.md)

Values on this page are **implemented defaults** from the active GDScript and scenes,
not claims of final balance.

## Economy

| Parameter | Default |
|---|---:|
| Starting currency | 300 |
| Generic spider bounty | 25 |

Dropping a shop car on a valid rail spends its `TowerData.cost`. Invalid or
off-track drops spend nothing. There is no upgrade system — cars are bought once at a
fixed cost and either sit in the train or get removed via the REMOVE button; see
[Removing cars](#removing-cars) below. Currency's only sinks are car purchases; its
only sources are spider bounties and Passenger Coach income.

## Placeable cars

An authoritative design source for these seven cars' intended cost, range, weight, and
role exists at [Infowiki unit cards](infowiki-cards.md) — it disagrees with nearly
every number below and describes an eighth car (Tender) that isn't implemented at all.
This section documents what actually ships; that page documents what was designed.

Seven cars can be dragged from the shop onto a train. Each has a `TowerData` resource
(`resources/*.tres`) carrying its cost, a one-line shop summary, and a `weight` — see
[Train weight and momentum](#train-weight-and-momentum) for what weight does. Five are
combat cars (they extend `scripts/turret.gd` or reimplement its targeting loop);
Passenger Coach and Brake Van are non-combat utility cars.

| Car | Cost | Weight | Rate of fire | Range | Damage |
|---|---:|---:|---:|---:|---|
| Gunner | 50 | 1.0 | 0.45/s (≈2.2s) | 360 | 1 direct, single target |
| Slomo | 75 | 1.0 | 0.25/s (4s pulse) | 360 | none — slows instead |
| Minigun | 125 | 1.0 | 0.33/s (3s), 5-shot burst | 330 | 1 per pellet (5/burst) |
| Ballast Blaster | 100 | 1.0 | 0.45/s (≈2.2s) | 190 | 2 to every target in range |
| Coal Cannon | 150 | 2.0 | 0.22/s (≈4.5s) | 340 | 3 direct + 1 splash |
| Passenger Coach | 90 | 1.0 | — | — | none — generates income |
| Brake Van | 60 | 0.0 | — | — | none — caps train, buffs it |

All five combat cars fire a homing projectile that flies at a fixed speed toward its
locked target's current position each frame (Gunner 900 u/s, Minigun 1050 u/s, Coal
Cannon's cannonball 480 u/s); Ballast Blaster instead hits everyone already inside its
own short range directly, with no travelling projectile.

**Gunner** (`scripts/turret.gd`, `scenes/Turret.tscn`) — the baseline single-target
car every other combat car's turret behavior is built on: acquire the nearest enemy
overlapping its `TargetingArea`, rotate to face it, fire on a timer.

**Slomo** (`scripts/turret_slomo.gd`) — deals no damage. Every 4 seconds it pulses its
360-unit range and calls `apply_slow()` on every enemy caught inside, halving that
enemy's speed for 1 second. A second pulse while already slowed only extends the
expiry timestamp rather than restarting a separate timer, so overlapping Slomo cars
can't stack multiplicatively.

**Minigun** (`scripts/turret_minigun.gd`, extends Turret) — overrides `_shoot()` to
fire a 5-bullet spread (`BURST_SIZE = 5`) in one burst every 3 seconds instead of the
base single-shot timer, each bullet dealing the normal 1 damage.

**Ballast Blaster** (`scripts/turret_ballast.gd`, extends Turret) — overrides
`_shoot()` entirely: instead of spawning a projectile, it deals a flat
`BLAST_DAMAGE = 2` to every body currently inside its 190-unit `TargetingArea`, with a
five-chunk ballast-debris visual spray toward the original target. Effectively a
short-range shotgun that hits a cluster rather than one target.

**Coal Cannon** (`scripts/turret_coal_cannon.gd` + `scripts/coal_cannonball.gd`) — the
slowest-firing car (≈4.5s between shots). Its cannonball deals `direct_damage = 3` to
whatever it hits, then queries the physics space for every other enemy within
`splash_radius = 140` world units of the impact point and deals `splash_damage = 1` to
each of them.

**Passenger Coach** (`scripts/passenger_coach.gd`) — no weapon and no targeting. While
attached and visible, it accumulates delta time and calls
`LevelManager.increase_currency(50)` every `income_interval = 10` seconds, with a
floating `+$50` popup on each payout.

**Brake Van** (`scripts/brake_van.gd`) — no weapon. `weight = 0.0`, so it never counts
toward its train's weight total. The moment one is attached, `TrainConvoy.attach_car()`
sets that train's `capped` flag, which makes both `can_attach_at()` and the drop
handler refuse any further car for that train, and applies `attack_speed_bonus = 1.2`
to every other car currently on it by writing directly to each car's
`attack_speed_multiplier` (read by `Turret`/`TurretSlomo`'s fire-rate check as
`bps * attack_speed_multiplier`). Removing the Brake Van clears the cap and resets
every other car's multiplier back to 1.0.

## Train weight and momentum

Every train is one `TrainConvoy` instance (`scripts/train_convoy.gd`) with its own
engine and its own attached cars — see [Multiple trains](#multiple-trains) below for
how many exist. A train's total weight is the sum of every attached car's `weight`
(Brake Van excluded by its own 0.0 weight, everything else defaults to 1.0 unless
overridden — only Coal Cannon does, at 2.0).

| Parameter | Default |
|---|---:|
| Max speed | 95 world units/second |
| Weight threshold | 5.0 |
| Base acceleration time (0 → max) | 2.0 seconds |
| Base coast-to-stop time | 5.0 seconds |
| Car spacing | 170 world units |
| Attachment radius | 115 world units |

Speed above the threshold is reduced 25% per weight-unit over, floored at 10% of max
so a train never fully stalls:

```text
over = max(0, total_weight − 5.0)
target speed = 95 × clamp(1 − 0.25 × over, 0.1, 1.0)
```

A 7-weight train (for example: Gunner + Coal Cannon + Ballast + Slomo + Minigun, one
Brake Van) sits at `over = 2`, target speed `95 × 0.5 = 47.5` — confirmed against the
live build during testing. The engine doesn't snap to that target: `current_speed`
eases toward it every frame, using the acceleration-time constant while speeding up or
the coast-time constant while slowing down, both stretched by `+0.5s × over` — so a
heavier train is both slower at cruise and sluggish to change speed. The engine also
hard-resets to 0 speed at each end-of-route reversal and has to build back up, rather
than instantly reversing at full pace.

Cars don't have independent physics — each one samples the engine's own recent
movement history at `car_spacing × its index` behind the front, which is what
produces the snake-like following through turns. A newly bought car stays invisible
and unprocessed until the engine has moved far enough to have recorded a unique tail
position for it.

## Multiple trains

`main.gd` generates `starting_trains` (2–4, default 2) separate routes and spawns one
`TrainConvoy` per route, each tinted a distinct engine color (white, light blue,
orange, purple) so they're never visually ambiguous even bare. Track generation
retries up to `max_generation_attempts` (default 6) times until it produces at least
two usable, fully connected routes that between them cover every spider lane; a
`push_error` makes a failed generation loudly visible in testing rather than shipping
a broken board silently. Only the first train starts with one free car (a Gunner);
every other train opens as a bare engine. Dropping a shop car targets whichever
train's attachment radius is nearest the drop point and isn't capped — see
`_find_attachable_convoy()`.

## Removing cars

Pressing REMOVE arms a one-shot "click a car" mode (the arm is deferred by one frame
so the button's own click can't immediately count as the car click). The next
left-click anywhere is checked against every train's attached cars; whichever one is
within `attachment_radius` of the click is detached. Because every car's position is
always resampled from its train's movement history rather than stored independently,
removing a car from the middle of a train doesn't need any special "reconnect"
logic — the cars behind it are simply resampled at their same history-distance next
frame, which is now a shorter physical gap, so they visually snap forward on their
own. Removing a Brake Van clears its train's cap and resets the attack-speed bonus it
had granted.

## Enemies and route

The active generic spider has 15 HP and a bounty of 25 (see the Economy table above —
this is deliberately lower than Passenger Coach's passive income). Its unslowed speed is derived
from the configured lane length so it takes 25 seconds to travel from spawn to leak,
and therefore remains stable when a larger board changes those coordinates.

Spider durability is also the wave difficulty ladder. Wave 1 starts with the one-dot,
5 HP form; waves 2–6 introduce 7, 9, 11, 13, and 15 HP forms respectively. Wave 6+
uses the full six-dot spider. During combat one dot disappears after each pair of
one-damage hits until the final one-dot form, which takes five hits to kill. Each
stage change has a short squash and paper-puff transformation beat.
It uses one 1500×1500 source frame at a normalized visual scale rather than the
combined 3000×1500 sheet. Each spawn is assigned uniformly to one of seven fixed
columns and travels straight from the top to the bottom of the courtyard, following
a Plants-vs.-Zombies-style lane model. Reaching the bottom removes the spider, counts
it as cleared for wave progression, awards no currency, and damages the station by
one health.

## Waves

| Parameter | Default |
|---|---:|
| First wave | 1 |
| Base enemies | 8 |
| Base spawn rate | 0.5/second |
| Delay between waves | 5 seconds |
| Scaling exponent | 0.75 |
| Spawn-rate cap | 15/second |

For wave `W`:

```text
enemy count = round(8 × W^0.75)
spawn rate  = min(0.5 × W^0.75, 15) enemies/second
```

| Wave | Enemies | Spawn rate/sec |
|---:|---:|---:|
| 1 | 8 | 0.50 |
| 2 | 13 | 0.84 |
| 5 | 27 | 1.67 |
| 10 | 45 | 2.81 |
| 20 | 76 | 4.73 |

Enemy scenes are selected uniformly at random from the configured prefab array. Only
the generic enemy is configured today.

## Provenance

These formulas originated in the archived Unity scripts and were carried into the
Godot port. Scene values can override script defaults; this page records the effective
checked-in configuration where one exists.
