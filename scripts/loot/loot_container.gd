class_name LootContainer
extends StaticBody3D
## 搜索容器：玩家交互后打开并生成掉落。

signal container_opened(container: LootContainer)

var content: ContentManager
var loot_table_id := "raid:crate_basic"
var is_opened := false
var container_name := "物资箱"

func setup(p_content: ContentManager, p_loot_table_id: String, p_name: String = "物资箱") -> void:
	content = p_content
	loot_table_id = p_loot_table_id
	container_name = p_name

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	_build_visual()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.5, 0.0)
	add_child(collision)

func _build_visual() -> void:
	var mesh := MeshInstance3D.new()
	var packed = load("res://assets/kenney/blaster/Models/GLB format/crate-medium.glb")
	if packed is PackedScene:
		var model = packed.instantiate()
		mesh.add_child(model)
		mesh.scale = Vector3.ONE * 0.8
	else:
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.4, 0.2)
		box.material = mat
		mesh.mesh = box
	add_child(mesh)

func open(player: PlayerController, loot_spawner: Callable) -> Array[Dictionary]:
	if is_opened:
		return []
	is_opened = true
	var table: LootTableData = content.get_loot_table(loot_table_id) if content else null
	var drops: Array[Dictionary] = []
	if table:
		drops = table.roll()
	# 让箱子稍微变暗表示已开
	var mesh := get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.scale = Vector3(1.0, 0.7, 1.0)
	if loot_spawner.is_valid():
		loot_spawner.call(global_position, drops)
	container_opened.emit(self)
	return drops
