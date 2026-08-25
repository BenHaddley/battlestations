# Battle Stations — Roadmap

This roadmap takes the active Godot scaffold from recovered prototype to a releasable
game. The [project wiki](wiki/README.md) is the source of truth for verified behavior,
content, history, and unresolved decisions; the roadmap describes proposed work.

The original Unity snapshot remains in [`legacy_unity/`](legacy_unity/). Do not add
features merely because an asset filename suggests them: confirm the design or mark
the interpretation as a proposal in the wiki.

## Working rules

- Keep every phase playable before advancing to the next.
- Update the wiki alongside mechanic, balance, content, or provenance changes.
- Separate recovered facts from new design decisions.
- Test in the browser once Web export exists, not only in the editor.
- Record playtest observations before changing balance formulas.

---

## Phase 0 — Recovery and migration ✅ complete

- [x] Snapshot the Unity source under `legacy_unity/`.
- [x] Port the eleven gameplay scripts to GDScript.
- [x] Rebuild the main gameplay scenes in Godot 4.
- [x] Migrate usable art and audio into `assets/`.
- [x] Consolidate implementation, history, content, and open questions into the
      [wiki](wiki/README.md).

The result is a useful scaffold, not yet a complete playable build. In particular,
the checked-in tower catalog is empty and the targeting values use inconsistent
units.

---

## Phase 1 — Make the scaffold playable and trustworthy

**Goal:** a repeatable editor build whose existing loop works without manual scene
configuration or known unit-scale errors.

### Configuration and correctness

- [x] Choose and document the supported Godot version: **4.7.2**, installed locally
      with matching Web export templates. `project.godot`'s `4.3` features string is
      just Godot's own minimum-compatibility tag, not a version pin — unrelated.
- [x] Add checked-in `TowerData` resources for the Gunner and slow defense
      (`resources/basic_turret.tres`, `resources/slomo_turret.tres`), configure
      `BuildManager.towers`, and expose both through the gutter shop UI.
- [x] Establish one world-unit convention for movement, bullet speed, and targeting:
      360-unit targeting range, 900-unit/s bullets, 180-unit/s enemy movement, consistent
      across `Turret`, `TurretSlomo`, `Bullet`, `Enemy.tscn` overrides.
- [x] Ensure a turret can acquire, retain, and hit an enemy across its intended
      range — confirmed via live browser playtest logs (see Phase 4 below).
- [x] Give orphaned homing bullets a cleanup path when their target disappears
      (`Bullet._physics_process` now frees itself if `target` is no longer valid).
- [x] Make slow effects relative to enemy base speed and safe under overlapping
      pulses: `EnemyMovement.apply_slow(duration)` tracks a slow-expiry timestamp
      that a later pulse can only extend, never shorten; speed is `base_speed * 0.5`
      while active, not an absolute `0.5`.
- [x] Guard invalid shop data and charge only after a train is dropped on a valid rail.

### Minimal interface

- [x] Display current currency with clear purchase failure feedback (`push_warning`
      on insufficient funds; HUD label updates live via `Menu`).
- [x] Display which defense is selected and the cost of each option.
- [x] Replace the unwired menu-animation hooks with an intentional two-gutter HUD.
- [x] Normalize the full board, one-frame spider art, trains, projectiles,
      colliders, render order, and seven top-to-bottom lanes around a 1280×720 viewport.
- [x] Spawn one default black engine and replace fixed build pads with convoy
      drag/drop; attached combat cars follow its route history as a trailing consist.

### Verification

- [ ] Add lightweight automated coverage for wallet operations, wave formulas,
      upgrade formulas, and invalid build selections.
- [x] Run a headless startup check with zero errors or warnings caused by the game
      (`godot --headless --path . --quit-after 60`, clean after an import pass).
- [x] Complete a manual smoke test: buy a defense, shoot a spider, apply a slow,
      receive a bounty, and advance to wave two — done as a full **Web-exported
      browser** playtest (stronger than an editor-only check), see Phase 4.
      Repeat both purchase paths after the visual-foundation browser export.

**Exit criterion:** a fresh clone opens and runs the existing combat loop without
editor-only setup, and the implemented values agree with
[Systems and balance](wiki/systems-and-balance.md).

---

## Phase 2 — Close the core run loop

**Goal:** a run can be understood, won or lost, and restarted.

### Run state

- [ ] Separate enemy **killed** and **leaked** events; keep both usable for wave
      accounting while only kills award currency.
- [ ] Add base health and apply damage when a spider reaches the final waypoint.
- [ ] Define and implement a loss condition at zero base health.
- [ ] Decide the initial victory model: finite final wave or endless score chase.
- [ ] Add game-over/victory UI with restart and return-to-menu actions.
- [ ] Prevent building, shooting, and spawning after the run ends.

### Player feedback

- [ ] Show base health, wave number, remaining enemies, and next-wave countdown.
- [ ] Build and wire the Gunner upgrade panel: current level, current stats, next
      values, next price, affordability, and purchase action.
