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

Remaining human, external-access, licensing, and unresolved-design gates are tracked
in the [roadmap unblock checklist](docs/roadmap-blockers.md).

---

## Current sprint — menu and 2026-09-03 playtest follow-up

This sprint translates Gubgub's latest menu description, demo notes, and four-car art
update into testable work. Preserve the current swivelling-car build as the stable
baseline; fixed-direction weapons are an experiment until playtesting confirms that
they improve the game.

### Today: stabilize the demo

- [x] Fix the Chaingunner so its seven-round burst fires sequentially, with one shot
      and one appropriately mixed sound per interval, rather than seven simultaneous
      bullets and stacked audio. Verify that one burst no longer behaves like a
      one-hit attack.
- [x] Make the Jumping Spider stationary between jumps. Movement and displacement
      should occur only during its hop state.
- [x] Restore the Coal Cannon's intended knockback and verify that a direct hit moves
      a spider backward along its route without breaking path or wave accounting.
- [x] Increase gameplay-font outline thickness and check legibility against light,
      dark, and visually busy parts of the board.
- [x] Replace edge-positioned placement errors with a centered, thin, low-opacity
      banner near the top of the play area. It should remain readable without hiding
      the board, then disappear automatically after a few seconds.
- [x] Add a documented sandbox/debug scene for directly spawning cars and spiders,
      changing relevant state, and resetting the encounter without playing through
      campaign levels. Link its controls from the developer documentation.

### Today: directional-car prototype

- [x] Import and connect the four updated car artworks without deleting or replacing
      the current production assets.
- [x] Add an experimental facing selector for the two attacking cars: while dragging
      with the left mouse button, right-click flips the placement preview and chosen
      firing direction between left and right.
- [x] Make facing obvious in both the preview and the placed car, and prevent a
      right-click flip from cancelling or prematurely placing the drag.
- [x] Keep the existing swivelling implementation available behind a toggle, separate
      scene, or versioned resource so the two aiming models can be compared safely.
- [ ] Playtest fixed-direction targeting with current spider and engine speeds before
      changing either. Record whether positioning is interesting, whether targets
      spend enough time in the firing arc, and whether manual train movement is
      necessary. Treat tile-step engine movement and arrow-key driving as later
      design options, not part of this first experiment.

### Next: build the full main menu

- [ ] Implement the supplied main-menu graphic as a responsive navigation screen,
      preserving its illustrated layout and adding keyboard-focus states alongside
      pointer hit areas.
- [ ] **Start Game:** begin the normal story campaign, including pre-round dialogue.
- [x] **Level Select:** list unlocked levels for replay and for retrying missed level
      challenges; locked levels must be visually distinct.
- [ ] **Challenges:** show a clear coming-soon state until special handicap/mechanic
      levels are designed.
- [x] **Achievements:** show persisted medal tasks and their locked/unlocked state.
- [x] **Almanac:** open the persisted discovery/reference collection from the main menu.
- [x] **Settings (gear):** expose music/SFX volume and default battle speed preferences.
      preferences.
- [x] **Profiles:** support three save profiles and make the active profile obvious;
      profile switching must isolate campaign progress and settings as specified.
- [ ] **Quit (X):** quit native builds safely. For Web builds, explain that the tab
      can be closed or return to a harmless title state instead of calling an
      unsupported quit operation.

### Later audio-readability pass

- [ ] When placeholder sounds are supplied, add distinct cues for the Coal Cannon
      power shot, Jumping Spider hop, Wolf Spider half-health mode, car placement,
      and other small but important board events.
- [ ] Normalize simultaneous sound playback so bursts and crowded waves remain clear
      and do not clip or become unexpectedly loud.

**Sprint exit criterion:** the reported Chaingunner, Jumping Spider, Coal Cannon,
font, and placement-message issues are fixed and regression-tested; the sandbox has
documented controls; fixed-direction cars can be compared with the preserved swivel
version; and every main-menu control either reaches its intended screen or presents
an intentional coming-soon state.

---

## Phase 0 — Recovery and migration ✅ complete

- [x] Snapshot the Unity source under `legacy_unity/`.
- [x] Port the eleven gameplay scripts to GDScript.
- [x] Rebuild the main gameplay scenes in Godot 4.
- [x] Migrate usable art and audio into `assets/`.
- [x] Consolidate implementation, history, content, and open questions into the
      [wiki](wiki/README.md).

The recovered scaffold has since grown into a playable campaign and challenge build.
The remaining phases track refinement, validation, deferred systems, and release work.

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
- [x] Spawn distinct engine liveries and replace fixed build pads with convoy
      drag/drop; attached combat cars use collision-safe route-distance spacing.
- [x] Complete the first cohesion pass: stronger rails and curves, lane/danger guides,
      larger linked cars, smoke, animated enemies, combat feedback, and a train-aware HUD.
- [x] Converge on the recovered illustrated control-desk reference: wooden full-height
      cabinets, illustrated inventory grid, transport/tutorial controls, challenges,
      bottom station-health bar, and narrow embedded modular rails.

