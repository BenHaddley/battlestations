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
| `TrackRenderer` | Builds 2+ short, modular railway routes (straights, bends, U-shapes, loops) placed in separate board bands, validated for lane coverage and traversability |
| `TrainConvoy` | Reusable scene (`TrainConvoy.tscn`); each instance moves its own engine along its own route and makes its attached cars follow its movement history |
| `BattlefieldOverlay` | Draws subdued spider-lane entrances, lane guides, and the station danger line |
| `Turret` + `Bullet` | Convoy following, target acquisition, rotation, firing, homing, and damage — base class for Minigun, Ballast, Coal Cannon, and Chaingun |
| `TurretMinigun` | Five-projectile spread burst followed by a three-second cooldown |
| `TurretBallast` | Short-range area shotgun using the five illustrated ballast fragments |
| `TurretSlomo` | Convoy following and periodic area slow without damage |
| `TurretCoalCannon` + `CoalCannonball` | Slow-firing splash shot: full damage on direct hit, weaker damage to every other enemy within its blast radius |
| `TurretChaingun` | Plain `Turret` subclass with no `_shoot()` override — just a much higher `bps` for sustained single-target DPS, no burst/cooldown pattern |
| `PassengerCoach` | No weapon — passive income timer while attached and visible |
| `BrakeVan` | No weapon — caps its train's car count and grants every other car on it an attack-speed multiplier |
| `Tender` | No weapon — negative `weight` offsets other cars', raising the effective weight threshold before the train slows |
| `Menu` | Run HUD, shop drag gestures, selected-train details, remove-any-car mode, and wave control |

### Current visual language

- Crooked illustrated wooden cabinets frame a camera-enlarged courtyard, with the
  environmental painting deliberately secondary to the tabletop play area.
- The left cabinet is a saturated cyan/yellow 2×5 card tray with deliberately
  uneven borders, crooked pieces, and three handwritten joke cards. Gunner and Slomo
  are functional; eight cards visibly preview the future roster but remain disabled.
  A burgundy `REMOVE` strip detaches the tail car, above a deliberately exaggerated
  blue points readout.
- Each tray slot carries stable paper flecks, dry-brush streaks, an imperfect ink
  keyline, and oversized artwork that pushes beyond its yellow well.
- The right cabinet holds illustrated playback controls, a conductor tutorial,
  route progress, a large paper `CHALLENGES` area with checkbox goals, and a
  burgundy gem/currency strip pinned along its bottom edge.
- The board now carries two independent trains on two separate short routes
  (a random module — short/long straight, L-bend, U-shape, rectangle loop, or
  compact circuit — per route, placed in its own horizontal band) instead of
  one long path spanning the whole courtyard. `TrackRenderer.generate_layout()`
  retries until every spider lane is reachable and every route is internally
  connected before Main accepts the layout.
- Engines are tinted per train so two trains are never visually ambiguous even
  before either has any cars attached. Dropping a purchased car attaches it to
  whichever train's engine or connected cars the drop lands near — there is no
  separate "select a train" step.
- The engine emits smoke; chunky cars receive varied comic-book colors, stay aligned
  to their train's route, and are spaced by physical length with visible couplers.
- Spiders animate and flash on hits. Gunfire, kills, bounty rewards, station damage,
  crooked white gun tracers, and Slomo's rough hand-drawn arrow burst all provide
  immediate feedback.
- Architects Daughter handwriting, thick outlines, warm burgundy, bright cyan,
  and paper yellow unify the interface with the supplied illustrated reference.
- The opening composition starts both trains stationary — the first with one free
  Gunner already attached, the second bare — with a $300 bankroll and combat paused
  until the player presses START WAVE. Waves 1–4 ramp gently (3/5/7/10 slow,
  low-health spiders, generous bounty and a wave-completion bonus) before the
  original difficulty curve resumes.

## Active scenes

| Scene | Current content |
|---|---|
| `TitleScreen.tscn` | Illustrated title mock-up with mouse/keyboard Start, Challenges, Options, and platform-aware Quit controls |
| `Main.tscn` | Fitted board, generated railway, default black engine, station, spawner, and gutter HUD |
| `Enemy.tscn` | Six-to-one-dot spider with 15 HP, staged transformations, and 25 bounty |
| `Turret.tscn` | Normalized Gunner art, 360-unit detection area, bullet scene |
| `TurretSlomo.tscn` | Normalized white-engine art and 360-unit slow area |
| `TurretMinigun.tscn` | Red rotating burst car, 330-unit range, five minigun bullets |
| `TurretBallast.tscn` | Purple/yellow close-range car with a 190-unit area blast |
| `TurretCoalCannon.tscn` | 340-unit range, ~4.5s cooldown, weight 2.0, fires `CoalCannonball.tscn` |
| `TurretChaingun.tscn` | 300-unit range, 1.5 bullets/sec continuous, fires `ChaingunBullet.tscn` |
| `PassengerCoach.tscn` | Weight 1.0, pays $50 every 10 seconds while coupled |
| `BrakeVan.tscn` | Weight 0.0, caps its train and grants +20% attack speed to the rest of it |
| `Tender.tscn` | Weight -2.0, no weapon — pure hauling-capacity utility car |
| `Bullet.tscn` | Homing gunner projectile with enemy collision mask |

## Known gaps and risks

- The tray can attach all seven original cars (Gunner, Slomo, Minigun, Ballast
  Blaster, Coal Cannon, Passenger Coach, Brake Van). Chaingun and Tender exist as
  complete `TowerData` entries in `BuildManager.towers` and are fully playable if
  attached programmatically, but the 2×5 shop grid is full — there is no tray slot
  wired up to purchase them yet. There is no per-car upgrade system — it was
  removed entirely (it was dead code left over from the click-to-place Plot design
  that predates the drag/drop train convoy, and had no reachable UI). REMOVE now
  detaches whichever car is clicked, anywhere in the train, not just the tail; there
  are still no refunds (a removed car's cost is not returned) or manual reordering.
- There is no victory or restart flow. Playback controls are present and waves now
  advance automatically, while the wider run-state flow remains prototype-level.
- Wave number and remaining spiders are displayed, but there is no countdown.
- Only one generic enemy is spawnable; most art has no gameplay scene.
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