- [ ] Wire pause and speed controls using the existing UI art; define supported
      speeds and ensure timers behave consistently.
- [ ] Add an explicit wave-start cue.

### First balance baseline

- [ ] Fix or intentionally confirm bullet travel speed, enemy speed, range, bounty,
      tower prices, and upgrade values after the unit-scale correction.
- [ ] Play waves 1–10 and record results before retuning the inherited formulas.
- [ ] Document the first intentional balance baseline in the wiki.

**Exit criterion:** a new player can complete or lose a run without explanation and
always knows the run state and available actions.

---

## Phase 3 — Resolve the product direction

**Goal:** decide what Battle Stations fundamentally is before building the full
roster. This phase is intentionally a gate.

The current direction is now mobile rail defense: one default black engine patrols a
procedurally generated courtyard railway, and shop cars attach behind it while fighting spiders. The lost
concept sheet's coupled-car capacities may extend this model later, but are not yet
implemented.

- [x] Choose coupled mobile rail defense over stationary plots: attach shop cars to
      the default engine and let the whole consist patrol automatically.
- [ ] Decide whether later trains become coupled multi-car consists or remain
      ordered cars sharing one engine-led consist.
- [ ] Decide whether runs use one board, multiple authored levels, or endless boards.
- [ ] Define the role of engines and whether the eleven liveries are cosmetic.
- [ ] Define intended roles for the initial defense and spider roster. Mark any new
      interpretation as new design rather than recovered canon.
- [ ] Write a one-page design brief covering player objective, placement/movement,
      roster roles, progression, victory, and defeat.
- [ ] Update [Game overview](wiki/game-overview.md) and close the relevant entries in
      [Open questions](wiki/open-questions.md).

### Recovery work that informs the decision

- [ ] Search Gubgub's separate Discord server `battle stations` channel.
- [ ] Check the old PC/backups for a later project and the deleted concept sheet.
- [ ] Identify the former Twitter/X account and preserve any public project material.
- [ ] Record recovered sources with date, author, and limitations under
      `wiki/sources/`.

Recovery should inform the decision but not block it indefinitely. If sources cannot
be recovered, explicitly choose a direction and record it as new design.

**Exit criterion:** the team can explain the core game in one paragraph and evaluate
every proposed feature against that definition.

---

## Phase 4 — Browser build and continuous delivery

**Goal:** every later milestone is playable at a shareable URL.

- [x] Install the Web export templates matching the chosen Godot version (4.7.2,
      `~/.local/share/godot/export_templates/4.7.2.stable/`).
- [x] Add and commit an HTML5 export preset (`export_presets.cfg`, single-threaded
      variant so no cross-origin-isolation headers are required to serve it).
- [ ] Test input, texture import, viewport scaling, save storage, and audio autoplay
      in at least two desktop browsers. Verified so far only in headless Chromium
      (via Playwright) — real desktop-browser passes (esp. audio autoplay, which
      Chromium/Firefox gate differently) are still outstanding.
- [ ] Confirm pause and speed controls work in Web export — blocked on those controls
      existing at all (Phase 2).
- [x] Create a repeatable export command:
      `godot --headless --path . --export-release "Web" export/web/index.html`.
- [x] Host target decided: **GitHub Pages**, not itch.io. A build-and-deploy workflow
      is checked in at `.github/workflows/deploy-pages.yml` (push to `main` → export →
      deploy). Not yet live — needs this repo pushed to GitHub with Pages enabled
      (Settings → Pages → Source: GitHub Actions) before the workflow can run.
- [ ] Add a short browser smoke-test checklist to the repository.

### Verified in a live Web-exported browser build (headless Chromium, this session)

Full playthrough of waves 1–2, confirmed via console logging then re-verified
debug-free. The placement model has since advanced: drag Gunner from the shop → drop
onto the engine/consist → currency spent → car joins the tail and visibly follows;
the turret acquires
and fires on the first spider to enter its 300-unit range; kills pay a 50-currency
bounty (currency climbed 50 → 600 across the run); Slomo Turret pulses and visibly
halves enemy velocity; wave 2 sizing/pace matched the formula exactly (13 enemies @
0.84/s for `round(8 * 2^0.75)` and `0.5 * 2^0.75`).

Bugs found and fixed only by testing the actual exported build, not visible from
reading the code or from the editor alone:
- `Viewport.physics_object_picking` defaults off — no `Plot` click ever registered
  without it, silently.
- A full-rect `Menu` `Control` defaulted to `MOUSE_FILTER_STOP`, swallowing every
  click on the board underneath it before picking even ran.
- Hand-written `NodePath("...")` literals assigned to typed-`Node` `@export` vars in
  `.tscn` files do **not** resolve — that inspector node-picker convenience only
  works when the editor itself writes the reference. Every such export (`Turret`,
  `TurretSlomo`, `Plot`, `EnemyMovement`, `Menu`) silently stayed `null`. Fixed by
  switching to `@onready var x := $NodePath` for in-scene references, and to
  explicit code wiring in `main.gd` for the one genuine cross-tree reference
  (`EnemySpawner.start_point`).
