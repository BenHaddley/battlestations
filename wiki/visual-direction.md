# Visual Direction

The recovered illustrated interface is the presentation target for Battle Stations.
It should feel like a hand-built railway control desk laid over the painted board,
not a conventional dark game dashboard.

## Interface language

- Full-height wooden equipment cabinets frame the courtyard.
- The left cabinet prioritizes currency and a compact illustrated car inventory.
- Available cars use bright turquoise card wells; selection uses warm yellow.
- The right cabinet owns transport controls, tutorial imagery, progress, and challenges.
- Station health is a prominent green/red bar beneath the battlefield.
- Text is short and set in the bundled Architects Daughter handwriting face, with
  pictures carrying most of the shop and tutorial communication.
- Avoid clean dashboard cards, realistic materials, or large explanatory copy; the
  screen should read first as a dense hand-inked board game.

## Battlefield language

- Rails are narrow modular pieces embedded into the paving, with clear straight and
  curved sections rather than broad bands over the artwork.
- Routes may vary each run but remain inside the courtyard and form one traversable
  engine-led network that can cover every spider lane.
- Cars remain aligned to track direction, retain readable coupling gaps, and follow
  corners without overlap.
- Weapon identity should be readable from both silhouette and effect: red five-shot
  Minigun spreads contrast with the purple/yellow Ballast car's gravel spray.
- Spider lanes are communicated lightly; they must not look like additional rails.
- Combat feedback should use intentionally imperfect inked arrows, flashes, smoke,
  and symbols rather than polished web-style effects.
- Preserve the current spider death effects' strong impact; Gubgub specifically
  praised their added “pop” in the 2026-08-28 playtest.
- Flat color fields should carry restrained paper flecks and paint streaks; functional
  controls may be crooked, but their hit targets and gameplay behavior stay stable.

## Current screen implementation

- The central board is camera-cropped closer and receives the majority of the width.
- Procedural tracks form dense concentric oval loops contained by the playable board.
- The shop presents ten equal cards in a tightly packed 2×5 tray, mixing large
  illustrated pieces with three crooked handwritten concept cards. Run-status text
  is kept off this component tray; `REMOVE` and the blue points strip own its base.
- Attached cars are palette-varied to keep longer trains readable at a glance.
- The right panel contains playback, tutorial art, wave-route progress, and the
  challenge sheet; selected-unit details no longer compete with those elements.
- The first view is composed as an active turn, with a starter consist and an
  automatically running spider wave, instead of a sparse pre-game configuration.

## Implementation boundary

The reference contains more car types, currencies, challenges, tutorial panels, and
track interactions than the current prototype supports. The interface may preview
those destinations, but controls must not imply functional systems until implemented.

The expanded engine control stand currently violates the battlefield-readability
goal by covering the bottom of the board during the moment spiders reach the station.
The documented direction is a much smaller interface, potentially just Up/Down
keyboard control, so train input never conceals the combat state it is meant to
influence.
