# Current Build

[Wiki home](README.md)

## Status

The active codebase is a Godot 4 scaffold port of the archived Unity prototype. Its
main scene contains one fitted 9×12 board, nine vertical enemy lanes, a randomized bounded railway, one enemy
spawner, a defended station, and a two-gutter HUD/shop. The port closely preserves the eleven original Unity
gameplay scripts as GDScript plus four autoload managers.

The build should be treated as a scaffold, not a finished playable slice — but the
core drag → deploy → patrol → shoot/slow → kill → currency → wave-scaling loop is now verified
working end to end, including in an actual Web-exported browser build (see
[Roadmap, Phase 4](../roadmap.md) for the full verification notes and the bugs that
testing-in-browser caught that code review and the editor alone did not). The
2026-09-09 direction — STATIONS rail building, spider avoidance and biting, unit
health and wrecks, range previews, the controlled-train readout and per-profile
Duck and Daisy lessons — is implemented and covered by the headless regression
suite (`tests/GameplayRegression.tscn`); it has not yet been playtested by a person.

## Running the project

With a compatible Godot 4 executable installed (developed against 4.7.2):

```sh
godot --editor --path .
```

For a headless startup check:

```sh
godot --headless --path . --import   # first run, or after adding assets
godot --headless --path . --quit-after 60
```

The configured entry scene is `scenes/TitleScreen.tscn`; its Start controls transition
to `scenes/Main.tscn`. A Web export preset is checked in
(`export_presets.cfg`); build it with:

```sh
godot --headless --path . --export-release "Web" export/web/index.html
```

`export/` is gitignored — it's a build artifact, not source. A GitHub Actions
workflow (`.github/workflows/deploy-pages.yml`) builds and deploys this to GitHub
Pages on push to `main`; the site is <https://benhaddley.github.io/battlestations/>.

The Web preset exports an **allowlist**: the scenes in `export_files`, everything they
reference transitively through `.tscn`/`.tres` dependencies, and the `include_filter`
patterns in `export_presets.cfg`. It does not follow a script's own `preload()`
targets. A script that preloads a file outside that set works in the editor but fails
to load in the exported build, and every script depending on it fails with it — this
is how the starting railway and train disappeared from the first Pages build after
`track_renderer.gd` preloaded the new `Rail End.png`. Reference new textures from a
scene where possible, add anything a script must preload to `include_filter`, and
rely on `_test_export_preset_covers_preloads` in the regression suite, which fails
whenever a preload target is not covered.

To boot the exported build itself in a headless Chromium and confirm the level
starts with its railway and train (and logs no script errors):

```sh
tests/web_smoke.sh export/web
```

It serves `export/web` locally, opens `index.html?autostart` (which starts a new
campaign without a click), and checks the console for Main's `LEVEL READY` line.
Chromium is located through `$CHROME_BIN` or the Playwright browser cache.

Main also prints a `TRAIN MOTION` line once per level. Under Chrome's virtual clock
the page usually stops right after boot, so that line often never arrives in this
harness and its absence is reported as a note, not a failure; the script only fails
on a report that positively says the train stood still. A real windowed run
(`xvfb-run … tests/VisualCapture.tscn -- --no-dialogue --combat`) does print it, and
freezing is covered properly by `_test_convoy_never_self_blocks`, which drives a
three-car consist a full lap of every route on all ten campaign layouts.

## Runtime architecture