- `EnemySpawner._spawn_enemy()` incremented `enemies_alive` even when it silently
  no-op'd on a null `start_point` — waves reported enemies "alive" that never
  actually existed in the scene.
- Unity's original tuning values (`targeting_range: 5`, `bullet_speed: 5`,
  `move_speed: 1`) are meaningless at this project's world scale (hundreds of
  pixels apart); nothing could ever have been in range or arrived in finite time
  until these were rescaled.

**Exit criterion:** a clean checkout can produce the same Web build, and the hosted
version passes the complete Phase 2 run-loop test.

---

## Phase 5 — Build the first intentional roster

**Goal:** meaningful strategic choices, selected according to the Phase 3 design
brief—not one mechanic reskinned repeatedly.

### Defenses or train cars

- [ ] Choose 3–4 launch candidates from Gunner, Coal Cannon, Minigun, Ballast
      Blaster, Brake Van, Oil Tanker, Passenger Coach, and Slate Return.
- [ ] Write a compact specification for each: role, cost, range, cadence, effect,
      upgrade identity, strengths, and counterplay.
- [ ] Implement each as data plus a scene, sharing behavior where appropriate.
- [ ] Include at least three genuinely distinct functions, such as direct damage,
      area damage, control, piercing, economy, or support.
- [ ] Add clear shop icons, stat summaries, placement previews, and affordability
      states.

### Enemies

- [ ] Choose an initial set from Generic, Baby, Charger, Rally, Roller, Sturdy, Wolf,
      Jump, and Egg.
- [ ] Give each selected enemy an explicit gameplay role, stats, bounty, and visual
      feedback.
- [ ] Replace uniform random spawning with authored wave composition or documented
      wave-based unlock rules.
- [ ] Add any special behavior only after its counterplay is available to the player.
- [ ] Decide whether to retain or replace the current spider art before a large
      animation-polish pass.

### Balance and testing

- [ ] Move balance values into inspectable data resources rather than scattering them
      through scene and script defaults.
- [ ] Add a debug wave selector and enough telemetry to record spending, leaks, kills,
      and wave reached.
- [ ] Playtest roster comprehension and whether multiple viable strategies exist.

**Exit criterion:** the player makes at least three mechanically meaningful choices,
and waves change in composition and behavior rather than only quantity.

---

## Phase 6 — Presentation, audio, and game feel

**Goal:** actions are readable, responsive, and stylistically coherent.

- [ ] Establish authorship, permission, and release status for every shipped asset.
- [ ] Determine whether `Train 45.mp3` is original, licensed, final, or the banjo
      placeholder mentioned in conversation; replace it if unresolved.
- [ ] Add firing, impact, enemy-death, leak, purchase, upgrade, and UI sounds.
- [ ] Use the existing hit and puff frames for impact, spawn, or death feedback where
      they suit the final art direction.
- [ ] Add restrained recoil, damage feedback, currency-gain feedback, and wave banners.
- [ ] Animate active spider and defense families consistently.
- [ ] Complete the menus, settings, volume controls, and first-run instructions.
- [ ] Test readability at the final browser resolution and common display scales.

**Exit criterion:** playtesters can read hits, kills, leaks, purchases, status effects,
and wave transitions without relying on debug output.

---

## Phase 7 — Progression and replayability

**Goal:** implement only the meta structure selected in Phase 3.

- [ ] Add the chosen level progression, endless scoring, or both.
- [ ] Persist settings and the smallest useful progress record in Web storage.
- [ ] Add board or wave variation that changes decisions, not only presentation.
- [ ] Add onboarding that teaches the final core loop through play.
- [ ] Avoid permanent upgrade systems until the baseline run is balanced and fun.

**Exit criterion:** players have a clear reason to begin another run, and saved state
survives closing and reopening the browser build.

---

## Phase 8 — Release

**Goal:** a stable, legally understood, publicly presentable build.

- [ ] Run fresh-player usability and full-run playtests.
- [ ] Fix critical bugs and complete a data-informed balance pass.
- [ ] Profile late waves at the 15-enemies/second cap; add pooling only if measurement
      shows it is needed.
- [ ] Test supported browsers, resolutions, audio behavior, and save migration.
- [ ] Confirm asset licenses, credits, and collaborator attribution in writing.
- [ ] Prepare the store page, description, screenshots, trailer/GIF, controls, and
      known-issues note.
- [ ] Tag a reproducible release and archive the matching export.

**Exit criterion:** the public build is reproducible, passes its release checklist,
has no unresolved asset-rights questions, and communicates what the game is.

---

## Next five tasks

These are the immediate priorities; later phases should not distract from them.

1. Choose the supported Godot version and verify headless startup.
2. Configure Gunner and slow-defense `TowerData` resources in the active build.
3. Fix the range/movement/bullet unit scale and validate combat end to end.
4. Separate kill and leak events, then add base health.
5. Add visible wave/base state and a restartable loss condition.
