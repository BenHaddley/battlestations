# Current Build

[Wiki home](README.md)

## Status

The active codebase is a Godot 4 scaffold port of the archived Unity prototype. Its
main scene contains one fitted board, seven vertical enemy lanes, a randomized bounded railway, one enemy
spawner, a defended station, and a two-gutter HUD/shop. The port closely preserves the eleven original Unity
gameplay scripts as GDScript plus four autoload managers.

The build should be treated as a scaffold, not a finished playable slice — but the
core drag → deploy → patrol → shoot/slow → kill → currency → wave-scaling loop is now verified
working end to end, including in an actual Web-exported browser build (see
[Roadmap, Phase 4](../roadmap.md) for the full verification notes and the bugs that
testing-in-browser caught that code review and the editor alone did not).

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
Pages on push to `main`, once the repo is pushed to GitHub with Pages enabled.

## Runtime architecture

| Component | Responsibility |
|---|---|
| `LevelManager` | Global waypoint list and currency wallet |
| `BuildManager` | Global tower catalog and current shop selection |
| `UIManager` | Prevents board clicks passing through UI |
| `GameEvents` | Global `enemy_destroyed` signal used for wave accounting |
| `Main` | Generates the railway, spawns one TrainConvoy per route, and routes car purchases to whichever train the drop lands near |
| `EnemySpawner` | Wave timing, alive count, and a hand-tuned gentle-start difficulty/spawn-rate/HP curve |
| `EnemyMovement` + `Health` | Wave-scaled lane traversal speed, staged dot transformations, slowing, damage, death, and bounty |
| `TowerData` | Train shop data, scene, description, price, and drag icon |
| `TrackRenderer` | Builds 2+ closed concentric oval railway loops inside the playable board, validated for lane coverage and full-loop traversability |
| `TrainConvoy` | Reusable scene (`TrainConvoy.tscn`); each instance moves its own engine along its own route and makes its attached cars follow its movement history |
| `BattlefieldOverlay` | Draws subdued spider-lane entrances, lane guides, and the station danger line |
| `Turret` + `Bullet` | Convoy following, target acquisition, rotation, firing, homing, and damage — base class for Chaingunner, Ballast, and Coal Cannon |
| `TurretMinigun` | The Chaingunner Car — seven-projectile spread burst followed by a four-second cooldown (filenames kept as Minigun, its earlier working name) |
| `TurretBallast` | Short-range area shotgun using the five illustrated ballast fragments |
| `TurretCoalCannon` + `CoalCannonball` | Slow-firing splash shot: full damage on direct hit, weaker damage to every other enemy within its blast radius |
| `PassengerCoach` | No weapon — passive Delta-income timer while attached and visible |
| `BrakeVan` | No weapon — caps its train's car count, grants every other car an attack-speed multiplier, and trims accel/coast time |
| `Tender` | No weapon — grants +500 carry capacity only when coupled directly behind the engine |
| `Menu` | Run HUD, shop drag gestures, STATION/BATTLE schedule, HP rail, remove-any-car mode, and wave control |

The roster is deliberately exactly the infowiki's documented turrets and cars (see
[Infowiki unit cards](infowiki-cards.md)) — Slomo (no card) and an earlier standalone
Chaingun car (redundant with the Chaingunner Car card) were both removed rather than
kept alongside them.

### Current visual language

- Crooked illustrated wooden cabinets frame a camera-enlarged courtyard, with the
  environmental painting deliberately secondary to the tabletop play area.
- The left panel is a scrollable Train Yard list of illustrated shop rows (icon, name,
  Delta price pill) rather than a fixed grid, so the roster can grow without the tray
  itself changing shape.
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

- The Train Yard list can attach all seven cars documented in the infowiki (Gunner Car,
  Chaingunner Car, Ballast Blaster, Coal Cannon, Passenger Coach, Brake Van, Tender —
  see [Infowiki unit cards](infowiki-cards.md)). There is no per-car upgrade system — it was
  removed entirely (it was dead code left over from the click-to-place Plot design
  that predates the drag/drop train convoy, and had no reachable UI). REMOVE now
  detaches whichever car is clicked, anywhere in the train, not just the tail; there
  are still no refunds (a removed car's cost is not returned) or manual reordering.
- There is no victory or restart flow. Playback controls are present and waves now
  advance automatically, while the wider run-state flow remains prototype-level.
- Wave number and remaining spiders are displayed, but there is no countdown.
- All supplied spider artwork is spawnable through one shared scene and the
  campaign-weighted `EnemyRoster`; specialist roles unlock progressively.
- Target selection uses the first overlapping physics body, with no explicit
  first/last/strongest targeting policy.
- Route completion and enemy death share one event. That is adequate for wave
  accounting, but cannot distinguish kills from leaks.
- Trains are fixed at 2 for the whole run — there is no purchasable third or
  fourth engine, and no true track junctions/switches (each train's route is
  a single reversing path, not a branching network a train chooses between).
- Attaching a car targets whichever train's radius the drop lands in; there is
  no explicit click-to-select-train step or highlight, so two trains parked
  very close together could make a drop ambiguous.

Resolved this session (were previously listed here): the slow effect now reduces
speed relative to each enemy's own base speed and safely extends under overlapping
pulses rather than racing; a homing bullet whose target disappears now frees itself
instead of drifting forever. The board, spider frame, trains, projectile,
colliders, lanes, render layers, and HUD are also normalized around a 1280×720
logical viewport. The full portrait board is fitted by height; its side gutters are
reserved for interface rather than cropped away.

See [Roadmap](../roadmap.md) for planned work rather than treating these gaps as
settled solutions.
