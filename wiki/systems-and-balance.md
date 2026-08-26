# Systems and Balance

[Wiki home](README.md)

Values on this page are **implemented defaults** from the active GDScript and scenes,
not claims of final balance.

## Economy

| Parameter | Default |
|---|---:|
| Starting currency | 100 |
| Generic spider bounty | 50 |
| Gunner price | 50 |
| Slomo Turret price | 75 |
| Turret base upgrade cost | 100 |

Dropping a shop train on a valid rail spends its `TowerData.cost`. Invalid or
off-track drops spend nothing. Currency has no other sink or source.

The cost shown before upgrading from current level `L` is:

```text
upgrade cost = round(100 × L^0.8)
```

The level increments after payment. Approximate next-upgrade costs at levels 1–5 are
100, 174, 241, 303, and 362.

## Standard turret

| Parameter | Default |
|---|---:|
| Bullets per second | 0.45 |
| Effective targeting range | 360 world units |
| Scene detection radius | 360 world units |
| Rotation speed | 5 radians/second in the Godot port |
| Bullet damage | 1 |
| Bullet speed | 900 world units/second |

The active scene overrides the inherited Unity-scale script defaults. Its scripted
range check and physics detection circle now use the same 360-unit radius.

At level `L`, stats are recalculated from their level-one base values:

```text
bullets per second = base BPS × L^0.6
targeting range    = base range × L^0.4
```

For the active base values of 0.45 BPS and range 360, levels 1–5 yield approximately:

| Level | BPS | Range |
|---:|---:|---:|
| 1 | 0.45 | 360 |
| 2 | 0.68 | 475 |
| 3 | 0.87 | 559 |
| 4 | 1.03 | 627 |
| 5 | 1.18 | 685 |

## Slow defense

The white-engine defense costs 75 and pulses every four seconds (`0.25`
pulses/second). Every overlapping enemy is slowed to half its own base speed for one
second. Repeated pulses extend the expiry instead of racing reset timers. It deals no
damage and has no upgrade path.

## Train deployment and patrol

The black steam engine spawns automatically and leads the player's single convoy.
Gunner, Slomo, Minigun, and Ballast Blaster are trailing cars rather than independent towers. Each run builds
one connected serpentine railway inside the central courtyard. It has five
horizontal sweeps, including a central sweep, joined by alternating edge
connectors and curved track pieces. Every sweep crosses all seven spider lanes, so a
Gunner in the consist can eventually cover every lane. Shop cars may only be dropped
within 90 world units of the engine or an attached car. A valid car is appended to the
tail at 170-world-unit spacing. Cars sample the engine's movement history, creating
Snake-like following through turns and reversals. A newly bought car remains pending
until enough unique route history exists for its tail position, preventing cars from
sharing the oldest recorded point. The convoy travels at 95 world units/second.

## Enemies and route

The active generic spider has 15 HP and a bounty of 50. Its unslowed speed is derived
from the configured lane length so it takes 25 seconds to travel from spawn to leak,
and therefore remains stable when a larger board changes those coordinates.

Spider durability is shown as staged red body dots: 15–14 HP has six dots, then one
dot disappears after each pair of hits at 13, 11, 9, 7, and 5 HP. The final one-dot
form takes five more one-damage hits to kill. Each stage change has a short squash and
paper-puff transformation beat.
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
