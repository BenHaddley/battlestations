# Almanac UI assets

The almanac follows the user-supplied parchment, wood, and riveted-metal reference.
The new raster asset is [frame.png](../assets/ui/almanac/frame.png). Tabs, pictograms,
card plates/rivets, selection and keyboard-focus states, scrollbar, locked-entry
symbols, detail panel, and all text are native Godot controls/drawing, so they remain
interactive and scale independently of the background. No generated unit artwork
is used. See the [rendered screen](screenshots/almanac.png).

## Generation record

Generated with the built-in image-generation tool, using the supplied almanac image
as the style reference. The output is copied into the project and included in the
Web export. Final prompt:

> Generate a production game UI background asset, landscape 1536x1024. Reference is the attached Battle Stations almanac image: hand-painted warm aged parchment framed by chunky dark wooden railway sleepers, black iron brackets, rivets and small brass bolts, thick comic ink outlines. Create ONLY the blank outer frame and continuous empty parchment interior. Border occupies outer 5% on all edges; interior uniformly light cream parchment with subtle wear, spacious and readable. Straight-on flat orthographic view, perfectly rectangular, no perspective. NO text, letters, title, icons, tabs, cards, units, silhouettes, scrollbars, notes or watermarks. This will sit behind live Godot controls. Match reference's warm amber/brown industrial storybook style. Save as project UI asset.

## Runtime behavior

- Enemies: the nine current spider archetypes, animated with their game walk frames.
  Dotted Spider uses its base-health stage from `EnemyMovement.DOT_STAGE_TEXTURES`.
- Train Cars: Steam Engine plus Passenger Coach, Brake Van, and Tender.
- Defenses: the five attacking cars, including Mail Carrier. Previews extract the
  scene's chassis/turret textures, scales, and placed idle orientations without
  running combat code or instantiating a live unit in the scene tree.
- Tracks: straight rails, curves, and buffer stops using current board sprites.
- Unseen entries show only anonymous silhouettes/locks, `???`, and `NOT YET
  DISCOVERED`. They have no unit artwork, names, stats, or clickable detail view.
- Counts are unique discoveries within the selected tab, for the active profile.
  Shop availability and campaign unlocks alone do not reveal an entry.
- Cars/spiders are discovered through the existing deployment/spawn hooks. Engines
  and rail pieces are recorded when they appear in a run, including rail extensions.
- Closing the screen restores focus to the title's Almanac button. Escape first
  closes unit details, then the almanac. Narrow windows use a single card column.

Switching to a different profile resets only that destination profile's tutorial
lessons. Its campaign position and discoveries remain intact. At the first station,
the opening tutorial repeats; a later saved station reintroduces its unlocked cars.
Selecting the already active profile does not reset lessons.

Validation covers anonymous entries, preview resources, unique counts, detail locks,
profile persistence/isolation, tutorial resets without campaign loss, and in-run
engine/track discovery in `tests/GameplayRegression.tscn`.
