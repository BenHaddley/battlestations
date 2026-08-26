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

The configured entry scene is `scenes/Main.tscn`. A Web export preset is checked in
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
| `Main` | Validates convoy drops, purchases cars, and attaches them to the engine |
| `EnemySpawner` | Wave timing, scaling, spawning, and alive count |
| `EnemyMovement` + `Health` | Route traversal, slowing, damage, death, and bounty |
| `TowerData` | Train shop data, scene, description, price, and drag icon |
| `TrackRenderer` | Generates a connected courtyard railway with straight and curved tiles; highlights valid drop targets |
| `TrainConvoy` | Moves the default black engine and makes attached cars follow its movement history |
| `BattlefieldOverlay` | Draws subdued spider-lane entrances, lane guides, and the station danger line |
| `Turret` + `Bullet` | Convoy following, target acquisition, rotation, firing, homing, and damage |
| `TurretSlomo` | Convoy following and periodic area slow without damage |
| `Menu` | Run HUD, shop drag gestures, selected-train details, and wave control |

### Current visual language

- Crooked illustrated wooden cabinets frame a camera-enlarged courtyard, with the
  environmental painting deliberately secondary to the tabletop play area.
- The left cabinet is a saturated cyan/yellow two-column card rack. Gunner and Slomo
  are functional; six illustrated cards visibly preview the future roster but remain disabled.
- The right cabinet is limited to illustrated playback controls, a conductor tutorial,
  route progress, and a large paper `CHALLENGES` area.
- Each generated route makes four or five connected passes through the courtyard,
  using narrow straight and curved pieces to create a dense railway puzzle.
- The engine emits smoke; chunky cars receive varied comic-book colors, stay aligned
  to the route, and are spaced by physical length with visible couplers.
- Spiders animate and flash on hits. Gunfire, kills, bounty rewards, station damage,
  and Slomo's rough hand-drawn arrow burst all provide immediate feedback.
- A recovered crayon-style display font, thick outlines, warm burgundy, bright cyan,
  and paper yellow unify the interface with the supplied illustrated reference.

## Active scenes

| Scene | Current content |
|---|---|
| `Main.tscn` | Fitted board, generated railway, default black engine, station, spawner, and gutter HUD |
| `Enemy.tscn` | Generic spider body with 2 HP and 50 bounty defaults |
| `Turret.tscn` | Normalized Gunner art, 360-unit detection area, bullet scene |
| `TurretSlomo.tscn` | Normalized white-engine art and 360-unit slow area |
| `Bullet.tscn` | Homing gunner projectile with enemy collision mask |

## Known gaps and risks

- The first shop can attach Gunner and Slomo cars with image previews, but has no
  refunds, upgrade information, consist-length limit, or car reordering.
- There is no victory or restart flow. Playback controls are present, while the
  wider run-state flow remains prototype-level.
- Upgrade methods exist, but no upgrade panel is wired in `Turret.tscn`.
- Wave number and remaining spiders are displayed, but there is no countdown.
- Only one generic enemy is spawnable; most art has no gameplay scene.
- Target selection uses the first overlapping physics body, with no explicit
  first/last/strongest targeting policy.
- Route completion and enemy death share one event. That is adequate for wave
  accounting, but cannot distinguish kills from leaks.

Resolved this session (were previously listed here): the slow effect now reduces
speed relative to each enemy's own base speed and safely extends under overlapping
pulses rather than racing; a homing bullet whose target disappears now frees itself
instead of drifting forever. The board, spider frame, trains, projectile,
colliders, lanes, render layers, and HUD are also normalized around a 1280×720
logical viewport. The full portrait board is fitted by height; its side gutters are
reserved for interface rather than cropped away.

See [Roadmap](../roadmap.md) for planned work rather than treating these gaps as
settled solutions.
