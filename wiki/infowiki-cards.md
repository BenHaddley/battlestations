# Infowiki Unit Cards

[Wiki home](README.md)

`assets/audio/infowiki/` (the folder name is misleading — these are images, not audio)
holds a set of trading-card-style unit spec sheets: `001_Steam_Engine.png` through
`007_Chaingun_Car.png`, then `012_Tender.png`. Cards 008–011 are missing from the
folder — not yet supplied, not lost from a larger set we know existed. Nothing in the
repository identifies an author; treat this as **Documented** per the
[confidence labels](README.md#confidence-labels) — a surviving design artifact, not
verified first-hand design intent.

**This is the authoritative unit design source.** The reconciliation this page used
to flag as an open question has been resolved — the shipped build now adopts these
cards' costs, weights, and (converted) ranges wholesale; see
[Divergence from the current build](#divergence-from-the-current-build) below for how
each gap was actually closed, and [Open questions](open-questions.md) for the decision
record.

## Card contents

Cost, Range, and Weight are transcribed exactly as printed, including the cards' own
`NxN` grid notation for range (not a world-unit radius) and their hundreds-scale Cost
and Weight (not the current build's tens-scale numbers). Bio text is verbatim,
including its typos.

### #001 — Steam Engine

| Cost | Range | Weight |
|---:|---:|---:|
| 250 | N/A | 300 |

> Default Engine with a Carry Capacity of 1000 Units of Weight. The only unit capable
> of movement, and is used to move your attacking units around the board, as well as
> maneuver your more fragile units out of harms way.
>
> This Engine, unlike any other units, can be spawned in one of 25 unique paint jobs
> at random.

The card's own Weight (300) reads as the engine's contribution to some larger budget
distinct from the 1000-unit Carry Capacity it grants everything else — the two are not
the same number and the card doesn't explain the relationship. Worth asking about
directly rather than guessing further.

### #002 — Gunner Car

| Cost | Range | Weight |
|---:|---:|---:|
| 150 | 7×7 | 150 |

> Fires pellets at Spiders within its range at a consistent rate.
>
> This is your most basic attacking unit in the game, and a very reliable way of
> stopping the spider onslaught.

### #003 — Passenger Coach

| Cost | Range | Weight |
|---:|---:|---:|
| 50 | N/A | 125 |

> Your main form of currency generation. Spawns the in-game currency 'Delta'.
>
> Without this unit, Building a hearty Defense will likely be difficult if you are
> only relying on the consistent, but weak passive income you are given during each
> leve[l].

First explicit confirmation of the currency's intended name, **Delta** — the current
build just calls it currency/funds with a `$` glyph. Worth reconciling in the same
pass as the numeric rebalance, since it touches most of the HUD.

### #004 — Brake Van

| Cost | Range | Weight |
|---:|---:|---:|
| 250 | N/A | 0 |

> Caps off the Train it is hooked up to, meaning no other cars can be added to the
> train once you attach a Brake Van to it.
>
> However, capping off the train with the Brake Van grants all attacking units in the
> Train an signifigant increase in attack power.
>
> Also slightly decreases the time it takes to start moving and to come to a stop.

Both effects are now implemented. The current build grants a flat +20%
**attack speed** to every other car — plausibly what "increase in attack power" means,
but the card doesn't actually say "speed," so treat that mapping as an assumption, not
a confirmed match. The acceleration/braking-time reduction described in the third
paragraph is implemented as a 15% improvement to convoy braking
(`brake_time_multiplier` on `brake_van.gd`) — the card doesn't give an exact
percentage either, so treat that number the same way.

### #005 — Coal Cannon

| Cost | Range | Weight |
|---:|---:|---:|
| 300 | 5×5 | 225 |

> Fires a powerful cannonball at a slow rate. Blasts Spiders within its range for high
> damage.
>
> The Coal dust shot out from the impact deals minimal Damage to spiders in a 3x3 area
> surrounding the impact area.

### #006 — Ballast Blaster

| Cost | Range | Weight |
|---:|---:|---:|
| 200 | 3×3 | 200 |

> Fires a shotgun Blast of Ballast at any spiders within it's short radius. The Radius
> of the blast is 3 tiles wide.
>
> A Very good Burst option for spiders getting too close to the station for comfort.

### #007 — Chaingunner Car

| Cost | Range | Weight |
|---:|---:|---:|
| 275 | 7×7 | 200 |

> Shoots large bursts of of 7 Pellets, with a cooldown of 4 seconds between each
> burst.
>
> Due to this, the Spread of the Burst means that the accuracy is all but slightly
> reduced, meaning that not every shot will hit its mark.
>
> However, this means that there is a potential to hit multiple spiders, rather than a
> single target.

Card name is "Chaingunner Car," not "Minigun" — the shipped `TurretMinigun`/
`turret_minigun.gd` scene/script now carries this card's stats and burst count (7
pellets, 4-second cooldown) and shows as "Chaingunner Car" in the shop, but kept its
implementation filenames since those are just this scene's earlier working name, not
part of the card's spec. The standalone "Chaingun" car built before this card was
transcribed turned out to be redundant with it and was removed.

### #012 — Tender

| Cost | Range | Weight |
|---:|---:|---:|
| 50 | N/A | 50 |

> This Car is meant to be pl[a]ce directly behind a Steam Engine in a Train. If done,
> It will increase the Max Pull Capacity will be increased by 500 Units.
>
> If not placed directly behind the engine, this effect will not be activated. The
> Tender will also match the color of the Steam Engines Paint Job for consistencies
> sake.

Implemented, including the coupling-position requirement: `TrainConvoy.effective_capacity()`
checks whether `followers[0]` is a Tender (`is_tender == true`) before granting the
+500 bonus, so a Tender anywhere else in the train is just another 50-weight car with
no effect — matching the card's second paragraph. The "matches the Steam Engine's
paint job" cosmetic detail is not implemented; the Tender keeps its own art regardless
of which of the 25 engine liveries it's coupled to.

## Divergence from the current build (resolved)

This used to document a roughly 3–10× gap between these cards and the shipped
numbers, in different units entirely for range and weight. It's been closed by
adopting the infowiki numbers wholesale rather than raiding them selectively:

- **Range**: the cards' grid-based `NxN` notation is converted to the shipped
  continuous world-unit radius as `radius = (N / 2) * path_step`, with
  `path_step = 90` (`TrackRenderer`'s tile size). 7×7 → 315, 5×5 → 225, 3×3 → 135.
  This conversion factor isn't stated anywhere on the cards themselves — it's a
  judgment call made during reconciliation, not a recovered fact, so treat it as
  Proposed rather than Documented if it's ever revisited.
- **Weight**: `TrainConvoy` now enforces the cards' "Carry Capacity" model as a hard
  cap rather than the old soft speed-penalty threshold — `carry_capacity` defaults to
  1000 (from the Steam Engine card), a Tender coupled directly behind the engine adds
  the card's +500 bonus, and `attach_car()` simply refuses (`return false`) a car that
  would push the train over capacity. Every car's `weight` export was changed to its
  card's literal number (Gunner 150, Ballast Blaster 200, Coal Cannon 225, Chaingunner
  Car 200, Passenger Coach 125, Tender 50, Brake Van 0).
- **Cost**: every `TowerData.cost` now matches its card exactly. Starting currency
  (300 → 450) and the early-wave bounty/wave-bonus formulas (`enemy_spawner.gd`) were
  scaled up roughly 3× alongside it, since the cards' costs run 3–5× higher than the
  values they replaced and the early-game pacing work from earlier in the project
  assumed the old scale.
- The Brake Van's acceleration/braking bonus and the Tender are both implemented now
  (see their card sections above).
- The currency is named **Delta** (`Δ`) throughout the HUD — currency label, shop
  price pills, kill-bounty popups, and Passenger Coach income popups.
- The roster was also trimmed to exactly the cards documented here: Slomo (no card in
  the folder) and an earlier standalone Chaingun car (redundant with the Chaingunner
  Car card, which this page already identified as Minigun's earlier name) were both
  removed rather than reconciled, since neither has infowiki backing.

[Placeable cars](systems-and-balance.md#placeable-cars) still documents what actually
ships — update it alongside this page rather than treating this page as the numbers
of record, per this wiki's own [Provenance](systems-and-balance.md#provenance) rule.
