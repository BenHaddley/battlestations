# Future runtime rails and spider navigation

This page records architectural preparation only. Runtime rail editing and
obstacle-aware spider pathfinding are not part of the current build.

Gubgub has since confirmed the high-level design intent: players should be able to
add rails and expand the railway **between waves**, but the feature is explicitly
deferred until later. Costs, inventory, removal rules, and whether existing rails may
be edited are not yet specified.

## Runtime rail editing

The current `TrackRenderer` already owns route generation, validation and visual
drawing, while each `TrainConvoy` receives a closed `PackedVector2Array`. That is
the correct separation to preserve. A future editor should change the route data,
ask the renderer to validate it, then rebind affected convoys at a safe station
phase boundary.

Before allowing edits during play, add:

- a route revision number so trains never sample stale geometry,
- explicit straight, corner and junction pieces with matching connection ports,
- validation for closed loops, minimum bend clearance and station connectivity,
- a safe convoy rebind rule that preserves train order and rejects a route whose
  circumference cannot hold the consist,
- build costs and editing permissions controlled by the STATION phase.

The convoy now uses distance along a closed route rather than movement history.
That makes future rebinding tractable and prevents reverse movement from driving
the engine into its own tail.

## Spider obstacle navigation

Spiders currently move down deterministic vertical lanes. Train cars remain
targets/defenders, not navigation obstacles, and this task deliberately does not
rewrite that movement.

For a future obstacle system, use a grid A-star map aligned to the illustrated
board cells. It is a better fit than free-form navigation for the 9 by 12 board,
keeps paths readable to players, and permits deterministic tests. Each car or
future placed obstacle can reserve cells and request path recalculation. Required
rules include:

- never accept a placement that removes every route to the station,
- reserve the spider spawn and station rows,
- replan only when obstacle revisions change, not every frame,
- distinguish passable rail art from a genuinely blocking unit,
- let a spider evade an ordinary oncoming train by moving one tile backward or
  sideways instead of taking collision damage,
- support the documented Barrier Car: a heavy two-tile wall that a spider bites when
  no route around the blocking train exists within three blocks,
- define precisely how the “within three blocks” search is measured and how multiple
  equally short detours are selected,
- give cars damage/health handling so sustained bites can destroy one car without
  corrupting convoy state.

Those rules should be proven in a separate navigation test scene before replacing
the current lane movement.
