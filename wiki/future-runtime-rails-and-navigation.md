# Rails and spider navigation

This page records the implemented rail-editing and spider-navigation model and what
remains open. The behaviour itself is documented in
[Systems and balance](systems-and-balance.md#rail-building-during-stations); this
page explains the architecture and the reasoning behind the proposed rules.

[Source](sources/2026-09-09-rail-building-and-train-collision-notes.md): Gubgub
requested rail building as the next step. During STATIONS, hovering an existing rail
shows plus controls on surrounding rail-free tiles; clicking adds rail for a
provisional **Δ50**. Construction is inaccessible during BATTLE. Rail art must fit the
grid, with buffer/end-cap pieces for dead ends. The notes did not specify adjacency,
inventory, removal/refunds, branches, or train behaviour at unfinished rails.

## Rail graph versus drivable routes

`TrackRenderer` keeps two structures deliberately apart:

- `routes` — closed rings (`PackedVector2Array`) a `TrainConvoy` samples by distance.
  Every consecutive pair is exactly one grid step, wrapping at the end.
- `graph` — the built network: every route cell plus player-built spurs, as
  orthogonal adjacency. It may contain dead ends, junctions and cycles no train uses.

Trains only ever drive routes. A spur is construction until it is joined into a
cycle that a route adopts, or until a locomotive is dropped on a closed cycle of its
own. The revision counter on the renderer marks every change so anything caching
geometry can tell it is stale.

## Why joining is explicit

An early version connected a new tile to every adjacent rail of the same circuit.
That made a spur hugging a loop fuse to it one cell at a time, adopting a zigzag
detour before the player had finished laying it. New tiles therefore connect only
to the tile they were extended from, and a dead end is joined to adjacent rail by a
separate, free click on the join ring. Only dead ends can be joined, so the network
never becomes a lattice, and the player always sees a detour adopted as one event.

## Route adoption rule

When a join closes a cycle, the shortest existing rail path between the two joined
ends is examined:

1. Its intersection with a route must be one contiguous stretch `a..b`.
2. The rest of the cycle (the detour) must be entirely player-built.
3. The detour must have more edges than the stretch it bypasses.

If all three hold, the ring is rewritten with the stretch replaced by the detour in
the ring's driving order; the bypassed stretch remains as a siding. Shortcuts, lobes
touching a route at one cell, and detours through sidings leave routes untouched.
Lifting any tile of an adopted detour reverses this by bridging the authored cells on
either side of the run of built cells, which restores the original stretch.

## Safe rebinding

`TrainConvoy.rebind_route()` adopts a revised ring only when the engine and every
car already sit on geometry both rings share, in the same order and facing, and the
new ring can hold the consist. Otherwise `Main` keeps the request pending and retries
every frame while the train keeps driving its old ring — the old ring is still real
rail, because bypassed stretches are never deleted. Removal of a tile under a
standing train is refused outright rather than deferred.

## Spider obstacle navigation

The Plants-vs.-Zombies-style vertical lanes are kept. Instead of a grid A-star map,
each spider checks its own corridor every physics frame:

- a live train unit within the look-ahead is an obstacle; wrecks and destroyed cars
  are not, and empty rail never is;
- the nearest clear lane within three lanes on either side is chosen, the side away
  from the unit first, and the spider steps into it diagonally;
- with no clear lane and the unit in contact, the spider stops and bites in fixed
  ticks; several spiders stack linearly;
- a target that drives away, is destroyed or wrecked releases the spider the next
  frame, and a sidestep times out after three seconds, so no spider can hold a wave.

This keeps paths readable and deterministic for tests without a navigation grid,
and is what a future Barrier Car (two-tile blocker, workbook health 1250) would use.

## Still open

- Junctions with switching (a train choosing a branch) and shuttle movement on a dead
  end. Both are excluded by the closed-ring model above.
- Collision or separation between two trains sharing rail — a player-built circuit
  can touch an authored ring at its lobe cell.
- Final rail price, whether inventory is finite, and whether authored rail may ever
  be lifted.
- Exact knockback, stun and glue interactions for the workbook's board-effect units.
