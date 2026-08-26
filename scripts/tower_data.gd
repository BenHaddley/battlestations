extends Resource
class_name TowerData
## Data-only tower catalog entry. Equivalent of Unity's [Serializable] Tower class.

@export var tower_name: String = ""
@export var cost: int = 0
@export var scene: PackedScene
@export var summary: String = "" ## One line shown in the selected-defense panel.
@export var icon: Texture2D ## Cursor preview while dragging from the shop.
@export var weight: float = 1.0 ## Contribution to the train's total weight; the engine slows past its weight threshold.
