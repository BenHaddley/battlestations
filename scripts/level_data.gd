extends Resource
class_name LevelData
## Data-only campaign level entry. wave_count == 0 means endless (no
## level-complete trigger) — used for the post-campaign "Open Rails" state.

@export var level_name: String = ""
@export var wave_count: int = 3
@export var starting_currency: int = 300
## Indices into BuildManager.towers — the cumulative roster available in the
## shop for this level (and every level after it).
@export var unlocked_tower_indices: Array[int] = []
## Indices of the cars newly introduced this level, for the level-complete
## reward callout. Empty if nothing new (the first level). A level can unlock
## several cars at once.
@export var new_tower_indices: Array[int] = []
## Index into TrackRenderer's authored reference-layout library. -1 retains
## procedural generation (used by post-campaign Open Rails).
@export var track_layout_index: int = -1
