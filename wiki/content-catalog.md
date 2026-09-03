# Content Catalog

[Wiki home](README.md)

This catalog groups the usable source assets migrated into `assets/`. Godot-generated
`.import` sidecars are not separate content. A filename proves an asset exists, not
that its implied mechanic was designed or implemented.

## Board and environment

- Two full-board images: `BATTLE STATIONS BOARD.png` and the currently used
  `THE_BOARD.png`.
- Rail tiles: curve and straight.
- Five numbered break pieces.
- Three rocks.

`THE_BOARD.png`, the straight rail tile, and the curved rail tile are used by active scenes.

## Engines

Eleven steam-engine liveries are available: Black, Blue, Dark Green, Lime, Marine,
Maroon, Orange, Pink, Red, White, and Yellow. The white engine is currently used as
the slow defense. Whether liveries are cosmetics or stat variants is unresolved.

The lost concept sheet also documented Steam, Diesel, Electric, and Oil engine ideas;
see [History and sources](history-and-sources.md). No surviving art is explicitly
named for the latter three.

## Defense and train-unit art

All seven placeable cars are implemented and purchasable from the in-game shop; see
[Placeable cars](systems-and-balance.md#placeable-cars) for cost, stats, and behavior.

| Family | Surviving art | Active gameplay |
|---|---|---|
| Gunner | Base, top, projectile | Single-target homing shot |
| Slomo | (reuses the white steam-engine livery) | Area slow pulse, no damage |
| Minigun | Base, top, bullet | 5-shot burst every 3s |
| Ballast Blaster | Unit plus 5 ballast frames | Short-range hit-everyone-in-range blast |
| Coal Cannon | Base, top, cannonball; 3 break frames unused | Slow splash shot: 3 direct, 1 splash |
| Passenger Coach | Unit | Passive income, no weapon |
| Brake Van | Unit | Caps the train, +20% attack speed buff, no weapon |
| Oil Tanker | 2 unit variants, 4 tar-tile frames | None |
| Slate Return | 2 unit frames, 2 slate frames | None |
| Delta | 3 projectile frames, no clearly named unit | None |

Oil Tanker, Slate Return, and Delta remain unimplemented; their mechanical roles are
still **inferred** from names and art alone. Coal Cannon reuses the generic hit-effect
sprite for its impact rather than its own 3 coal-break frames, which remain unused.
Ballast Blaster's five ballast-chunk frames are used, for its firing-spray animation.

### Documented future content

- **Barrier Car** — planned as a heavy, two-tile divider/wall. No finished asset or
  stats are currently documented.
- **Ramming engine** — a possible engine limited to one carried car but fast enough
  to damage spiders on impact. No asset or stats exist yet.
- **Redrawn armed cars** — Gubgub considers the current firing-unit art outdated and
  plans versions that visually support one-direction-only weapons.
- **Updated Steam Engine** — an updated-color redraw was in progress on 2026-08-29.
- **Discovery gallery** — planned to fill with every unit the player has encountered,
  with a name and short description for each. Gubgub will provide the art and copy;
  implementation is deferred until those assets are finished.

## Reference material (not game assets)

`assets/audio/infowiki/` holds eight trading-card-style unit spec sheets — despite
living under `audio/`, these are reference images, not sound or usable sprite content.
See [Infowiki unit cards](infowiki-cards.md) for the full transcription.

## Spider art

- Generic sets: walk variants numbered 2–6, a standalone sprite, and a death frame.
- Named sets: Baby, Charger, Rally, Roller, Sturdy, and Wolf, generally with two
  movement frames and one death frame.
- Special sets: Spider Jump with two movement frames and death; Spider Egg with two
  frames and a break frame.
- Wolf additionally has two angry-state frames (one filename contains the apparent
  typo `Anfy`).

All supplied spider sets are now used through the shared active enemy scene. The
one-through-six-dot walk pairs provide the generic durability transformations;
Baby, Charger, Rally, Roller, Sturdy, Wolf, Jump, and Egg are campaign-unlocked
archetypes. Their implemented roles are recorded in
[Systems and balance](systems-and-balance.md#enemy-roster).

## Effects and UI

- Effects include hit and puff art, five break frames, and animated GIF source art.
- Runtime UI includes the illustrated HUD, control icons, HP art, portraits, tutorial
  frames, and the game-over composition.
- `assets/sprites/ui/game over ai placeholder/` is actively used despite its legacy
  directory name. Renaming it requires updating the preloads in `game_over_overlay.gd`.
- The identical `BREAK 1.png` through `BREAK 5.png` files in `board/` and `effects/`
  are retained for now because their intended ownership is unresolved.

## Audio

The game now has a shuffled 20-track gameplay playlist from `assets/audio/songs/`.
The title screen retains its separate
`opening screen musicMountain Banjo.mp3` theme. Gameplay exhausts a shuffled cycle
before repeating and prevents the same song playing across a reshuffle boundary.
The recordings' authorship, intended use, and whether any are the placeholder
“banjo music” mentioned in conversation remain
unverified. Do not assume it is cleared for release until provenance is confirmed.

## Archive

The original Unity project and its metadata remain in `legacy_unity/`. Use the active
`assets/` tree for Godot work; use the archive to investigate provenance or recover
scene configuration, not as a second live asset library.
