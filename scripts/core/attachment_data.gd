class_name AttachmentData
extends Resource
## 枪械配件定义，安装后通过倍率/加法修改武器数值。

@export var id: String = ""
@export var display_name: String = ""
@export var slot: String = ""
@export var rarity: String = "common"
@export var model_path: String = ""

@export var damage_add: float = 0.0
@export var damage_mult: float = 1.0
@export var fire_rate_add: float = 0.0
@export var fire_rate_mult: float = 1.0
@export var magazine_add: int = 0
@export var reserve_add: int = 0
@export var reload_time_mult: float = 1.0
@export var spread_mult: float = 1.0
@export var move_speed_mult: float = 1.0
@export var range_mult: float = 1.0
