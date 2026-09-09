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

## Next priority — STATIONS rail building and train interaction

Source: [Gubgub's rail-building and collision follow-up](wiki/sources/2026-09-09-rail-building-and-train-collision-notes.md),
recorded 2026-09-09. Rail building is now the requested next feature, superseding
its earlier deferred status. Tasks below remain unimplemented unless checked.

### Restore the wave-start skip button

- [x] Fix the reported missing **skip to the start of the wave** button from
      **wave 2 onward**. Show it during the between-wave STATIONS countdown so the
      player can start the next wave immediately; hide or disable it during BATTLE.
      Verify it returns after each completed wave and cannot start a wave twice.
      (`PhaseManager.request_wave_start()`; the button now reads START WAVE n /
      WAVE n UNDERWAY / LEVEL COMPLETE. The cause was the tutorial restoring a stale
      clock pause; lessons now use a separate hold. Regression-tested headless.)

### Stop train controls from moving UI focus

- [x] Fix the reported input conflict where **Up/Down**, while controlling a train,
      also select or highlight UI buttons. Route directional input to the active
      train controls without simultaneously moving interface focus. (HUD controls
      cannot take focus; `Main._input` consumes `ui_up/down/left/right` while the
      board is live.)
- [x] Preserve intentional keyboard navigation in menus and dialogue. Verify train
      control after clicking shop/HUD buttons, closing overlays, and resuming from
      pause, including held keys and switching between trains. (Driving is disabled
      while any card or dialogue is open, so their own focus navigation is untouched;
      covered by the regression suite. A person still needs to try held keys in the
      browser build — see the smoke-test checklist.)

### Build connected rails during STATIONS

- [x] Enable rail building during STATIONS only; disable construction and its plus
      controls during BATTLE.
- [x] Hover an existing rail tile to show clickable plus signs on surrounding empty
      tiles; clicking a plus adds a connected rail tile. Settle adjacency rules.
      (Orthogonal neighbours only; a new tile connects to the hovered tile; dead
      ends are joined to adjacent rail by an explicit free click on a join ring.)
- [x] Charge **Δ50 per rail tile provisionally**, with clear affordability feedback;
      charge only for a valid placement. Workshop the final price after playtesting.
- [x] Explain failed rail placements with a specific reason: insufficient Delta,
      occupied space, or an invalid connection. Preserve the current railway and
      wallet when placement fails.
- [x] Keep purchased rails between waves. Before implementing persistence, define
      what survives saving/loading, restarting, and replaying a level; verify each
      transition preserves or resets the railway according to those rules. (Built
      rail is run-local: it survives every wave and resets whenever the level scene
      reloads — restart, replay, continue, next stop.)
- [x] Define rail-editing cancellation, undo, removal, and refund rules, including
      restrictions for occupied track; implement clear controls and feedback.
      (Right-click lifts a laid tile for a full refund; authored rail, occupied rail,
      and removals that strand track or break a circuit are refused with a reason.)
- [x] Add a rail-building tutorial explaining hover/plus controls, the provisional
      Δ50 cost, and construction availability during STATIONS only.
- [x] Add buffer/end-cap art for dead ends and refresh neighboring connections after
      placement (every cell is drawn from its connection set, including junctions).
- [ ] Redraw rail pieces to fit the board grid exactly if the current 750 px tiles,
      scaled slightly over the 65.5-unit cell to hide seams, are judged unacceptable.
      Artist task; see the roadmap blockers.
- [x] Define how extensions, junctions, and dead ends affect train routes before
      rebinding convoys. Preserve safe movement while an extension is being built;
      the requested dead ends cannot be treated as already-supported closed loops.
      (Trains drive closed rings only; a joined, longer, player-built detour is
      adopted and the convoy rebinds once its whole consist is on shared track; dead
      ends are construction. Proposed design — see the wiki.)
- [x] Verify phase gating, hover/plus placement, invalid/occupied cells, single-charge
      purchases, insufficient funds, connection art, and safe route updates.
      (`_test_rail_building` in the regression suite.)

### Spiders avoid trains, then bite when blocked

- [x] Make moving trains obstacles that spiders try to maneuver around to the left
      or right; when no detour exists, attack the blocking unit instead.
- [x] Use the workbook's unit health values and start biting at **about 25 damage
      per second per spider**. Define tick timing and how simultaneous attackers stack.
      (0.25 s ticks of 6.25; attackers stack linearly.)
- [x] Add incidental train-impact damage of **about one bullet's worth** to a spider,
      plus a small recoil on the train. Define the reference bullet, recoil amount,
      and contact cooldown so ramming cannot replace the intended weapons. (One
      Gunner bullet = 20; 2 s per spider per unit; only above 60% cruise; the train
      drops to 35% speed and jolts back 8 units.)
- [x] Handle destroyed cars/engines, convoy gaps, lost buffs/carry capacity, and
      navigation updates without corrupting the train or wave state.
- [x] Decide engine-destruction behavior before implementing train damage: what
      happens to surviving attached cars, whether a stranded train can be recovered,
      and how recovery works if supported. (A wreck: cars keep firing where they
      stand, nothing couples, spiders walk past; dropping a Δ325 locomotive on the
      wreck recovers the train at full engine health. Proposed design.)
- [x] Add readable unit-health feedback: show damaged cars, identify the unit being
      bitten, and clearly communicate car or engine destruction.
- [x] Resolve whether empty rail tiles block spiders, the left/right search distance
      (including the earlier three-block idea), and no-detour behavior near board edges.
      (Empty rail never blocks; three lanes each side; lanes beyond the board edge are
      simply unavailable, so an edge spider bites sooner.)
- [ ] Playtest avoidance, multiple biting spiders, impact/recoil, and car destruction.
      This revises the older specification that ordinary trains deal no impact damage.
- [x] Recover spiders from stale paths or invalid attack targets after trains move,
      rails change, or cars are destroyed. Recalculate movement or enter the valid
      blocked/bite state so a frozen spider cannot prevent the wave from finishing.

### Show attack range and the controlled train

- [x] Show a car's actual attack range while placing or selecting it, including
      Mail Carrier's 5×5 range. Keep previews consistent with targeting and upgrades,
      and avoid showing an attack radius for non-attacking cars. (Guns now acquire
      at the documented radius rather than through the scaled physics area, so the
      preview is the real range; the upgrade card reports range in board tiles.)
- [x] Clearly mark the train currently being controlled and show its current total
      weight and carry capacity. Refresh the feedback when switching trains,
      coupling/removing cars, or losing a unit or capacity bonus.

### Verify campaign transitions and the complete run

- [x] Verify final-wave completion, character dialogue, rewards, victory, and the
      next station occur in the intended order without overlapping screens,
      duplicate rewards, or starting the next encounter before dialogue finishes.
      (Fixed: dismissing dialogue after the final wave could restart the station
      clock under the level-complete card; the spawner now refuses waves after the
      level finishes. Regression-tested headless; the in-person run below remains.)
- [ ] Run a full campaign playtest covering every car unlock, Duck and Daisy lesson,
      wave-skip button from wave 2 onward, and save/continue transition together.
      Include rail edits and train damage as those systems become available; record
      the build, observations, and failures, then recheck fixes.

### Duck and Daisy guide the player throughout the campaign

- [x] Map every player-facing feature and car to a level introduction. Duck and
      Daisy should teach progressively as levels unlock content, building on earlier
      lessons rather than stopping after the opening tutorial.
- [x] Cover train placement/coupling, driving and selection, capacity and Tender
      positioning, Delta income, upgrades/selling, wave-start skipping, and STATIONS
      rail building. Introduce avoidance, biting, unit health, destruction, and
      recovery alongside those systems when implemented.
- [x] Give every unlocked car its own explanation and guided use: role, cost,
      weight, range/targeting where applicable, special behavior, and a practical
      reason to choose it. Include Mail Carrier and extend coverage to future cars.
- [x] Pair dialogue with a highlighted control or unit and a small actionable task;
      advance when the player performs the action. Keep lessons possible with the
      player's available money, train capacity, and current board state.
- [x] Schedule lessons during safe moments, preferably STATIONS, and coordinate
      them with wave timing so combat cannot interrupt an unfinished instruction.
- [x] Track completed lessons per profile; support skipping and replaying guidance,
      and ensure continuing a save still introduces newly unlocked features/cars.
      Reset the appropriate lesson progress for a new campaign.
- [x] Make sure switching to a different profile restarts the tutorial on that
      profile (a profile with no completed lessons of its own should see the
      opening tutorial again, not inherit progress from the previously active
      profile).
- [ ] Verify the full campaign's teaching sequence with a fresh player, including
      levels that unlock multiple cars, save/continue, skipped lessons, and replays.
      Every available feature and car should have an introduction at a useful moment.

### Correct Gunner and Chaingunner artwork

- [ ] Import the updated Gunner/Chaingunner art from the shared Drive as separate
      chassis and turret images and audit it against the placed cars. The repository
      only holds the older chassis/turret pairs and the static directional sheets.
- [x] Replace superseded active references and verify both placed cars match their
      previews while still swivelling. (Every surface — shop row, drag preview,
      placement ghost, almanac card, upgrade card — now renders the placed car's own
      chassis/turret pair via `CarArt`; the static sheets remain only for the debug
      directional toggle.)

---

## Asset workbook — roster and production backlog

Source: [Assets to make.xlsx](wiki/sources/Assets%20to%20make.xlsx),
`Sheet1!A1:L26`; [complete 25-unit register](wiki/asset-workbook.md), documented
2026-09-09. These are documented concepts, not 25 delivered assets or an approved
release order. The following work groups are a proposed implementation sequence.

### Reconcile the existing roster first

- [x] Transcribe all 25 units, all stat columns, and their roles; retain `N/A`,
      qualitative power/speed, and targeting priorities without inventing values.
- [x] Record differences from the build and older infowiki cards in the wiki.
- [x] Restore the original swivelling Gunner/Chaingunner behavior following playtest
      feedback; retain the directional experiment only as a debug comparison.
- [x] Add Mail Carrier with supplied chassis/turret/envelope artwork, 5×5 range,
      and independent random targeting for every projectile.
- [x] Add a Mail Carrier unlock explanation and almanac entry covering its rapid
      fire, 5×5 range, and independent random target selection for each envelope.
      (Duck and Daisy car lesson, the level-complete card now names every car a stop
      unlocks, and the almanac card uses the placed car's own artwork.)
- [ ] Reconcile Steam Engine cost 250/carry 1200, Tender cost 75, Delta Coach cost
      100, Mail Car cost 125/weight 125, and Brake Van cost 175 against current values.
      Tender weight and capacity bonus are `N/A`, not replacements for existing values.
- [ ] Resolve Brake Van's specified 1.25× attack-power buff versus the current
      1.2× attack-speed buff, including stacking, train-cap, and braking behavior.
- [ ] Translate Weak/Average/Great/Insta-Kill power and Fast/Average/Slow/Very Slow/
      Recharge speed labels into approved numeric stats. Define Coal Cannon's
      knockback chance and exact Close/Strong/All/Webs targeting rules.
- [ ] Specify health/damage/destruction for engines and cars using the workbook's
      health column, including consist reconnection, lost capacity, and buff removal.
- [ ] Playtest reconciled existing cars before expanding the roster.

### Audit and produce assets

- [ ] Audit all 25 entries against available files, including the shared Drive;
      record delivered/missing chassis, tops, icons, projectiles, effects, and animations.
- [ ] Assign owners and delivery status; agree dimensions, pivots, facing, scale,
      required states, and authorship/permissions. The workbook supplies none of these.
- [ ] Define the double-size Barrier Car footprint and train spacing/placement art.
- [ ] Supply action visuals for the new roles: tongue/chewing, rail spike, returning
      slate, crossfire, thump/stun, glue tiles, web clearing, drilling, and interception.

### Implement approved additions in dependency groups

- [ ] Add Diesel Engine's higher-capacity/slower movement variant and Turbine Coach's
      rapid-motion Delta income after defining movement thresholds and income rates.
- [ ] Add Greenhouse (eat/chew), Steel Driver (strong-target spike), Slate Return
      (boomerang path damage), Clique Car (same-train scaling), and Crossfire Car
      (four-way fire), with targeting and damage rules tested per mechanic.
- [ ] Add Barrier Car (two-tile blocker), Thumper (area stun), Scapegoat (station
      damage interception), and Glue Tanker (slowing tiles) after train health and
      board navigation/effect rules are specified.
- [ ] Add Velocity Van (speed boost, 10% damage reduction), Mini Van (1.75× attack
      power with at most three cars), and Throttle Rocket (whole-train speed boost).
      Define magnitude, stacking/caps, and whether engine/Tender count toward limits.
- [ ] Add Web Whacker (web-cluster removal) and Jackhammer (rapid close damage,
      extra damage to rocks) alongside persistent webs and destructible obstacles.
- [ ] Add approved cars to the shop, discovery/almanac, campaign unlocks, and sandbox;
      validate costs, capacity, placement, effects, and readable counterplay.

**Exit criterion:** every accepted unit has an approved specification and tracked
assets; implementation status is explicit, and new mechanics pass focused gameplay
checks and playtests. Unspecified mechanics remain in the
[decision register](wiki/open-questions.md#asset-workbook-reconciliation).

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

### Historical experiment: directional-car prototype

- [x] Import and connect the four updated car artworks without deleting or replacing
      the current production assets.
- [x] Add an experimental facing selector for the two attacking cars: while dragging
      with the left mouse button, right-click flips the placement preview and chosen
      firing direction between left and right.
- [x] Make facing obvious in both the preview and the placed car, and prevent a
      right-click flip from cancelling or prematurely placing the drag.
- [x] Keep the existing swivelling implementation available behind a toggle, separate
      scene, or versioned resource so the two aiming models can be compared safely.
- [x] Record playtest outcome: direction locking was withdrawn; original swivelling
      behavior is restored in normal gameplay. The debug toggle remains available.

### Next: build the full main menu

- [x] Implement the supplied main-menu graphic as a responsive navigation screen,
      preserving its illustrated layout and adding keyboard-focus states alongside
      pointer hit areas. (`TitleScreen.tscn`: illustrated hit areas, Start focused on
      entry, Enter/Space and Escape handling, focusable buttons throughout.)
- [x] **Start Game:** begin the normal story campaign, including pre-round dialogue.
      (Start continues the active profile's save or opens Daisy's new-game choice;
      every stop opens with its Duck and Daisy introduction.)
- [x] **Level Select:** list unlocked levels for replay and for retrying missed level
      challenges; locked levels must be visually distinct.
- [x] **Challenges:** the coming-soon state was superseded — six challenge job cards
      (Last Train Standing, Heavy Haul, No Brakes, Sturdy Situation, Budget Railway,
      Spider Assault) are designed, launchable and regression-tested.
- [x] **Achievements:** show persisted medal tasks and their locked/unlocked state.
- [x] **Almanac:** open the persisted discovery/reference collection from the main menu.
- [x] **Settings (gear):** expose music/SFX volume and default battle speed preferences.
      preferences.
- [x] **Profiles:** support three save profiles and make the active profile obvious;
      profile switching must isolate campaign progress and settings as specified.
- [x] **Quit (X):** quit native builds safely. For Web builds, explain that the tab
      can be closed or return to a harmless title state instead of calling an
      unsupported quit operation. (`TitleScreen._quit_game()`.)

### Later audio-readability pass

- [ ] When placeholder sounds are supplied, add distinct cues for the Coal Cannon
      power shot, Jumping Spider hop, Wolf Spider half-health mode, car placement,
      and other small but important board events.
- [x] Normalize simultaneous sound playback so bursts and crowded waves remain clear
      and do not clip or become unexpectedly loud. (At most four voices per sound
      with each extra copy ducked 3 dB, and a limiter on the SFX bus.)

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
      deploy). Live at <https://benhaddley.github.io/battlestations/> (Pages source:
      GitHub Actions); the artist grid sheet is served beneath `/test`.
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
- [x] Implement the now-prioritized STATIONS rail-expansion system: hover-to-reveal
      plus controls, provisional Δ50 tiles, buffer art, route validation, and safe
      convoy rebinding. See the next-priority section above.
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

These priorities follow Gubgub's latest written direction; the workbook expansion
backlog and existing release gates remain tracked above. The 2026-09-09 systems are
built and regression-tested; what remains needs a person, an asset, or a decision.

1. Playtest rail building, avoidance, biting, ramming recoil and car destruction in
   the browser build; record observations and approve or replace the provisional
   Δ50, 25 DPS, 20-damage and recoil values.
2. Confirm or amend the proposed rail rules (explicit joins, detour adoption, full
   refunds, run-local persistence, no junction switching) and the wreck/recover rule.
3. Import the updated Gunner/Chaingunner Drive artwork as chassis/turret pairs.
4. Run the fresh-player campaign pass covering every car lesson, save/continue,
   skipped and replayed lessons, and profile switching.
5. Decide the workbook cost/carry/buff differences and spider bounty targets, then
   start the first expansion group (Barrier Car plugs into the obstacle rules).