### Verification

- [x] Complete lightweight automated coverage for wallet operations, wave formulas,
      catalog validity, invalid shop selections, train placement, and upgrade cost,
      application, and persistence.
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

- [x] Replace one-shot leaks with a persistent station-attack state; only kills
      clear the enemy from wave accounting and award currency.
- [x] Add tunable station health and periodic damage from surviving attackers.
- [x] Define and implement a loss condition at zero base health.
- [x] Use a seven-stop finite campaign followed by an endless Open Rails mode.
- [x] Add game-over/victory UI with restart and return-to-menu actions.
- [x] Prevent building, shooting, and spawning after the run ends by pausing the tree.

### Player feedback

- [x] Replace the current game-over screen with the supplied `GAME_OVER_TEXT` artwork:
      slightly darken the gameplay screen, then fade the artwork in. Preserve the
      existing restart and return-to-menu actions in the new presentation. Source:
      [Discord attachment](https://media.discordapp.net/attachments/947661024075595838/1542709884045369414/GAME_OVER_TEXT.png?ex=6a9583ca&is=6a94324a&hm=8bcbd04381492aa1749bf28d9d12e365b4f48f304241f83f3c5e281f826d4ab2&=&format=webp&quality=lossless&width=1024&height=1024),
      described as: “the screen would just darken a little and this would fade in
      or somethin.”
- [x] Finalize the compact engine controls from the 2026-08-28 playtest: keep combat
      at the bottom of the board visible, use Up/Down for forward/reverse speed, make
      manual input primarily boost the default cruise speed, and allow a very slow
      crawl rather than a complete stop. Playtest the final minimum and maximum speeds
      so stopping in one ideal position is not the dominant strategy.
- [x] Show base health, wave number, remaining enemies, and next-wave countdown.
- [x] Build and wire the car upgrade panel with level, stats, next price,
      affordability, purchase, and sell actions.
- [x] Wire pause and speed controls using the existing UI art; define supported
      speeds and ensure timers behave consistently.
- [x] Add an explicit animated wave-start cue.

### First balance baseline

- [x] Fix or intentionally confirm bullet travel speed, enemy speed, range, bounty,
      tower prices, and upgrade values after the unit-scale correction.
- [ ] Reduce spider Delta bounties until large waves no longer make car prices
      inconsequential, while keeping Passenger Coach income strategically important.
- [ ] Play waves 1–10 and record results before retuning the inherited formulas.
- [x] Document the first intentional balance baseline in the wiki.

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
- [x] Implement the agreed multi-engine model: grant one engine at level start, let
      the player buy and place additional engines on rails, and provide clear controls
      for selecting and managing each train independently.
- [x] Use multiple authored campaign boards followed by an endless mode.
- [x] Treat the 25 engine paint jobs as cosmetic variants.
- [x] Define intended roles for the initial defense and spider roster. Mark any new
      interpretation as new design rather than recovered canon.
- [x] Write a one-page design brief covering player objective, placement/movement,
      roster roles, progression, victory, and defeat.
- [x] Update [Game overview](wiki/game-overview.md) and close the relevant entries in
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

- [x] Convert the supplied title-screen mock-up into the functional entry scene,
      with responsive illustrated hit areas and Start/Enter/Space navigation into battle.

**Goal:** every later milestone is playable at a shareable URL.

- [x] Install the Web export templates matching the chosen Godot version (4.7.2,
      `~/.local/share/godot/export_templates/4.7.2.stable/`).
- [x] Add and commit an HTML5 export preset (`export_presets.cfg`, single-threaded
      variant so no cross-origin-isolation headers are required to serve it).
- [ ] Test input, texture import, viewport scaling, save storage, and audio autoplay
      in at least two desktop browsers. Verified so far only in headless Chromium
      (via Playwright) — real desktop-browser passes (esp. audio autoplay, which
      Chromium/Firefox gate differently) are still outstanding.
- [ ] Confirm the implemented pause, 1×/2× speed, and Up/Down train controls in two
      real desktop-browser Web runs.
- [x] Create a repeatable export command:
      `godot --headless --path . --export-release "Web" export/web/index.html`.
- [x] Host target decided: **GitHub Pages**, not itch.io. A build-and-deploy workflow
      is checked in at `.github/workflows/deploy-pages.yml` (push to `main` → export →
      deploy). Not yet live — needs this repo pushed to GitHub with Pages enabled
      (Settings → Pages → Source: GitHub Actions) before the workflow can run.
- [x] Add a short [browser smoke-test checklist](docs/browser-smoke-test.md) to the repository.

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

- [x] Ship the seven infowiki-backed launch cars: Gunner, Coal Cannon, Minigun,
      Ballast Blaster, Brake Van, Passenger Coach, and Tender.
- [x] Write a compact specification for each: role, cost, range, cadence, effect,
      upgrade identity, strengths, and counterplay.
- [x] Implement each as data plus a scene, sharing behavior where appropriate.
- [x] Include at least three genuinely distinct functions, such as direct damage,
      area damage, control, piercing, economy, or support.
- [x] Add clear shop icons, stat summaries, placement previews, and affordability
      states.

### Enemies

- [x] Use Generic, Baby, Charger, Rally, Roller, Sturdy, Wolf,
      Jump, and Egg.
- [x] Give each selected enemy an explicit gameplay role, stats, bounty, and visual
      feedback.
- [x] Replace uniform random spawning with documented campaign-level unlock and
      weighted-composition rules.
- [x] Introduce specialist behavior progressively after baseline combat is taught,
      with readable tells and documented counterplay for every active archetype.
- [ ] Decide whether to retain or replace the current spider art before a large
      animation-polish pass.

### Balance and testing

- [x] Move shared wave, economy, and train tuning into `resources/game_balance.tres`;
      keep mechanic-specific car values in `TowerData`/scenes and spider values in
      the explicit roster catalog.
- [x] Add a debug wave selector and telemetry for spending, income, kills, net Delta,
      and wave reached.
- [ ] Playtest roster comprehension and whether multiple viable strategies exist.
- [ ] Confirm that Passenger Coaches remain a meaningful economy choice after spider
      bounty tuning rather than becoming optional once waves grow.

**Exit criterion:** the player makes at least three mechanically meaningful choices,
and waves change in composition and behavior rather than only quantity.

---

## Phase 6 — Presentation, audio, and game feel

**Goal:** actions are readable, responsive, and stylistically coherent.

- [ ] Establish authorship, permission, and release status for every shipped asset.
- [ ] Determine whether `Train 45.mp3` is original, licensed, final, or the banjo
      placeholder mentioned in conversation; replace it if unresolved.
- [x] Add firing, impact, enemy-death, station-hit/leak, purchase, upgrade, and UI sounds.
- [x] Use the existing hit and puff frames for impact, spawn, or death feedback where
      they suit the final art direction.
- [x] Preserve the spider death effects' impact and “pop,” which was specifically
      praised in the 2026-08-28 playtest, through later animation and art revisions.
- [x] Add restrained recoil, damage feedback, currency-gain feedback, and wave banners.
- [x] Animate active families consistently: spiders alternate their supplied walk
      frames and animate special states, while combat cars track targets, recoil,
      flash, trace shots, and emit family-specific projectiles/effects.
- [x] Complete the pause/restart/title menus, persistent volume/mute settings,
      fullscreen control, and event-driven first-run instructions.
- [ ] Test readability at the final browser resolution and common display scales.

**Exit criterion:** playtesters can read hits, kills, leaks, purchases, status effects,
and wave transitions without relying on debug output.

---

## Phase 7 — Progression and replayability

**Goal:** implement only the meta structure selected in Phase 3.

- [x] Add a seven-stop campaign followed by endless Open Rails play.
- [x] Persist campaign progress in Web storage.
- [x] Add deterministic campaign board layouts and challenge variations.
- [ ] Design and implement the explicitly deferred between-wave rail-expansion system,
      including costs, placement/removal rules, route validation, and rebinding trains
      safely when the railway changes.
- [x] Add event-driven onboarding that teaches coupling a Gunner, starting a wave,
      automatic firing, Delta payouts, train weight, and each newly unlocked car.
- [x] Keep upgrades run-local; campaign persistence records progress only and adds no
      permanent stat-upgrade system before baseline balance is established.

**Exit criterion:** players have a clear reason to begin another run, and saved state
survives closing and reopening the browser build.

---

## Phase 8 — Release

**Goal:** a stable, legally understood, publicly presentable build.

- [ ] Run fresh-player usability and full-run playtests.
- [ ] Fix critical bugs and complete a data-informed balance pass.
- [ ] Complete late-wave profiling at the 15-enemies/second cap. The repeatable
      headless CPU probe passes at 225 active spiders (0.265 ms/frame on 2026-08-31),
      so pooling is not justified by movement CPU cost; Web rendering/audio profiling
      remains before release.
- [ ] Test supported browsers, resolutions, audio behavior, and save migration.
- [ ] Confirm asset licenses, credits, and collaborator attribution in writing.
- [x] Prepare the release kit in `docs/release-kit.md`: store copy, controls,
      known issues, seven rendered screenshots, a gameplay GIF, and a silent
      14-second trailer preview are checked in. Public use remains rights-gated.
- [ ] Tag a reproducible release and archive the matching export.

**Exit criterion:** the public build is reproducible, passes its release checklist,
has no unresolved asset-rights questions, and communicates what the game is.

---

## Next five tasks

These are the immediate implementation priorities from the current sprint; complete
the remaining sprint items after them.

1. Fix and regression-test Chaingunner burst sequencing and audio.
2. Fix Jumping Spider idle movement and Coal Cannon knockback.
3. Improve font outlines and replace placement errors with the timed top banner.
4. Add and document the direct unit-testing sandbox/debug scene.
5. Prototype reversible left/right facing for the two updated attacking cars while
   preserving the current swivelling version.
