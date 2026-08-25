# Systems and Balance

[Wiki home](README.md)

Values on this page are **implemented defaults** from the active GDScript and scenes,
not claims of final balance.

## Economy

| Parameter | Default |
|---|---:|
| Starting currency | 100 |
| Generic spider bounty | 50 |
| Turret base upgrade cost | 100 |

Building spends the selected `TowerData.cost`; no tower price is currently checked
into the global catalog. Currency has no other sink or source.

The cost shown before upgrading from current level `L` is:

```text
upgrade cost = round(100 × L^0.8)
```

The level increments after payment. Approximate next-upgrade costs at levels 1–5 are
100, 174, 241, 303, and 362.

## Standard turret

| Parameter | Default |
|---|---:|
| Bullets per second | 1.0 |
| Script targeting range | 5.0 |
| Scene detection radius | 80 pixels |
| Rotation speed | 5 radians/second in the Godot port |
| Bullet damage | 1 |
| Bullet speed | 5 pixels/second |

The script's range check and the physics detection circle use different values. With
defaults unchanged, a target detected inside the 80-pixel area will be discarded
unless it is also within 5 pixels. This unit mismatch is a likely porting bug and
should be resolved before balance work.

At level `L`, stats are recalculated from their level-one base values:

```text
bullets per second = base BPS × L^0.6
targeting range    = base range × L^0.4
```

For base values 1 BPS and range 5, levels 1–5 yield approximately:

| Level | BPS | Range |
|---:|---:|---:|
| 1 | 1.00 | 5.00 |
| 2 | 1.52 | 6.60 |
| 3 | 1.93 | 7.76 |
| 4 | 2.30 | 8.71 |
| 5 | 2.63 | 9.52 |

## Slow defense

The white-engine defense pulses every four seconds (`0.25` pulses/second). Every
overlapping enemy is assigned speed `0.5` for one second, then reset to its original
speed. It deals no damage and has no upgrade path or defined shop price.

## Enemies and route

The active generic spider has 2 HP, speed 1, and a bounty of 50. It follows five
markers in scene-tree order. Reaching the last marker removes the spider and counts it
as cleared for wave progression, but does not award currency or damage a base.

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
