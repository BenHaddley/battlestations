# Open Questions

[Wiki home](README.md)

This is the decision register. Record an answer, owner, date, and evidence when a
question is resolved, then update the affected design page.

## Product and game design

| Question | Why it matters | Current evidence |
|---|---|---|
| ~~Are defenses stationary towers, coupled train cars, or both?~~ **Resolved for prototype** | Changes the core loop and architecture. | One default black engine leads a coupled consist. Gunner and Slomo cars are dragged onto it and follow at the tail. |
| What causes victory and defeat? | Required for a complete run. | Leaks currently disappear; no base or final wave exists. |
| One board or a level progression? | Affects save data, content scope, and UI. | Only one board is implemented. |
| Replace the current board with the proposed 9×11 version? | Changes lane coordinates, rail bounds, camera framing, and illustrated grid alignment. | Awaiting the new board image; the current 2100×1920 source is the older seven-column courtyard. |
| What are the intended roles of each unit and spider? | Needed before implementing the roster. | **Partially resolved for 8 cars** — [Infowiki unit cards](infowiki-cards.md) gives cost/range/weight/bio for Steam Engine, Gunner, Passenger Coach, Brake Van, Coal Cannon, Ballast Blaster, Chaingunner (implemented as Minigun), and the unimplemented Tender. Cards 008–011 and the full spider roster are still undocumented. |
| ~~Should the shipped car costs, ranges, and weights be reconciled toward the infowiki cards?~~ **Resolved** | The two disagreed by roughly 3–10× on nearly every number, and used different units for range (grid tiles vs. world-unit radius) and weight (capacity budget vs. threshold-with-penalty). | Adopted the infowiki numbers wholesale. Range: `radius = (N / 2) * path_step` (path_step = 90), so 7×7 → 315, 5×5 → 225, 3×3 → 135. Weight: `TrainConvoy` now enforces the card's hard Carry Capacity model (1000 base, +500 with a Tender coupled directly behind the engine) instead of the old soft speed-penalty threshold — `attach_car()` simply refuses a car that would exceed capacity. Brake Van's accel/coast-time reduction (previously undocumented in code) is implemented as a 15% cut. The roster itself was also trimmed to exactly the infowiki's turrets: Slomo (no card) and the earlier standalone Chaingun car (redundant with the Chaingunner Car card, which the wiki already identified as Minigun's earlier name) were removed. |
| ~~Are engine colors cosmetic?~~ **Resolved** | Prevented duplicated or misleading content work. | Switched from eleven named liveries to the 25 numbered `Steam Engine N.png` files, matching the Steam Engine card's "25 unique paint jobs at random" claim exactly. |
| ~~What does currency represent and how should it scale?~~ **Resolved** | Needed for meaningful balance. | The [Passenger Coach card](infowiki-cards.md#003--passenger-coach) names it "Delta"; the HUD now shows `Δ` amounts throughout (currency label, price pills, bounty popups, income popups) instead of a bare `$`. Starting currency and bounty/wave-bonus formulas were scaled up roughly 3× alongside the new card costs. |
| How far should spider bounties be reduced? | Large-wave kill rewards currently make costs inconsequential and crowd out Passenger Coach strategy. | Gubgub's 2026-08-28 playtest establishes the direction—less bounty, more reliance on Passenger Coaches—but supplies no target values. |
| What are the final manual engine controls and speed limits? | The expanded panel hides the station edge, while full stopping encourages static play. | Suggested direction: compact Up/Down input, manual speed mainly boosts cruise, and engines slow dramatically without reaching zero. Exact behavior remains open. |
| ~~Can engines be acquired during a level?~~ **Resolved as design intent** | Determines shop scope and how multiple trains enter play. | Each level grants one engine; the player can buy and place more engines on rails, then manage them separately. Not implemented. |
| ~~How does car destruction affect a train?~~ **Resolved for prototype (proposed design, 2026-09-09)** | Barrier play introduces car health, biting, and possible gaps inside consists. | Implemented: workbook health on every unit, 25 DPS bites in 0.25 s ticks stacking linearly, a destroyed car leaves the consist and its neighbours close the gap, its buffs/capacity go with it, and a destroyed engine becomes a recoverable wreck (Δ325 locomotive drop). See [Systems and balance](systems-and-balance.md#train-damage-avoidance-biting-ramming-and-wrecks). Needs designer confirmation and a playtest. |
| ~~What are the rules and economy for between-wave rail expansion?~~ **Resolved for prototype (proposed design, 2026-09-09)** | Rail editing changes route validity, spending, and convoy rebinding. | Implemented: STATIONS-only hover/plus at Δ50, orthogonal adjacency, explicit free joins for dead ends, longer player-built detours adopted by the ring, full refunds on removal, run-local persistence. Still open: final price, finite inventory, junction switching, dead-end shuttling, and separation between trains sharing a cell. See [Rails and navigation](future-runtime-rails-and-navigation.md). |
| ~~What happens when a train hits a spider?~~ **Resolved for prototype** | Incidental ramming must not become the main weapon. | Implemented as 20 damage (one Gunner bullet) per spider per unit with a 2 s cooldown, only above 60% cruise speed; the train drops to 35% speed and jolts back 8 units. Values are provisional. |
| ~~Do empty rails block spiders, and how far do spiders search for a detour?~~ **Resolved for prototype** | Determines navigation and when biting starts. | Empty rail never blocks. A spider searches up to three lanes each side for a clear corridor before biting a unit in contact. |
| Which updated Gunner/Chaingunner artwork replaces the current chassis/turret pairs? | The placed cars and every preview must match while still swivelling. | The build now renders one chassis/turret pair everywhere. The updated files Gubgub placed on the shared Drive are not in the repository; import them as separate chassis and turret images to replace `Gunner Car Base/Top` and `Minigun Base/Top`. |

## Asset workbook reconciliation

Source: [25-unit register and build comparison](asset-workbook.md). Record decisions
before treating the spreadsheet's unspecified values as implementation defaults.

| Question | Why it matters | Current evidence |
|---|---|---|
| Which workbook values supersede the older cards and provisional build stats? | Costs, carry capacity, and buffs change existing balance. | Steam 250/1200 carry, Tender 75, Delta Coach 100, Mail 125 cost/125 weight, Brake Van 175 and 1.25× attack power differ from the build. |
| How do Power, Speed, and Priority map to exact rules? | Defines damage, cadence, nearest/strong selection, targeting ties, and exceptions. | Workbook supplies qualitative labels; Mail random-per-projectile behavior is already implemented. Coal knockback probability is not given. |
| How do per-unit health, destruction, and support effects interact? | Determines train gaps, lost buffs, station interception, and capacity after losing a Tender. | Health, destruction, gap closing, lost Brake Van buffs and lost Tender capacity are implemented for the current roster (a train left over capacity keeps its cars but cannot couple more). Station interception, buff stacking across future vans, and Mini Van's car-count rules remain unspecified. |
| What are the new board-effect and movement thresholds? | Required for Turbine income, glue, stun, web clearing, rocks, and speed-support cars. | Roles are documented, but durations, income rates, speed thresholds, limits, and obstacle rules are not. |
| Which planned units have production-ready assets and approved unlocks? | Prevents a concept entry being mistaken for a delivered car. | Workbook lists no asset paths, completion statuses, owners, or release order. |

## Art, audio, and identity

| Question | Why it matters | Current evidence |
|---|---|---|
| How should the supplied game-over artwork coexist with the restart/menu controls? | The requested treatment is a minimal dim-and-fade overlay, while the player still needs a clear way to continue. | The supplied [`GAME_OVER_TEXT` Discord attachment](https://media.discordapp.net/attachments/947661024075595838/1542709884045369414/GAME_OVER_TEXT.png?ex=6a9583ca&is=6a94324a&hm=8bcbd04381492aa1749bf28d9d12e365b4f48f304241f83f3c5e281f826d4ab2&=&format=webp&quality=lossless&width=1024&height=1024) should fade in over slightly darkened gameplay. |
| Is the existing spider art temporary? | Determines when an art pass is worthwhile. | A collaborator planned to remake it after gameplay was established. |
| Are the soundtrack recordings original, licensed, and final? | Release and attribution risk. | `Train 45`, eight gameplay songs, and a separate title theme now exist; provenance still needs confirmation. |
| What was the game’s Twitter/X handle and branding? | Could recover public history and visual identity. | The account was discussed but never linked in the searched DM. |
| Who owns each surviving asset? | Needed before public release. | Repository filenames do not establish authorship or license. |

## Technical decisions

| Question | Why it matters | Current evidence |
|---|---|---|
| ~~What world-unit scale should targeting, bullets, and movement use?~~ **Resolved** | Current defaults mixed 5-unit script ranges with pixel-scale collision areas. | Standardized around 360-unit Gunner range and 900-unit projectile speed; spider speed is derived from lane length for a 25-second journey. Verified in live browser playtests. |
| ~~Should a leak and a kill be separate events?~~ **Resolved for prototype** | Base damage, bounty, stats, and wave accounting need different semantics. | Arrival now enters a persistent station-attack state. Only actual death emits `enemy_destroyed` and pays bounty. |
| ~~What targeting policy should turrets use?~~ **Resolved for the current roster** | Strongly affects strategy and balance. | Guns acquire the nearest live spider within their documented radius (workbook priority *Close*); Mail Carrier picks a random recipient per envelope. *Strong*, *All* and *Webs* priorities wait for the units that use them. |
| ~~What is the supported Godot version?~~ **Resolved** | Required for reproducible exports. | **4.7.2**, installed locally with matching export templates. Project `features` string (`4.3`) is Godot's own minimum-compatibility tag, unrelated to the actual engine version used. |
| ~~What is the shop's selection UI going to look like?~~ **Resolved for prototype** | Train deployment needs a clear interaction. | Each infowiki-backed car acts as a drag source in a scrollable Train Yard list; a preview follows the cursor and the convoy glows as the valid attachment target. |

## Recovery checklist

- [ ] Search the separate Discord server's `battle stations` channel.
- [ ] Check the old PC or backups for later project files and the original sheet.
- [ ] Identify the Twitter/X account.
- [ ] Establish authorship and release permission for art and audio.
- [ ] Capture recovered material with dates and provenance under `wiki/sources/`.
