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

Only `THE_BOARD.png` and the straight rail tile are used by active scenes.

## Engines

Eleven steam-engine liveries are available: Black, Blue, Dark Green, Lime, Marine,
Maroon, Orange, Pink, Red, White, and Yellow. The white engine is currently used as
the slow defense. Whether liveries are cosmetics or stat variants is unresolved.

The lost concept sheet also documented Steam, Diesel, Electric, and Oil engine ideas;
see [History and sources](history-and-sources.md). No surviving art is explicitly
named for the latter three.

## Defense and train-unit art

| Family | Surviving art | Active gameplay |
|---|---|---|
| Gunner | Base, top, projectile | Standard turret |
| Coal Cannon | Base, top, cannonball, 3 break frames | None |
| Minigun | Base, top, bullet | None |
| Ballast Blaster | Unit plus 5 ballast frames | None |
| Brake Van | Unit | None |
| Oil Tanker | 2 unit variants, 4 tar-tile frames | None |
| Passenger Coach | Unit | None |
| Slate Return | 2 unit frames, 2 slate frames | None |
| Delta | 3 projectile frames, no clearly named unit | None |

Mechanical roles for unused families are **inferred**. Splash, piercing, tar damage,
and similar behavior in the roadmap are proposals, not recovered specifications.

## Spider art

- Generic sets: walk variants numbered 2–6, a standalone sprite, and a death frame.
- Named sets: Baby, Charger, Rally, Roller, Sturdy, and Wolf, generally with two
  movement frames and one death frame.
- Special sets: Spider Jump with two movement frames and death; Spider Egg with two
  frames and a break frame.
- Wolf additionally has two angry-state frames (one filename contains the apparent
  typo `Anfy`).

Only `Spider walk 2-1 sprite.png` is used in the active enemy scene. Names such as
Charger or Rally suggest possible roles but do not establish them.

## Effects and UI

- Effects: hit effect, Puff, and two additional puff frames.
- UI: left and right menu art, pause, speed up, and `gifmaker_me_4.png`.

The active build uses only a plain Godot currency label; these effect and UI images
are not wired into gameplay.

## Audio

One track survives: `assets/audio/Train 45.mp3`. Its authorship, intended use, and
whether it is the placeholder “banjo music” mentioned in conversation remain
unverified. Do not assume it is cleared for release until provenance is confirmed.

## Archive

The original Unity project and its metadata remain in `legacy_unity/`. Use the active
`assets/` tree for Godot work; use the archive to investigate provenance or recover
scene configuration, not as a second live asset library.
