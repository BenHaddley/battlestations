# Open Questions

[Wiki home](README.md)

This is the decision register. Record an answer, owner, date, and evidence when a
question is resolved, then update the affected design page.

## Product and game design

| Question | Why it matters | Current evidence |
|---|---|---|
| Are defenses stationary towers, coupled train cars, or both? | Changes the core loop and architecture. | Current code uses stationary plots; the lost sheet describes engines carrying cars. |
| What causes victory and defeat? | Required for a complete run. | Leaks currently disappear; no base or final wave exists. |
| One board or a level progression? | Affects save data, content scope, and UI. | Only one board is implemented. |
| What are the intended roles of each unit and spider? | Needed before implementing the roster. | Mostly names and art; the detailed concept sheet is lost. |
| Are engine colors cosmetic? | Prevents duplicated or misleading content work. | Eleven liveries exist without supporting logic. |
| What does currency represent and how should it scale? | Needed for meaningful balance. | Only starting money, bounty, and upgrade formulas survive. |

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
| ~~What world-unit scale should targeting, bullets, and movement use?~~ **Resolved** | Current defaults mixed 5-unit script ranges with 80-pixel collision areas. | Standardized: 300-unit targeting range, 600 px/s bullets, 80 px/s movement, applied consistently across `Turret`, `TurretSlomo`, `Bullet`, `Enemy.tscn`. Verified working in a live browser playtest. |
| Should a leak and a kill be separate events? | Base damage, bounty, stats, and wave accounting need different semantics. | Both currently emit `enemy_destroyed`. |
| What targeting policy should turrets use? | Strongly affects strategy and balance. | Current code uses the first overlap returned by physics. |
| ~~What is the supported Godot version?~~ **Resolved** | Required for reproducible exports. | **4.7.2**, installed locally with matching export templates. Project `features` string (`4.3`) is Godot's own minimum-compatibility tag, unrelated to the actual engine version used. |
| What is the shop's selection UI going to look like? | Two `TowerData` entries now exist (Gunner, Slomo Turret) but nothing lets the player pick between them — `BuildManager.selected_tower` always defaults to 0. | New this session, not previously tracked. |

## Recovery checklist

- [ ] Search the separate Discord server's `battle stations` channel.
- [ ] Check the old PC or backups for later project files and the original sheet.
- [ ] Identify the Twitter/X account.
- [ ] Establish authorship and release permission for art and audio.
- [ ] Capture recovered material with dates and provenance under `wiki/sources/`.