| Component | Responsibility |
|---|---|
| `LevelManager` | Global waypoint list and currency wallet |
| `BuildManager` | Global tower catalog and current shop selection |
| `UIManager` | Prevents board clicks passing through UI |
| `GameEvents` | Global `enemy_destroyed` signal used for wave accounting |
| `Main` | Generates the railway, spawns one TrainConvoy per route, routes car purchases to whichever train the drop lands near, registers coupled cars as obstacles with health, rebinds convoys after rail edits, and recovers wrecked engines when a locomotive is dropped on them |
| `EnemySpawner` | Wave timing, alive count, and a hand-tuned gentle-start difficulty/spawn-rate/HP curve |
| `EnemyMovement` + `Health` | Wave-scaled lane traversal speed, staged dot transformations, slowing, damage, death, bounty, plus train avoidance (sidestep to a clear lane), biting when boxed in, and ramming impacts |
| `TowerData` | Train shop data, scene, description, price, drag icon, weight, and workbook health |
| `TrackRenderer` | Owns the closed routes and the rail graph: authored/generated loops, STATIONS-built spurs, dead ends and join-closed detours; draws every cell from its connection set (straight, curve, buffer stop, junction pairs) and reroutes a ring when a longer player-built detour is joined |
| `RailBuilder` | STATION hover/plus construction, join markers for dead ends, right-click removal with refunds, and the specific refusal reasons |
| `TrainConvoy` | Reusable scene (`TrainConvoy.tscn`); each instance samples its engine and attached cars at fixed distances along a closed route, including safe acceleration and reversing, safe rebinding to a revised route, ramming impacts with recoil, and the wreck/recover states |
| `UnitHealth` | Hit points on every engine and coupled car, bite/ram damage, screen-oriented health bar and jaws marker, debris burst and caption on destruction |
| `RangePreview` + `CarPlacementGhost` | The real acquisition radius around a hovered or selected car and around the track-snapped placement preview |
| `CarArt` | One chassis/turret art source for shop rows, drag previews, ghosts, almanac cards and upgrade portraits |
| `TutorialDirector` + `DialogueOverlay` | Per-profile Duck and Daisy lessons with highlighted objectives, STATION scheduling, and replay |
| `BattlefieldOverlay` | Draws subdued spider-lane entrances, lane guides, and the station danger line |
| `Turret` + `Bullet` | Convoy following, target acquisition, rotation, firing, homing, and damage — base class for Chaingunner, Ballast, and Coal Cannon |
| `TurretMinigun` | The Chaingunner Car — seven-projectile spread burst followed by a four-second cooldown (filenames kept as Minigun, its earlier working name) |
| `TurretBallast` | Short-range area shotgun using the five illustrated ballast fragments |
| `TurretCoalCannon` + `CoalCannonball` | Slow-firing splash shot: full damage on direct hit, weaker damage to every other enemy within its blast radius |
| `PassengerCoach` | No weapon — passive Delta-income timer while attached and visible |
| `BrakeVan` | No weapon — caps its train's car count, grants every other car an attack-speed multiplier, and trims accel/coast time |
| `Tender` | No weapon — grants +500 carry capacity only when coupled directly behind the engine |
| `Menu` | Run HUD, shop drag gestures, STATION/BATTLE schedule, HP rail, remove-any-car mode, and the START WAVE control (offered in every STATION window, withdrawn during BATTLE and after the level ends) |
| `PhaseManager` | STATION/BATTLE clock with two holds: the level-complete pause and the lesson hold that stops only the automatic departure |

The roster is deliberately exactly the infowiki's documented turrets and cars (see
[Infowiki unit cards](infowiki-cards.md)) — Slomo (no card) and an earlier standalone
Chaingun car (redundant with the Chaingunner Car card) were both removed rather than
kept alongside them.

### Current visual language

- The separated `the_new_map.png` and `the_new_ui.png` layers now register a
  3840×2160 authored composition to the 1280×720 viewport. Crooked illustrated cabinets frame the courtyard, with the
  environmental painting deliberately secondary to the tabletop play area.
- The left panel is a scrollable Train Yard list of illustrated shop rows (icon, name,
  Delta price pill) rather than a fixed grid, so the roster can grow without the tray
  itself changing shape. The column is a stack of **non-overlapping regions**:
  currency, the scrolling unit list, a fixed-height selected-unit card
  (`Menu.DETAIL_PANEL_HEIGHT`), then BUILD TRACK and REMOVE UNIT. The card must never
  grow with its text — when it did, it took height from the list until shop rows sat
  underneath it and could not be reached. It shows only what a purchase decision needs
  (name, price, weight, health, range and the one-line `TowerData.summary`); the
  authored paragraphs live in `UnitLore` and are shown by the Almanac.
  **No shop control carries `tooltip_text`:** Godot's native tooltip rendered those
  multi-paragraph blurbs as a banner across the board, the Train Yard and the right
  panel, so the copy was moved into the card and the tooltips emptied. A locked card
  keeps its numbers and blurb and adds an "UNLOCKS AT STOP n" note. Every label in the
  card must wrap — a single-line label's minimum width would widen the whole column
  past its illustrated frame. Shop ranges are quoted in the cards' NxN grid notation
  (converted with the original 90-unit cell: 315 → 7×7), matching the lessons.
