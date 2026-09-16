# September 16 — roster reconciliation and roadmap verification

Implemented in response to the request to build out navigation/combat checks,
campaign guidance verification, and the existing roster's balance baseline.

## Source precedence and decisions

The September 10 playtest revision controls movement and combat behavior. The
surviving asset workbook supplies explicit prices, weights, capacity and health.
Where the workbook is silent, existing behavior remains. These choices are an
implemented baseline for evaluation, not a claim of designer or playtester approval.
No additional cars have been added.

| Existing unit | Price (Delta) | Weight | Carry / support |
|---|---:|---:|---|
| Steam Engine | 250 | — | 1200 carry; recovery also costs 250 |
| Gunner | 150 | 150 | unchanged |
| Chaingunner | 225 | 200 | seven-round burst unchanged |
| Ballast Blaster | 200 | 175 | unchanged attack |
| Passenger / Delta Coach | 100 | 125 | 32 Delta every 8 seconds |
| Coal Cannon | 300 | 225 | unchanged base direct/splash damage |
| Brake Van | 175 | 0 | 1.25× damage; train cap; existing 15% braking-time reduction |
| Tender | 75 | 50 | +500 carry only directly behind engine |
| Mail Carrier | 125 | 125 | 2.625 envelopes/second; 4 base damage |

Tender weight and capacity bonus are not specified in the workbook; 50 and +500
remain intentional existing values. Brake Van does not stack because it prevents
further attachments. Its multiplier applies to Gunner, Chaingunner, Mail Carrier,
Ballast area damage, and Coal Cannon direct/splash damage. Integer damage rounds to
the nearest whole point. Removing/selling/destroying the van removes only its own
modifier; a car's separate damage modifier is preserved. Firing cadence is unchanged.

## Bounty baseline

Campaign progress now increases enemy durability without automatically adding
8 Delta per stop to each spider's reward. Early generic rewards decrease from 18
to 12. Other standalone archetype rewards remain their catalog base values.

| Enemy | Reward (Delta) |
|---|---:|
| Generic | 12 |
| Standalone Baby | 8 |
| Charger | 18 |
| Rally | 22 |
| Roller | 25 |
| Sturdy | 32 |
| Wolf | 36 |
| Jump | 38 |
| Egg shell | 0 |
| Baby hatched from an egg | 2 |

A Roller plus its egg and four offspring yields 33 total, rather than the old
390 at the seventh stop. Budget Railway's 0.45 multiplier applies to each kill,
rounded per kill: 11 for the Roller plus four 1-Delta babies = 15. Player-deployed
Spider Assault enemies and their offspring pay zero. Destroying an egg twice cannot
release additional babies or duplicate its reward. The four babies remain counted
as living enemies until killed.

Passenger Coach still earns 4 Delta/second and repays its 100 purchase price in
25 earning seconds while coupled and visible. Wave bonuses remain 35 + 12 × wave.
This arithmetic explains the baseline; it does not prove the Coach is strategically
necessary or that late waves are balanced.

## Fixes and automated evidence

Command: `godot --headless --path . tests/GameplayRegression.tscn`.
Test profiles use isolated temporary directories, never a real career.

- Junctions prefer a fresh built branch, then less-used exits, with straight travel
  winning an equal-use tie on unbuilt track. An occupied train can enter and back
  out of a newly built dead-end spur without leaving the rails or self-blocking.
- Buffer stops hold position for 0.65 seconds before accelerating in reverse;
  both ends and the complete consist are checked.
- Jump Spiders remain still during windup, jump 131 units (two tiles) in approximately
  0.75 seconds at 30/60/120 FPS, rest after landing, and clamp a short final hop to
  the destination. Existing coverage verifies jumping over trains without biting.
  The 3.55-second cadence is measured between hop starts.
- Mail Carrier previously discarded fractional firing time every frame. It now
  preserves the remainder, emits 157 shots over 60 seconds at 30/60/144 FPS, and
  discards idle time when no recipient is available. Existing tests verify random
  recipients, range, retargeting and actual envelope damage.
- Tests fire all five weapon types under the Brake Van buff, check direct and splash
  damage, preserve cadence, and verify bonus removal and Tender capacity removal.
- The full campaign flow traverses seven actual scenes and all 35 scheduled waves,
  persists and reloads every stop, checks introductions for all eight cars, skips
  lessons and confirms their persistence, checks double-start protection and final
  payout/clock state, then uses the real completion signal to reload the next stop.
  The finale enters Open Rails. Profile switching preserves separate campaign saves;
  guidance replays on a changed profile, same-profile selection preserves skips,
  and New Game resets the lessons. Earlier regression coverage completes the opening
  Gunner placement objective and explicitly replays the unlocked-car lessons.
- Later queued introductions now recheck affordability and train capacity. If an
  earlier purchase consumed the budget or capped the train, the lesson becomes
  advice with a Continue action instead of an impossible required purchase.

The campaign run uses scripted kills, not an AI strategy or a fresh human player.
It verifies state transitions and persistence, not comprehension, difficulty,
real-time survival, or browser storage behavior. The gameplay regression suite
passes, including all the checks above.

## Web export check

The updated Web release exported successfully. `tests/web_smoke.sh export/web 60`
passed in headless Chromium: Boiler Room loaded with two routes, one train, one car
and 40 rail cells, with no script errors. This is a boot smoke test; its virtual
clock did not run gameplay long enough to report train motion. Audio awaits the
normal browser user gesture. It does not verify the full campaign in a browser.

## Remaining human playtest

Use a fresh profile in a real browser and record the build, browser/OS, strategy,
wave telemetry and failures under `wiki/sources/`.

1. Build and revisit multiple branches. Check whether the chosen exit is understandable
   and the buffer pause/reversal feels responsive with short and long trains.
2. Play Jump and Roller encounters. Observe jump readability, baby threat and income;
   compare Mail Carrier against other affordable cars rather than only its raw cadence.
3. Play all seven stops without coaching. Confirm each car introduction arrives at a
   useful time, then exercise save/continue, lesson skip/replay and profile changes.
4. Record waves 1–10 with and without Passenger Coaches, including spending, income,
   station damage and survival. Decide bounty adjustments from those results.
5. Complete the two-browser checklist in `docs/browser-smoke-test.md` before release.

Keep these human gates open in the roadmap. Numeric definitions for future cars,
Coal Cannon knockback probability and other unspecified workbook behavior remain
separate decisions before expanding the roster.
