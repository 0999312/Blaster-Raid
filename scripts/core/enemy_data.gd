class_name EnemyData
extends Resource
## 数据驱动敌人定义。

@export var id: String = ""
@export var display_name: String = ""
@export var model_path: String = ""
@export var max_hp: float = 50.0
@export var speed: float = 4.0
@export var damage: float = 8.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0
@export var projectile_speed: float = 18.0
@export var projectile: bool = true
@export var ai_type: String = "melee"  # melee / ranged
@export var scale: float = 1.0
@export var model_height: float = 1.8
@export var model_forward: String = "+z"  # "+z" 或 "-z"
@export var color: Color = Color.WHITE
@export var loot_table_id: String = "loot_table:enemy_basic"
@export var experience: int = 5
@export var tags: Array[String] = []
## 手持武器（近战/远程均可）：模型路径 / 目标世界长度（米）/ 武器自身 Y 轴偏航角（度）
## weapon_yaw_deg：blaster 类枪口为 -Z，需 180° 让枪口朝敌人前向；KayKit 等 Y 轴长武器用 0。
## weapon_model_path 为空 = 空手。
@export var weapon_model_path: String = ""
@export var weapon_world_length: float = 0.55
@export var weapon_yaw_deg: float = 0.0
## 武器握持微调偏移（自动跟随模式下生效）：在“敌人前向水平基”里的附加位移，
## 用于数据驱动地修正握点（如枪柄离手过远），无需改场景/改代码。
@export var weapon_grip_offset: Vector3 = Vector3.ZERO