- **BUILD TRACK is a mode.** Construction markers are off the board during ordinary
  play; arming it shows plus signs on the hovered rail's free neighbours, outlines the
  circuit that rail belongs to, previews the tile under the cursor, and steps the
  Train Yard, portrait and to-do list back so the board is what reads. Starting a wave
  disarms it.
- The authored main line stays fully saturated; player-built rail is drawn lighter and
  less saturated (`TrackRenderer.PLAYER_BUILT_TINT`) so the two are never confused.
  Lane guides are deliberately faint. Each vehicle carries a small contact shadow and
  an ink ring — wider and darker on the locomotive, which is also drawn at a larger
  token size so it outranks its cars — with a slim drawbar coupler between them and a
  quiet spine threading the consist into one object. A brass stud marks every cell
  where three or more rails meet, so a junction never reads as two circuits passing
  close by. The station nameplate stands on posts in the band below the railway
  rather than on the sleepers.
- **Selection is a layer, not an overlay on the train.** Unselected: no arrows, no
  card, no track fading. Selected: four cyan corner brackets and a thin outline around
  the locomotive (never a filled disc over it), a compact card floating clear above it
  with the engine number and a weight bar, widely spaced direction arrows on that
  route only, and `TrackRenderer.set_route_focus()` lifting the ring that train drives
  while every other rail fades. `Main` sets and clears the focus with the selection.
- The right panel runs a STATION/BATTLE schedule panel (phase dots, a conductor
  portrait that swaps per phase, and a SKIP WAIT / IN PROGRESS action button) above a
  to-do checklist tracking the run's live objectives.
