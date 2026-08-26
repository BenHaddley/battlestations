# Infowiki Unit Cards

[Wiki home](README.md)

`assets/audio/infowiki/` (the folder name is misleading — these are images, not audio)
holds a set of trading-card-style unit spec sheets: `001_Steam_Engine.png` through
`007_Chaingun_Car.png`, then `012_Tender.png`. Cards 008–011 are missing from the
folder — not yet supplied, not lost from a larger set we know existed. Nothing in the
repository identifies an author; treat this as **Documented** per the
[confidence labels](README.md#confidence-labels) — a surviving design artifact, not
verified first-hand design intent.

**This is the authoritative unit design source, and it disagrees with the current
implementation on nearly every number.** See
[Divergence from the current build](#divergence-from-the-current-build) below before
using anything on this page as a bug report against the code. The roadmap and
[Open questions](open-questions.md) are where a reconciliation decision belongs, not
this page.

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

Two effects on the card, only one implemented. The current build grants a flat +20%
**attack speed** to every other car — plausibly what "increase in attack power" means,
but the card doesn't actually say "speed," so treat that mapping as an assumption, not
a confirmed match. The acceleration/braking-time reduction described in the third
paragraph has no equivalent in `train_convoy.gd` at all.

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

Card name is "Chaingunner Car," not "Minigun" — the current implementation
(`TurretMinigun`/`turret_minigun.gd`) is almost certainly this card under an earlier
working name, not a separate, unimplemented seventh weapon.

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

Entirely unimplemented — there's no `Tender` scene, script, or `TowerData` resource in
the current build, and no equivalent of "specific coupling position matters" logic
anywhere in `train_convoy.gd` (cars only care about their index, not adjacency to a
particular other car).

## Divergence from the current build

Every number on these cards is roughly 3–10× the corresponding value shipped today,
and the two use different units entirely for range and weight:

- **Range** is grid-based (`NxN`, presumably board tiles) on the cards; the shipped
  turrets use a continuous world-unit radius (Gunner 360, Coal Cannon 340, Ballast
  Blaster 190). No conversion factor between the two is established anywhere.
- **Weight** on the cards describes a "carry capacity" budget in the hundreds (Steam
  Engine carries 1000, Gunner costs 150 of it). The shipped weight system uses a flat
  5.0-unit threshold with most cars at 1.0 and Coal Cannon at 2.0 — a different scale
  and a different shape of constraint (threshold-with-penalty vs. hard capacity).
- **Cost** is 3× to 5× higher per card on the infowiki (Gunner 150 vs. shipped 50;
  Brake Van 250 vs. shipped 60), and starting currency would need to scale with it.
- The Brake Van's acceleration/braking bonus and the entire Tender car are missing
  from the implementation.
- The currency is unnamed in the UI; the cards call it Delta.

None of this is a defect in [Placeable cars](systems-and-balance.md#placeable-cars) —
that page documents what actually ships today, deliberately kept separate from
proposed or historical design values per this wiki's own rule (see
[Provenance](systems-and-balance.md#provenance)). Reconciling the two — adopting the
infowiki numbers wholesale, treating them as a different design pass to raid
selectively, or leaving them as reference lore — is an open decision; see
[Open questions](open-questions.md).
