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

## Art, audio, and identity

| Question | Why it matters | Current evidence |
|---|---|---|
| Is the existing spider art temporary? | Determines when an art pass is worthwhile. | A collaborator planned to remake it after gameplay was established. |
| Are the soundtrack recordings original, licensed, and final? | Release and attribution risk. | `Train 45`, eight gameplay songs, and a separate title theme now exist; provenance still needs confirmation. |
| What was the game’s Twitter/X handle and branding? | Could recover public history and visual identity. | The account was discussed but never linked in the searched DM. |
| Who owns each surviving asset? | Needed before public release. | Repository filenames do not establish authorship or license. |

## Technical decisions

| Question | Why it matters | Current evidence |
|---|---|---|
| ~~What world-unit scale should targeting, bullets, and movement use?~~ **Resolved** | Current defaults mixed 5-unit script ranges with pixel-scale collision areas. | Standardized around 360-unit Gunner range and 900-unit projectile speed; spider speed is derived from lane length for a 25-second journey. Verified in live browser playtests. |
| ~~Should a leak and a kill be separate events?~~ **Resolved for prototype** | Base damage, bounty, stats, and wave accounting need different semantics. | Arrival now enters a persistent station-attack state. Only actual death emits `enemy_destroyed` and pays bounty. |
| What targeting policy should turrets use? | Strongly affects strategy and balance. | Current code uses the first overlap returned by physics. |
| ~~What is the supported Godot version?~~ **Resolved** | Required for reproducible exports. | **4.7.2**, installed locally with matching export templates. Project `features` string (`4.3`) is Godot's own minimum-compatibility tag, unrelated to the actual engine version used. |
| ~~What is the shop's selection UI going to look like?~~ **Resolved for prototype** | Train deployment needs a clear interaction. | Each infowiki-backed car acts as a drag source in a scrollable Train Yard list; a preview follows the cursor and the convoy glows as the valid attachment target. |

## Recovery checklist

- [ ] Search the separate Discord server's `battle stations` channel.
- [ ] Check the old PC or backups for later project files and the original sheet.
- [ ] Identify the Twitter/X account.
- [ ] Establish authorship and release permission for art and audio.
- [ ] Capture recovered material with dates and provenance under `wiki/sources/`.
