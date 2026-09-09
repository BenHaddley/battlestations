# Asset workbook — unit concepts

[Wiki home](README.md) · [Roadmap](../roadmap.md#asset-workbook--roster-and-production-backlog)

**Documented design**, transcribed from [Assets to make.xlsx](sources/Assets%20to%20make.xlsx),
`Sheet1!A1:L26`, on 2026-09-09. The workbook contains 25 unit entries across six
classes. Its author and design revision date are not established by the sheet.
This is a separate surviving source from the deleted 2023 unit-concepts sheet;
it does not establish that the deleted sheet has been recovered.

These are workbook specifications, not a claim that every unit, asset, or statistic
is implemented. The workbook has no asset filenames, completion statuses, owners,
frame counts, or delivery dates. Reconcile conflicts with the older
[infowiki cards](infowiki-cards.md) before adopting new balance or behavior.

## Reading the sheet

- Size is recorded as `⬛` for every unit except Barrier Car (`⬛⬛`). One/two tile
  footprints are the working interpretation, supported for Barrier by prior notes.
- `N/A` is preserved; it does not mean zero. Tender's weight and carry bonus are
  unspecified, whereas the three support vans explicitly weigh zero.
- Range retains the sheet's notation (including Thumper's `7X7`). The current build
  converts 7×7, 5×5, and 3×3 to circular radii of 315, 225, and 135 world units.
  `Train` is a scope label, not a numeric radius.
- Power and Speed are qualitative labels, not damage or seconds. Speed describes
  movement for locomotives and appears to describe cadence for attacking cars;
  exact values remain to be defined. `Recharge` describes Chaingun's burst cycle.
- Priority labels are preserved: `Close`, `Random`, `Strong`, `All`, and `Webs`.
  Exact distance rules, ties, and the meaning of strong/special require a spec.
- Rows 55–98 contain isolated text fragments (for example, “catch arlong”, “luffy”,
  and “power scalers”) outside the unit table. Their connection to Battle Stations
  is unestablished, so they are retained in the source rather than added to its backlog.

## Complete unit register

Names, numbers, class membership, and qualitative labels below follow the workbook.
Descriptions reproduce its meaning with minor spelling and grammar cleanup.

### LOCOMOTIVE

| Row | Unit | Cost | Size | Carry | Weight | Health | Range | Power | Speed | Priority |
|---:|---|---:|---|---:|---:|---:|---|---|---|---|
| 2 | STEAM ENGINE | 250 | ⬛ | 1200 | N/A | 300 | N/A | N/A | Average | N/A |
| 3 | TENDER | 75 | ⬛ | N/A | N/A | 125 | N/A | N/A | N/A | N/A |
| 4 | DIESEL ENGINE | 325 | ⬛ | 1600 | N/A | 300 | N/A | N/A | Slow | N/A |

| Unit | What it does |
|---|---|
| STEAM ENGINE | Carries cars around the track. Vital to any players Gameplan. |
| TENDER | Attach to the back of an engine to increase its carry capacity. |
| DIESEL ENGINE | Has a Higher carry capacity, but moves slower. |

### ECONOMY

| Row | Unit | Cost | Size | Carry | Weight | Health | Range | Power | Speed | Priority |
|---:|---|---:|---|---:|---:|---:|---|---|---|---|
| 5 | DELTA COACH | 100 | ⬛ | N/A | 125 | 175 | N/A | N/A | N/A | N/A |
| 6 | TURBINE COACH | 125 | ⬛ | N/A | 125 | 150 | N/A | N/A | N/A | N/A |

| Unit | What it does |
|---|---|
| DELTA COACH | Generates Delta to fund your efforts. |
| TURBINE COACH | Generates a little bit of delta rapidly if the train its attached to is in rapid motion. |

### OFFENSE

| Row | Unit | Cost | Size | Carry | Weight | Health | Range | Power | Speed | Priority |
|---:|---|---:|---|---:|---:|---:|---|---|---|---|
| 7 | GUNNER CAR | 150 | ⬛ | N/A | 150 | 200 | 7x7 | Average | Average | Close |
| 8 | COAL CANNON | 300 | ⬛ | N/A | 225 | 225 | 5x5 | Great | Slow | Close |
| 9 | BALLAST BLASTER | 200 | ⬛ | N/A | 175 | 200 | 3x3 | Great | Average | Close |
| 10 | CHAINGUN CAR | 225 | ⬛ | N/A | 200 | 200 | 7x7 | Average | Recharge | Close |
| 11 | MAIL CAR | 125 | ⬛ | N/A | 125 | 150 | 5x5 | Weak | Fast | Random |
| 12 | GREENHOUSE | 200 | ⬛ | N/A | 175 | 250 | 5x5 | Insta-Kill | Slow | Close |
| 13 | STEEL DRIVER | 175 | ⬛ | N/A | 150 | 200 | 5x5 | Great | Slow | Strong |
| 14 | SLATE RETURN | 200 | ⬛ | N/A | 150 | 200 | 5x5 | Weak | Fast | Close |
| 15 | CLIQUE CAR | 175 | ⬛ | N/A | 125 | 200 | 5x5 | Average | Average | Close |
| 16 | CROSSFIRE CAR | 300 | ⬛ | N/A | 175 | 200 | 7x7 | Average | Average | Close |

