class_name UpgradeData
extends Resource
## 局外永久强化。

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_level: int = 5
@export var cost_base: int = 100
@export var effects: Dictionary = {}  # 例如 {"max_health": 10, "move_speed": 0.1}
