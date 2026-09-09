# Rail building, train collisions, and gun artwork follow-up

Recorded 2026-09-09 from a user-supplied Discord conversation between Gubgub and
TheRealBen, with displayed times 4:59–5:09 PM. The conversation's original date and
timezone were not supplied. Personal conversation and profile text are omitted.
This records design intent and a reported visual bug, not implemented behavior.

## Rail building — next development priority

Gubgub identifies rail building as the next step and part of the STATIONS section.
It is unavailable in BATTLE. During STATIONS, hovering an existing rail tile shows
plus signs on surrounding tiles without rails; clicking a plus builds connected
railway extensions. The precise adjacency rule (including diagonals) was not stated.
Rails cost money: **50 Delta per piece is the provisional starting price**, to be
workshopped later. Rail art may need resizing/redrawing to fit each tile exactly,
and a buffer/end-cap version is needed for dead ends.

Dead-end art is explicitly requested. Train turnaround, stopping, branch selection,
and how a partly built extension connects to the currently closed-loop movement
system were not specified. Do not infer that all purchased track must immediately
form a loop, or that dead ends already work for trains.

## Train–spider interaction

Spiders should try to maneuver around trains, checking for a way to the left or
right. If there is no way around, they bite the blocking train. Gubgub proposes
**about 25 damage per second per spider** to the units and explains that this is
why the spreadsheet gives every unit health.

A spider struck by a train takes **about one bullet's worth of damage**, and the
train recoils a little. Ramming is incidental, not the main offense. This updates
the earlier no-collision-damage direction. Neither the reference bullet/damage
number nor recoil distance/cooldown was specified. The latest message does not
repeat or redefine the earlier three-block detour-search idea.

The conversation refers to giving “rails and spiders collision,” then describes
trains as the objects spiders avoid and bite. Whether empty rails themselves block
spiders needs clarification; do not silently make every rail tile an obstacle.

## Gunner and Chaingunner art mismatch

Gubgub confirms the turret behavior looks fixed, but reports that the placement
ghost uses the correct art while the placed Gunner uses the old version. They say
updated Gunner and Chaingunner artwork was added to Drive a few days earlier.
TheRealBen notes that an asset labelled “new” is now the wrong one.

Audit both units' shop/ghost and placed chassis/turret references against those
supplied artworks, and retire the superseded active references. Keep the restored
swivelling behavior. The conversation does not identify exact replacement filenames.
