# Battle Stations

Battle Stations is a railway-themed tower-defense prototype being migrated from
Unity to Godot 4.

## Project guide

- [Wiki home](wiki/README.md) — the consolidated source of truth
- [Roadmap](roadmap.md) — planned development phases
- [Roadmap blockers](docs/roadmap-blockers.md) — external evidence and decisions still required
- [Run the current project](wiki/current-build.md#running-the-project)
- [Original Discord research](docs/research/discord-gubgub-notes.md) — preserved source notes

The active project is the Godot project at the repository root. The original Unity
snapshot is retained under [`legacy_unity/`](legacy_unity/) for provenance.

## Validation

Run the headless gameplay and content-catalog regression suite from the repository
root:

```sh
godot --headless --path . tests/GameplayRegression.tscn
```

After exporting the Web build, boot it in headless Chromium to confirm the exported
pack starts a level with its railway and train:

```sh
godot --headless --path . --export-release "Web" export/web/index.html
tests/web_smoke.sh export/web
```

## Folder layout

- `scenes/`, `scripts/`, `resources/` — active Godot game and data.
- `assets/` — runtime art, fonts, and audio; dialogue portraits live in `assets/sprites/ui/portrait/`.
- `assets/_reference/` — source artwork, archives, and models, excluded from Godot imports.
- `tests/` — gameplay regression, profiling, and visual checks.
- `docs/` — development guides, screenshots, and original research.
- `wiki/` — game design, current behavior, and asset provenance.
- `legacy_unity/` — preserved Unity source snapshot.
- `export/` and `.godot/` — generated output, ignored by Git.

Documentation and legacy folders contain `.gdignore` files to keep them out of
Godot's resource scan. Keep Godot `.import` settings and script `.uid` files with
their source assets when moving files.