- An illustrated HP rail sits between the board and the right panel.
- The board carries two independent trains on separate closed-loop tracks generated
  every run. Engines use one of 25 authored liveries (matching the infowiki Steam
  Engine card's "25 unique paint jobs") drawn without replacement, so no two engines
  on the board share a color. Dropping a purchased car attaches it to whichever
  train's engine or connected cars the drop lands near — there is no separate "select
  a train" step.
- The engine emits smoke; chunky cars receive varied comic-book colors, stay aligned
  to their train's route, and are spaced by physical length with visible couplers.
- Spiders animate and flash on hits. Gunfire, kills, bounty rewards, station damage,
  and crooked white gun tracers all provide immediate feedback.
- Architects Daughter handwriting, thick outlines, warm burgundy, bright cyan,
  and paper yellow unify the interface with the supplied illustrated reference.
- The opening composition starts both trains stationary — the first with one free
  Gunner Car already attached, the second bare — with a Δ450 bankroll and combat
  paused until the player presses START WAVE. Waves 1–4 ramp gently (3/5/7/10 slow,
  low-health spiders, generous bounty and a wave-completion bonus) before the
  original difficulty curve resumes.

## Active scenes

| Scene | Current content |
|---|---|
| `TitleScreen.tscn` | Illustrated title mock-up with mouse/keyboard Start, Challenges, Options, and platform-aware Quit controls |
| `Main.tscn` | Fitted board, generated railway, default black engine, station, spawner, and gutter HUD |
| `Enemy.tscn` | Shared scene for nine campaign-unlocked spider archetypes, including staged dots and special behaviors |
| `Turret.tscn` | Gunner Car — normalized art, 315-unit detection area, bullet scene |
| `TurretMinigun.tscn` | Chaingunner Car — 315-unit range, seven minigun bullets per burst |
| `TurretBallast.tscn` | Purple/yellow close-range car with a 135-unit area blast |
| `TurretCoalCannon.tscn` | 225-unit range, ~4.5s cooldown, weight 225, fires `CoalCannonball.tscn` |
| `PassengerCoach.tscn` | Weight 125, pays Δ50 every 10 seconds while coupled |
| `BrakeVan.tscn` | Weight 0, caps its train, +20% attack speed, ×0.85 accel/coast time |
| `Tender.tscn` | Weight 50, no weapon — +500 capacity only as the car directly behind the engine |
| `Bullet.tscn` | Homing gunner projectile with enemy collision mask |

## Known gaps and risks

The failure presentation now slightly darkens the live battlefield and fades in the
supplied `GAME_OVER_TEXT` artwork. Restart/retry and Main Menu remain interactive
actions beneath the title treatment.

- The Train Yard list can attach all eight documented cars (Gunner Car, Chaingunner
  Car, Ballast Blaster, Coal Cannon, Passenger Coach, Brake Van, Tender, Mail Carrier).
  A car the campaign has not granted yet is **hidden from the yard entirely** — it used
  to sit there as a dimmed "STOP n" preview, which filled the list with rows the player
  could not use and pushed the usable ones out of view. Every card on screen is one that
  can be bought right now; the Almanac is where the rest of the roster is browsed.
  Cars have a run-local upgrade/sell card; REMOVE detaches whichever car is clicked,
  without a refund, and there is no manual reordering.
- STATIONS rail building is implemented with the proposed join/reroute/removal rules in
  [Systems and balance](systems-and-balance.md#rail-building-during-stations). Trains
  still drive closed rings only: there is no junction switching, no shuttle movement
  on dead ends, and no collision between two trains sharing a cell. The Δ50 price is
  provisional and rail inventory is unlimited.
- Spiders steer round trains and bite when boxed in; engines and cars carry workbook
  health, destroyed cars drop out of the consist and wrecked engines can be recovered.
  All numbers are the notes' provisional figures. The Barrier Car, the workbook's
  other new units, Strong/All/Webs targeting priorities and Coal knockback probability
  are not implemented.
- Guns acquire the nearest spider within their documented radius. The earlier build
  acquired through the car's scaled physics area (about half the radius), so range
  balance has effectively changed and needs a playtest.
- Gunner and Chaingunner render the same chassis/turret pair everywhere (shop row,
  drag preview, ghost, almanac, upgrade card, placed car). The updated artwork Gubgub
  added to the shared Drive is not in the repository yet; once imported as chassis
  and turret pieces it replaces `Gunner Car Base/Top` and `Minigun Base/Top`.
- Spiders stop at the station and attack it repeatedly rather than disappearing.
  They remain targetable and keep the wave active until killed. Station HP is a
  separately tunable 60-point pool; no station gun has been added.
- Campaign boards use deterministic artist-reference layouts and receive one train
  per closed circuit. Additional locomotives are purchasable and can be parked on any
  free ring, including a player-built one.
- Spider bounties and the workbook's cost/carry/buff differences are unchanged pending
  the designer decisions in [roadmap blockers](../docs/roadmap-blockers.md).

Resolved this session (were previously listed here): the slow effect now reduces
speed relative to each enemy's own base speed and safely extends under overlapping
pulses rather than racing; a homing bullet whose target disappears now frees itself
instead of drifting forever. The board, spider frame, trains, projectile,
colliders, lanes, render layers, and HUD are also normalized around a 1280×720
logical viewport. The full portrait board is fitted by height; its side gutters are
reserved for interface rather than cropped away.

See [Roadmap](../roadmap.md) for planned work rather than treating these gaps as
settled solutions.

## Illustrated almanac and profile guidance

The title-screen Almanac uses the supplied parchment/railway reference, with Enemies,
Train Cars, Defenses, and Tracks tabs, a scrollable two-column grid (one on narrow
windows), per-tab discovery counts, and selectable discovered-entry details.
Unseen units remain anonymous and show no actual unit artwork or stats. Entries use
current game sprite resources, including both layers of placed turrets, and are
revealed only after appearing in that profile's run. Browsing the almanac does not
discover content. See [assets and behavior](../docs/almanac-assets.md).

Selecting a different profile reloads its discoveries and restarts its tutorial
lessons without resetting campaign progress. Selecting the same profile preserves
lesson progress; later saved levels introduce their unlocked cars again.
