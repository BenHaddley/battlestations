# Roadmap unblock checklist

The locally actionable implementation, validation, documentation, and release-media
work has been completed as far as current evidence and settled design allow. These
remaining gates require a human decision, external account/device, contributor
confirmation, or observed playtest. Do not close them from code inspection alone.

## Balance and usability playtests

Owner needed: designer/playtester.

- Play campaign waves 1–10 with wave telemetry enabled.
- Record starting/ending Delta, spending, income, kills, leaks, cars purchased, and
  whether Passenger Coach was strategically necessary.
- Have fresh players identify each car and spider role without explanation.
- Decide whether current spider bounties are acceptable or provide replacement values.
- Record critical issues and rerun after any balance change.

Evidence to save: dated results under `wiki/sources/`, including build commit, tester,
strategy, telemetry output, observations, and approved tuning decisions.

## Real-browser sign-off

Owner needed: tester with two desktop browsers.

- Run `docs/browser-smoke-test.md` in current Chromium and Firefox desktop builds.
- Verify input, 1×/2× speed, pause, Up/Down driving, texture scaling, autoplay after
  interaction, campaign persistence, New Game reset, and save migration.
- Profile a late wave with rendering/audio active and compare frame time with the
  checked-in headless CPU baseline.
- Test 100%, 125%, and 150% display scaling.

Evidence to save: completed browser table, versions/OS, screenshots, console output,
performance trace, and issue links.

## Asset rights and source recovery

Owner needed: project owner and contributors with Discord/backups/account access.

- Search the separate Discord server's `battle stations` channel.
- Search the old PC/backups for later project files and the deleted concept sheet.
- Identify the historical Twitter/X account and preserve relevant posts.
- Obtain creator, license, commercial/Web use, derivative-use, and credit requirements
  for every active asset family listed in `wiki/asset-provenance.md`.
- Determine whether `Train 45.mp3` and every other recording are final and licensed.

Evidence to save: original URLs/files, dates, authors, limitations, license texts, and
written permission under `wiki/sources/` and a future `legal/` directory.

## Art-direction decision

Owner needed: artist/designer.

- Decide whether current spider art is retained or replaced.
- If replacing art, specify frame dimensions, pivots, facing direction, animation
  frames, and whether existing collision silhouettes remain valid.

## Asset workbook decisions and deliveries

Owner needed: designer and artist; source is the
[25-unit workbook register](../wiki/asset-workbook.md).

- Resolve spreadsheet-versus-build costs, Steam carry capacity, and Brake Van's
  attack-power versus attack-speed behavior; Mail cost/weight are currently provisional.
- Define numeric power/cadence, targeting rules, knockback chance, buff stacking,
  train-health/destruction rules, and new board-effect durations and interactions.
- Audit delivered assets and supply missing chassis/top/icon/projectile/effect art,
  with dimensions, pivots, states, authorship, and delivery status.
- Choose the first expansion group and its campaign unlocks after existing-roster
  reconciliation and playtesting.

Evidence to save: dated decisions and an asset inventory linked to the workbook rows.
The spreadsheet contains no completion statuses or numeric replacements for `N/A`.

## Between-wave rail expansion and train damage — confirm the proposed rules

Owner needed: designer. The
[latest notes](../wiki/sources/2026-09-09-rail-building-and-train-collision-notes.md)
settled the gesture, the provisional Δ50 price and the biting/ramming figures; the
rest was implemented as **proposed design** and needs a yes, a no, or replacement
values. Current answers, all documented in
[Systems and balance](../wiki/systems-and-balance.md#rail-building-during-stations):

1. Inventory is unlimited; the price is Δ50 per tile and refunds are full.
2. Players may lift the rail they laid; authored rail cannot be removed.
3. No switching. New tiles attach only to the tile they extend; a dead end is joined
   by a separate free click; a longer player-built detour replaces the stretch it
   bypasses and trains still drive one closed ring.
4. Dead ends are construction: trains never enter them and no locomotive can be
   parked on one until it closes into a circuit.
5. A closed player-built lobe becomes its own circuit; two trains may share the cell
   where it touches an authored ring, with no collision between them.
6. A convoy rebinds only when its whole consist is on shared track, retrying every
   frame; a tile under a train cannot be lifted.
7. A revised ring that cannot hold the consist is refused for that train.
8. Rail may cross every lane; no rows are reserved.
9. Trains keep moving during STATIONS; a route change applies the moment it is safe.
10. Lifting any tile of an adopted detour restores the original stretch.
11. Bites tick every 0.25 s at 25 DPS per spider and stack linearly; ramming deals 20
    per spider per unit on a 2 s cooldown above 60% cruise speed; a wrecked engine is
    recovered by dropping a locomotive on it for Δ325.

Playtest rail building, avoidance, multiple biting spiders, impact recoil and car
destruction before tuning, then record the approved values under `wiki/sources/`.

## Rail and gun artwork deliveries

Owner needed: artist.

- Rail tiles are 750 px squares scaled to 67.5 world units on a 65.5-unit grid, so
  straights overlap slightly to hide seams. If exact-fit pieces are redrawn, keep the
  buffer stop's open end at the bottom of the image and the curve joining down and right.
- The updated Gunner and Chaingunner artwork on the shared Drive has not been added to
  the repository. Deliver each as a separate chassis image and turret image (the turret
  drawn pointing up, the chassis pointing down) so the placed cars keep swivelling; the
  build renders the same pair on every surface, so replacing `Gunner Car Base/Top` and
  `Minigun Base/Top` updates the shop, previews, almanac and placed cars together.

## Release operations

Owner needed: repository/release owner.

- Push the intended commit and enable GitHub Pages with GitHub Actions.
- Complete the rights, browser, playtest, and performance gates above.
- Choose a release version, create the signed/annotated tag, run the export from that
  exact tag, checksum it, and archive the matching build.

The tag must not be created from the current mixed, uncommitted worktree or before the
rights gate is resolved.
