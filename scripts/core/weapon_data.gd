class_name WeaponData
extends Resource
## 数据驱动武器定义。

@export var id: String = ""
@export var display_name: String = ""
@export var model_path: String = ""
@export var damage: float = 10.0
@export var fire_rate: float = 6.0
@export var spread_degrees: float = 0.5
@export var magazine_size: int = 30
@export var reserve_ammo: int = 120
@export var reload_time: float = 1.2
@export var auto: bool = true
@export var projectile: bool = false
@export var projectile_speed: float = 40.0
@export var ammo_type: String = "cell"
@export var rarity: String = "common"
@export var range: float = 100.0
@export var base_value: int = 50
@export var tags: Array[String] = []
## 可安装配件的槽位。
@export var attachment_slots: Array[String] = ["scope", "barrel", "mag", "grip"]
