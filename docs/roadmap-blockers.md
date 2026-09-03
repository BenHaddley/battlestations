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
- Supply fixed-direction armed-car redraws or approve continued swivelling art.
- If replacing art, specify frame dimensions, pivots, facing direction, animation
  frames, and whether existing collision silhouettes remain valid.

## Between-wave rail expansion specification

Owner needed: designer. Implementation should begin only after these are answered.

1. What does each rail piece cost, and is rail inventory finite?
2. May players add only, or also remove/replace existing rails?
3. Are junctions/switches in the first version, and how does a train choose a branch?
4. Must every edited route remain a closed loop at every click, or only on confirmation?
5. Can a route serve multiple trains, and what collision/separation rule applies?
6. How is a convoy rebound after editing: nearest point, station, or explicit placement?
7. What happens when a proposed loop is too short for its current consist?
8. Can rail cross spider lanes freely, and are station/spawn rows reserved?
9. Are edits allowed throughout the Station phase or in a separate paused editor?
10. What undo/cancel/refund rules apply?

Once approved, implement route revisions, connection-port tiles, transactional edits,
closed-loop/capacity validation, safe convoy rebinding, UI costs, and dedicated tests as
outlined in `wiki/future-runtime-rails-and-navigation.md`.

## Release operations

Owner needed: repository/release owner.

- Push the intended commit and enable GitHub Pages with GitHub Actions.
- Complete the rights, browser, playtest, and performance gates above.
- Choose a release version, create the signed/annotated tag, run the export from that
  exact tag, checksum it, and archive the matching build.

The tag must not be created from the current mixed, uncommitted worktree or before the
rights gate is resolved.
