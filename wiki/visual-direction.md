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
- Text is short, handwritten or sign-painted in spirit, with pictures carrying most
  of the shop and tutorial communication.
- Avoid clean dashboard cards, realistic materials, or large explanatory copy; the
  screen should read first as a dense hand-inked board game.

## Battlefield language

- Rails are narrow modular pieces embedded into the paving, with clear straight and
  curved sections rather than broad bands over the artwork.
- Routes may vary each run but remain inside the courtyard and form one traversable
  engine-led network that can cover every spider lane.
- Cars remain aligned to track direction, retain readable coupling gaps, and follow
  corners without overlap.
- Spider lanes are communicated lightly; they must not look like additional rails.
- Combat feedback should use intentionally imperfect inked arrows, flashes, smoke,
  and symbols rather than polished web-style effects.

## Current screen implementation

- The central board is camera-cropped closer and receives the majority of the width.
- Procedural tracks use four or five horizontal sweeps per playthrough.
- The shop presents eight illustrated cards in two columns, with unavailable roster
  concepts clearly disabled.
- Attached cars are palette-varied to keep longer trains readable at a glance.
- The right panel contains playback, tutorial art, wave-route progress, and the
  challenge sheet; selected-unit details no longer compete with those elements.

## Implementation boundary

The reference contains more car types, currencies, challenges, tutorial panels, and
track interactions than the current prototype supports. The interface may preview
those destinations, but controls must not imply functional systems until implemented.