| Unit | What it does |
|---|---|
| GUNNER CAR | Shoots at nearby spiders on the rails. |
| COAL CANNON | Fires a powerful coal cannonball at spiders. Has a chance to knock spiders back. |
| BALLAST BLASTER | Shoots a powerful burst of ballast at spiders in close proximity to it. |
| CHAINGUN CAR | Shoots a burst of 7 bullets at a nearby spider, has to cooldown after each burst. |
| MAIL CAR | Flings letters rapidly at random spiders within its range |
| GREENHOUSE | Sticks its tongue out and eats a spider whole. Takes time to chew afterwards. |
| STEEL DRIVER | Shoots a powerful rail spike forward that prioritizes strong or special spiders. |
| SLATE RETURN | Hurls a slate tile in an arc like a boomerang, dealing light damage to anything in its path. |
| CLIQUE CAR | Will increase its attack power depending on how many clique cars are on the same train. |
| CROSSFIRE CAR | Fires four bullets in a cross formation. |

### DEFENSE

| Row | Unit | Cost | Size | Carry | Weight | Health | Range | Power | Speed | Priority |
|---:|---|---:|---|---:|---:|---:|---|---|---|---|
| 17 | BARRIER CAR | 125 | ⬛⬛ | N/A | 325 | 1250 | N/A | N/A | N/A | N/A |
| 18 | THUMPER | 250 | ⬛ | N/A | 275 | 250 | 7X7 | None | Very Slow | All |
| 19 | SCAPEGOAT | 325 | ⬛ | N/A | 300 | 1000 | N/A | N/A | N/A | N/A |
| 20 | GLUE TANKER | 250 | ⬛ | N/A | 300 | 225 | 7x7 | None | Slow | Close |

| Unit | What it does |
|---|---|
| BARRIER CAR | Blocks off spiders |
| THUMPER | Thumps the ground, bouncing spiders in the air and stunning them for a short time. |
| SCAPEGOAT | Will take damage for the station in its place until its destroyed. |
| GLUE TANKER | Shoots globs of glue onto tiles that slows spiders down. |

### SUPPORT

| Row | Unit | Cost | Size | Carry | Weight | Health | Range | Power | Speed | Priority |
|---:|---|---:|---|---:|---:|---:|---|---|---|---|
| 21 | BRAKE VAN | 175 | ⬛ | N/A | 0 | 200 | N/A | N/A | N/A | N/A |
| 22 | VELOCITY VAN | 200 | ⬛ | N/A | 0 | 200 | N/A | N/A | N/A | N/A |
| 23 | MINI VAN | 225 | ⬛ | N/A | 0 | 150 | N/A | N/A | N/A | N/A |

| Unit | What it does |
|---|---|
| BRAKE VAN | Increases the attack power of the cars attached to your train by 1.25x |
| VELOCITY VAN | Increases the speed of the train, decreases the damage of attached cars by 10% |
| MINI VAN | Increases the attack power of the cars attached by 1.75x if your train has 3 cars or less. |

### MISC.

| Row | Unit | Cost | Size | Carry | Weight | Health | Range | Power | Speed | Priority |
|---:|---|---:|---|---:|---:|---:|---|---|---|---|
| 24 | WEB WHACKER | 100 | ⬛ | N/A | 100 | 200 | 3x3 | N/A | N/A | Webs |
| 25 | JACKHAMMER | 200 | ⬛ | N/A | 150 | 200 | 3x3 | Average | Fast | Close |
| 26 | THROTTLE ROCKET | 225 | ⬛ | N/A | 200 | 150 | Train | N/A | N/A | N/A |

| Unit | What it does |
|---|---|
| WEB WHACKER | Wipes away any web clusters left by spiders on the board. |
| JACKHAMMER | Rapidly damages nearby spiders, deals heavy damage to board obstacles like rocks. |
| THROTTLE ROCKET | Will increase the speed of the whole train. |

