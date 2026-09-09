extends Resource
class_name TowerData
## Data-only tower catalog entry. Equivalent of Unity's [Serializable] Tower class.

@export var tower_name: String = ""
@export var cost: int = 0
@export var scene: PackedScene
@export var summary: String = "" ## One line shown in the selected-defense panel.
@export var icon: Texture2D ## Cursor preview while dragging from the shop.
## Informational only — the real value used by TrainConvoy's hard carry-capacity
## check lives on the car's own instantiated scene, not here. Kept in sync so the
## shop UI (which reads this resource, not the scene) isn't misleading.
@export var weight: float = 1.0
## Hit points from the asset workbook's Health column. Biting spiders and
## ramming wear this down; at zero the car is destroyed and the train closes
## the gap.
@export var health: int = 200
