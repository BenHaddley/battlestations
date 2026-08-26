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
| Should the shipped car costs, ranges, and weights be reconciled toward the infowiki cards? | The two currently disagree by roughly 3–10× on nearly every number, and use different units for range (grid tiles vs. world-unit radius) and weight (capacity budget vs. threshold-with-penalty). | See [Divergence from the current build](infowiki-cards.md#divergence-from-the-current-build) for the specific gaps, including the Brake Van's undocumented accel/brake bonus and the entirely unimplemented Tender. |
| Are engine colors cosmetic? | Prevents duplicated or misleading content work. | Eleven liveries exist without supporting logic; the infowiki Steam Engine card separately claims 25 random paint jobs, not tied to the eleven named liveries. |
| What does currency represent and how should it scale? | Needed for meaningful balance. | **Partially resolved** — the [Passenger Coach card](infowiki-cards.md#003--passenger-coach) names it "Delta"; the shipped UI still shows a bare `$` amount. Scaling still needs the reconciliation above. |

## Art, audio, and identity

| Question | Why it matters | Current evidence |
|---|---|---|
| Is the existing spider art temporary? | Determines when an art pass is worthwhile. | A collaborator planned to remake it after gameplay was established. |
| Is `Train 45.mp3` original, licensed, and final? | Release and attribution risk. | One file survives; conversation mentions placeholder banjo music. |
| What was the game’s Twitter/X handle and branding? | Could recover public history and visual identity. | The account was discussed but never linked in the searched DM. |
| Who owns each surviving asset? | Needed before public release. | Repository filenames do not establish authorship or license. |

## Technical decisions

| Question | Why it matters | Current evidence |
|---|---|---|
| ~~What world-unit scale should targeting, bullets, and movement use?~~ **Resolved** | Current defaults mixed 5-unit script ranges with pixel-scale collision areas. | Standardized around 360-unit Gunner range and 900-unit projectile speed; spider speed is derived from lane length for a 25-second journey. Verified in live browser playtests. |
| Should a leak and a kill be separate events? | Base damage, bounty, stats, and wave accounting need different semantics. | Both currently emit `enemy_destroyed`. |
| What targeting policy should turrets use? | Strongly affects strategy and balance. | Current code uses the first overlap returned by physics. |
| ~~What is the supported Godot version?~~ **Resolved** | Required for reproducible exports. | **4.7.2**, installed locally with matching export templates. Project `features` string (`4.3`) is Godot's own minimum-compatibility tag, unrelated to the actual engine version used. |
| ~~What is the shop's selection UI going to look like?~~ **Resolved for prototype** | Train deployment needs a clear interaction. | Gunner, Slomo, Minigun, and Ballast cards act as drag sources; a preview follows the cursor and the convoy glows as the valid attachment target. |

## Recovery checklist

- [ ] Search the separate Discord server's `battle stations` channel.
- [ ] Check the old PC or backups for later project files and the original sheet.
- [ ] Identify the Twitter/X account.
- [ ] Establish authorship and release permission for art and audio.
- [ ] Capture recovered material with dates and provenance under `wiki/sources/`.
