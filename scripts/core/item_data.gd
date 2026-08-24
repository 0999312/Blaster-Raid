class_name ItemData
extends Resource
## 数据驱动物品定义。

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = "misc"  # ammo / food / health / valuable / weapon / attachment
@export var model_path: String = ""
@export var stack_max: int = 99
@export var value: int = 1
@export var hunger_restore: float = 0.0
@export var health_restore: float = 0.0
@export var ammo_type: String = ""
@export var ammo_amount: int = 0
@export var rarity: String = "common"
@export var use_time: float = 0.5
@export var tags: Array[String] = []

func is_food() -> bool:
	return category == "food"

func is_ammo() -> bool:
	return category == "ammo"

func is_valuable() -> bool:
	return category == "valuable"

func is_health() -> bool:
	return category == "health"
