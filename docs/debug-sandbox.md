# Debug unit lab

Launch the sandbox directly from the project directory:

```sh
godot --path . scenes/DebugSandbox.tscn
```

Move the mouse to the desired position, then use:

- `1`–`8`: spawn any shop car, in shop order
- `Q W E R T Y U I O`: spawn each spider archetype
- `F`: flip the most recently spawned directional gun car
- `V`: toggle that gun car between the new static-facing prototype and the preserved swivel version
- `C`: clear spawned units
- `Escape`: return to the main menu

This lab ignores prices, campaign unlocks, waves, and train capacity so combat interactions can be checked immediately.

Mail Carrier is available on `8`, with a fresh random recipient per envelope.

Spawned cars carry their workbook health and count as obstacles: a spider spawned
above a car steps into a clear neighbouring lane, and with cars across every lane
within three steps it stops and bites at 25 damage per second (the health bar and
jaws marker appear on the bitten car, which is removed when destroyed).

## AI art in Unit Sandbox

The main menu's Unit Sandbox includes 14 free **ART PROTOTYPE** entries at the
start of the Train Yard, using the 21 generated PNGs. Drag them onto an engine
like other cars; scroll to see the rest of the roster. These are visual mockups
with placeholder health/footprints and no attacks or special abilities. Diesel
is a coupled visual mockup here, not a working alternative locomotive.

Drafts are exclusive to Unit Sandbox. Campaign and other challenge rosters keep
the eight implemented cars. Native images live in `assets/sprites/units/ai_drafts/`;
render-time scaling leaves their source pixels intact.
