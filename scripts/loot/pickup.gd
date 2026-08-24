class_name Pickup
extends Area3D
## 可拾取物：玩家碰到后自动进入背包 / 补给。
## 模型按类别归一化到统一世界尺寸（Kenney 食物模型原始仅约 0.2m，
## 直接 0.45 倍缩放会小到看不见），并绕 Y 轴慢速自旋提升辨识度。

signal picked(display_name: String, count: int)

## 各类目标世界尺寸（米）
const TARGET_SIZE := {
	"food": 0.30,
	"health": 0.34,
	"ammo": 0.36,
	"valuable": 0.30,
	"attachment": 0.55,
}

var item: ItemData
var count := 1
var content: ContentManager
var collected := false

var _mesh: MeshInstance3D = null
var _spin_speed := 0.0
var _base_y := 0.0
var _model_built := false

func setup(p_item: ItemData, p_count: int, p_content: ContentManager) -> void:
	item = p_item
	count = p_count
	content = p_content
	# 注意：本节点 add_child 后 _ready 先于 setup 执行，item 必须就绪后再构建模型
	_build_model()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)

func _build_model() -> void:
	if _model_built:
		return
	_model_built = true
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	if item and not item.model_path.is_empty():
		var packed = load(item.model_path)
		if packed is PackedScene:
			var model = packed.instantiate()
			_mesh.add_child(model)
			_fit_model(model)
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.3, 0.3)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.9, 0.4)
		box.material = mat
		_mesh.mesh = box
		_mesh.scale = Vector3.ONE * 0.8
	# 悬浮高度：模型中心约在 0.35m
	_base_y = 0.35
	_mesh.position.y = _base_y
	_spin_speed = randf_range(1.0, 1.8)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	collision.shape = shape
	collision.position.y = _base_y
	add_child(collision)

## 把模型归一化到类目标尺寸并居中（原点即模型中心）
func _fit_model(model: Node3D) -> void:
	var aabb := _collect_aabb(model)
	if aabb.size.length_squared() <= 0.0001:
		return
	var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var target: float = TARGET_SIZE.get(item.category if item else "", 0.35)
	var s := target / max_dim
	var center := aabb.get_center()
	model.scale = Vector3.ONE * s
	model.position = -s * center

func _collect_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child as MeshInstance3D
		var box := mi.get_aabb()
		var rel := root.global_transform.affine_inverse() * mi.global_transform
		for point in _aabb_corners(box):
			var p := rel * point
			if not found:
				result.position = p
				result.size = Vector3.ZERO
				found = true
			result = result.expand(p)
	return result

func _aabb_corners(box: AABB) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for x in [box.position.x, box.end.x]:
		for y in [box.position.y, box.end.y]:
			for z in [box.position.z, box.end.z]:
				pts.append(Vector3(x, y, z))
	return pts

func _process(delta: float) -> void:
	if collected or _mesh == null:
		return
	_mesh.rotate_y(_spin_speed * delta)
	_mesh.position.y = _base_y + sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 0.04

func _on_body_entered(body: Node) -> void:
	if collected or body == null or not (body is PlayerController):
		return
	var player := body as PlayerController
	collected = true
	if item == null:
		queue_free()
		return
	if item.category == "ammo" and player.weapon_controller:
		player.weapon_controller.add_ammo(item.ammo_type, item.ammo_amount * count)
	if player.inventory:
		player.inventory.add_item(item.id, count)
	picked.emit(item.display_name, count)
	queue_free()