## Relationship to the active build

The current catalog contains eight purchasable cars plus the Steam Engine.
Workbook names `DELTA COACH`, `CHAINGUN CAR`, and `MAIL CAR` correspond to the current
Passenger Coach, Chaingunner Car, and Mail Carrier respectively; these mappings
follow their matching roles and supplied art, rather than introducing duplicate units.

| Item | Workbook | Current implementation / follow-up |
|---|---|---|
| Steam Engine | Cost 250; carry 1200; health 300 | Purchased engine costs 325; base carry is 1000 in [game balance](../scripts/game_balance.gd). Reconcile economy and capacity. |
| Tender | Cost 75; health 125; weight and carry `N/A`; attach behind engine to increase capacity | [Catalog](../resources/tender_car.tres) costs 50, weighs 50; current direct-behind bonus is +500. Sheet does not supply a replacement bonus. |
| Delta Coach | Cost 100; weight 125; health 175 | [Passenger Coach](../resources/passenger_coach.tres) costs 110, weighs 125. Income amount/interval remain unspecified by the sheet. |
| Mail Car | Cost 125; weight 125; health 150; 5×5; Weak/Fast/Random | [Mail Carrier](../resources/mail_carrier.tres) currently uses provisional cost 200 and weight 150, with 3 shots/sec and 4 damage. Random targeting and range are implemented; numeric power/cadence are not established by the sheet. |
| Brake Van | Cost 175; weight 0; health 200; 1.25× train attack power | [Catalog](../resources/brake_van.tres) costs 250. [Behavior](../scripts/brake_van.gd) grants 1.2× attack speed, caps attachments, and reduces braking time by 15%. Damage versus cadence, train-cap rules, and stacking need reconciliation. |
| Coal Cannon | Knockback has a chance to occur | [Projectile](../scripts/coal_cannonball.gd) currently applies knockback on each eligible direct hit. Probability is unspecified. |
| Target selection | Most offensive cars use Close; Steel Driver uses Strong; Mail uses Random | Standard [turrets](../scripts/turret.gd) acquire the first physics overlap, which is not guaranteed nearest. Mail already reselects randomly per projectile. |
| Health and size | All 25 rows specify health; Barrier has a double footprint | These are design requirements, not proof of implemented per-car health/destruction or two-tile placement. Train damage and reconnection rules remain open. |

Gunner, Coal Cannon, Ballast Blaster, and Chaingunner retain the familiar listed
cost/range/weight values. This does not settle their new health, qualitative power,
cadence, or priority specifications. Latest playtest feedback restores swivelling
weapons; the workbook's directional wording for individual new attacks does not
reinstate the rejected global direction-lock experiment.

## Production and implementation dependencies

The following work is derived from the unit descriptions; it is a proposed production
breakdown, not an asset-delivery list supplied by the spreadsheet.

| Work group | Units | Required specification / asset work |
|---|---|---|
| Locomotion and economy | Diesel Engine, Turbine Coach, Velocity Van, Throttle Rocket | Movement/capacity variants; rapid-motion threshold and income tick; speed bonuses, stacking, and caps; vehicle art and status feedback. |
| Specialized attacks | Greenhouse, Steel Driver, Slate Return, Clique Car, Crossfire Car | Eating/chewing and instant-kill exceptions; strong-target ordering and rail spike; outbound/return slate collisions; same-train damage scaling; four-way projectile behavior. Supply vehicle, projectile, and action art as appropriate. |
| Defense and board control | Barrier Car, Thumper, Scapegoat, Glue Tanker | Two-tile placement and spider detours/bites; airborne stun duration/immunities; station-damage redirection; glue tile duration/stacking. Supply barrier, impact, stun, interception, and glue visuals. |
| Support | Mini Van, Brake Van, Velocity Van | Define attack-power bonuses, which units count toward the three-car limit, stacking order, and recalculate on coupling/removal/destruction. Add readable buff feedback. |
| Board interaction | Web Whacker, Jackhammer | Define web-cluster persistence/removal and destructible obstacle health; distinguish damage to spiders from rocks; supply clearing, drilling, web, and obstacle visuals. |
| Shared roster presentation | All 25 units | Audit existing art before commissioning; track chassis/top/icon/projectile/effect needs, pivots, scale, animation states, authorship, and delivery status. Add shop/almanac descriptions and unlock plans for approved additions. |

Track execution in the [roadmap](../roadmap.md#asset-workbook--roster-and-production-backlog)
and design decisions in [Open questions](open-questions.md).
