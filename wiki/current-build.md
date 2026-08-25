# Current Build

[Wiki home](README.md)

## Status

The active codebase is a Godot 4 scaffold port of the archived Unity prototype. Its
main scene contains one board, five route markers, three build plots, one enemy
spawner, and a currency label. The port closely preserves the eleven original Unity
gameplay scripts as GDScript plus four autoload managers.

The build should be treated as a scaffold rather than a finished playable slice. In
particular, `BuildManager.towers` has no checked-in resource entries, so clicking a
plot may fail until the tower catalog is configured.

## Running the project

With a compatible Godot 4 executable installed:

```sh
godot --editor --path .
```

For a headless startup check:

```sh
godot --headless --path . --quit-after 60
```

The configured entry scene is `scenes/Main.tscn`. No Web export preset is currently
checked in.

## Runtime architecture

| Component | Responsibility |
|---|---|
| `LevelManager` | Global waypoint list and currency wallet |
| `BuildManager` | Global tower catalog and current shop selection |
| `UIManager` | Prevents board clicks passing through UI |
| `GameEvents` | Global `enemy_destroyed` signal used for wave accounting |
| `Main` | Copies scene path markers into `LevelManager` |
| `EnemySpawner` | Wave timing, scaling, spawning, and alive count |
| `EnemyMovement` + `Health` | Route traversal, slowing, damage, death, and bounty |
| `Plot` + `TowerData` | Buying the selected defense on a build tile |
| `Turret` + `Bullet` | Target acquisition, rotation, firing, homing, and damage |
| `TurretSlomo` | Periodic area slow without damage |
| `Menu` | Currency text and optional panel animation |

## Active scenes

| Scene | Current content |
|---|---|
| `Main.tscn` | Board, route, three plots, spawner, currency label |
| `Plot.tscn` | Clickable 96×96 build region using rail art |
| `Enemy.tscn` | Generic spider body with 2 HP and 50 bounty defaults |
| `Turret.tscn` | Gunner art, 80-pixel detection area, bullet scene |
| `TurretSlomo.tscn` | White steam-engine art and 80-pixel slow area |
| `Bullet.tscn` | Homing gunner projectile with enemy collision mask |

## Known gaps and risks

- No tower catalog is serialized into `BuildManager`.
- No base health or penalty for leaked enemies.
- No win, loss, pause, restart, or speed-control flow.
- Upgrade methods exist, but no upgrade panel is wired in `Turret.tscn`.
- The wave number, countdown, and enemy count are not displayed.
- Only one generic enemy is spawnable; most art has no gameplay scene.
- Target selection uses the first overlapping physics body, with no explicit
  first/last/strongest targeting policy.
- The slow sets speed to an absolute `0.5`, not 50% of each enemy's base speed;
  overlapping reset timers may also restore speed earlier than expected.
- A homing bullet whose target disappears remains alive because it has no fallback
  lifetime or cleanup path.
- Route completion and enemy death share one event. That is adequate for wave
  accounting, but cannot distinguish kills from leaks.

See [Roadmap](../roadmap.md) for planned work rather than treating these gaps as
settled solutions.
