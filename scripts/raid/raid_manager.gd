class_name RaidManager
extends Node3D
## 单局撤离行动管理器：地图、玩家、敌人、容器、拾取、撤离流程。

signal raid_extracted(valuable_value: int)
signal raid_failed
signal extraction_progress_changed(progress: float)
signal upgrade_offered(choices: Array[Dictionary])
signal item_picked(display_name: String, count: int)

## 兵种场景（模型+武器已预置，可在编辑器里人工调锚点）；未匹配时回退基场景
const ENEMY_SCENES := {
	"raid:runner": preload("res://scenes/enemy_runner.tscn"),
	"raid:shooter": preload("res://scenes/enemy_shooter.tscn"),
	"raid:brute": preload("res://scenes/enemy_brute.tscn"),
}
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROTO_BASE := "res://assets/kenney/prototype/Models/GLB format/"
## 撤离点素材主题（绿）
const EXTRACT_GREEN := Color(0.2, 0.9, 0.4)

var content: ContentManager
var inputs: GuideInputManager
var player: PlayerController
var map_builder: MapBuilder
var extract_area: Area3D
var enemy_root: Node3D
var loot_root: Node3D
var container_root: Node3D
var extraction_point: Node3D

var raid_active := false
var extracted := false
var extraction_timer := 0.0
const EXTRACTION_TIME := 4.0
const INTERACT_DISTANCE := 3.0
const UPGRADE_POOL := [
	{"id": "damage_up", "name": "强化火力", "desc": "武器伤害 +20%", "kind": "weapon_damage", "value": 0.2},
	{"id": "speed_up", "name": "轻装跑", "desc": "移动速度 +10%", "kind": "move_speed", "value": 0.1},
	{"id": "max_hp", "name": "厚甲", "desc": "最大生命 +20", "kind": "max_health", "value": 20.0},
	{"id": "reload_up", "name": "快速装填", "desc": "换弹速度 +15%", "kind": "reload_speed", "value": 0.15},
	{"id": "loot_up", "name": "搜刮直觉", "desc": "立即获得物资", "kind": "loot", "value": 3},
]

var _map_data: Dictionary = {}
var _extract_arrow: Node3D = null

func _ready() -> void:
	# 暂停时战斗逻辑（敌人/投射物/撤离计时）不运行；UI/输入仍由 Main 以 ALWAYS 处理
	process_mode = Node.PROCESS_MODE_PAUSABLE

func setup(p_content: ContentManager, p_inputs: GuideInputManager) -> void:
	content = p_content
	inputs = p_inputs

func start_raid(p_seed: int, weapon_overrides: Array[WeaponData] = [], speed_mult: float = 1.0, max_health: float = 100.0, installed_attachments: Dictionary = {}) -> void:
	clear_raid()
	raid_active = true
	extracted = false
	extraction_timer = 0.0
	_setup_lighting()

	map_builder = MapBuilder.new()
	add_child(map_builder)
	_map_data = map_builder.build(p_seed)

	enemy_root = Node3D.new()
	enemy_root.name = "Enemies"
	add_child(enemy_root)
	loot_root = Node3D.new()
	loot_root.name = "Loot"
	add_child(loot_root)
	container_root = Node3D.new()
	container_root.name = "Containers"
	add_child(container_root)

	_spawn_player(weapon_overrides, speed_mult, max_health, installed_attachments)
	_spawn_enemies()
	_spawn_containers()
	_spawn_extraction()

func clear_raid() -> void:
	raid_active = false
	extraction_timer = 0.0
	for child in get_children():
		child.queue_free()
	player = null
	map_builder = null
	enemy_root = null
	loot_root = null
	container_root = null
	extract_area = null
	extraction_point = null
	_extract_arrow = null

func _setup_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	add_child(light)

func _spawn_player(weapon_overrides: Array[WeaponData], speed_mult: float, max_health: float, installed_attachments: Dictionary = {}) -> void:
	var start: Vector3 = _map_data.get("start", Vector3.ZERO)
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	player.global_position = start
	player.reset_physics_interpolation()
	player.setup(inputs.actions, content, max_health, speed_mult)
	player.died.connect(_on_player_died)
	player.set_controls_enabled(true)
	# 局外整备选定的武器
	if not weapon_overrides.is_empty():
		player.weapon_controller.weapons.clear()
		player.weapon_controller.mags.clear()
		player.weapon_controller.current_index = 0
		for w in weapon_overrides:
			player.weapon_controller.add_weapon_override(w)
	# 应用改枪配置
	for weapon_id in installed_attachments.keys():
		var slots: Dictionary = installed_attachments[weapon_id]
		for slot in slots.keys():
			player.weapon_controller.install_attachment(String(weapon_id), String(slots[slot]))

func _spawn_enemies() -> void:
	var spawns: Array = _map_data.get("enemy_spawns", [])
	var enemy_ids := ["raid:runner", "raid:runner", "raid:shooter", "raid:shooter", "raid:brute", "raid:runner"]
	var spawn_index := 0
	for pos in spawns:
		var enemy_id: String = enemy_ids[spawn_index % enemy_ids.size()]
		_spawn_enemy(enemy_id, pos)
		spawn_index += 1

func _spawn_enemy(enemy_id: String, pos: Vector3) -> void:
	var data: EnemyData = content.get_enemy(enemy_id)
	if data == null:
		return
	var scene: PackedScene = ENEMY_SCENES.get(enemy_id, ENEMY_SCENE)
	var enemy: Enemy = scene.instantiate() as Enemy
	if enemy == null:
		return
	enemy_root.add_child(enemy)
	enemy.global_position = pos
	enemy.reset_physics_interpolation()
	enemy.setup(data, player, content)
	enemy.set_loot_callback(_on_enemy_died)

func _on_enemy_died(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy.data == null:
		return
	var table: LootTableData = content.get_loot_table(enemy.data.loot_table_id)
	if table:
		var drops := table.roll()
		spawn_loot_at(enemy.global_position, drops)
	if enemy.data.tags.has("enemy:elite"):
		_offer_upgrade()

func _offer_upgrade() -> void:
	var choices: Array[Dictionary] = []
	var pool := UPGRADE_POOL.duplicate()
	while choices.size() < 3 and pool.size() > 0:
		var idx := randi_range(0, pool.size() - 1)
		choices.append(pool[idx].duplicate())
		pool.remove_at(idx)
	upgrade_offered.emit(choices)

func _spawn_containers() -> void:
	var positions: Array = _map_data.get("container_spawns", [])
	for pos in positions:
		var container: LootContainer = LootContainer.new()
		container_root.add_child(container)
		container.global_position = pos
		container.setup(content, "raid:crate_basic")

func _spawn_extraction() -> void:
	var pos: Vector3 = _map_data.get("extraction", Vector3.ZERO)
	extraction_point = Node3D.new()
	extraction_point.name = "ExtractionPoint"
	add_child(extraction_point)
	extraction_point.global_position = pos
	build_extraction_marker(extraction_point)

	extract_area = Area3D.new()
	extract_area.name = "ExtractionArea"
	extract_area.collision_layer = 0
	extract_area.collision_mask = 2
	extract_area.monitoring = true
	extraction_point.add_child(extract_area)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.2
	shape.height = 2.0
	collision.shape = shape
	collision.position = Vector3(0.0, 1.0, 0.0)
	extract_area.add_child(collision)
	# 悬浮箭头动画
	if _extract_arrow:
		_extract_arrow.process_mode = Node.PROCESS_MODE_INHERIT

func build_extraction_marker(parent: Node3D) -> void:
	var disc := _spawn_proto("indicator-round-a.glb", parent,
		Vector3(0.0, 0.02, 0.0), Vector3(4.4, 0.12, 4.4), EXTRACT_GREEN, 1.6, false)
	if disc:
		disc.position.y = 0.02

## 实例化 prototype 模型：归一化到指定尺寸（scale 向量），并应用绿色发光材质。
## 注意：pos 是相对 parent 的局部坐标（如箭头挂在撤离点上方 1.7m）——
## 必须用 inst.position，用 global_position 会把素材丢到世界原点（Bug #5.2）。
func _spawn_proto(model_name: String, parent: Node3D, pos: Vector3, scale_v: Vector3,
		green: Color, energy: float, emissive_only: bool) -> Node3D:
	var packed = load(PROTO_BASE + model_name)
	if packed == null or not (packed is PackedScene):
		return null
	var inst: Node3D = packed.instantiate() as Node3D
	if inst == null:
		return null
	parent.add_child(inst)
	inst.position = pos
	inst.scale = scale_v
	_apply_emissive(inst, green, energy, emissive_only)
	return inst

func _apply_emissive(root: Node3D, color: Color, energy: float, emissive_only: bool) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color if not emissive_only else Color.WHITE
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emissive_only else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.material_override = mat

func spawn_loot_at(pos: Vector3, drops: Array[Dictionary]) -> void:
	for drop in drops:
		var item: ItemData = content.get_item(String(drop.get("id", "")))
		if item == null:
			continue
		var pickup := Pickup.new()
		loot_root.add_child(pickup)
		pickup.global_position = pos + Vector3(randf_range(-0.6, 0.6), 0.5, randf_range(-0.6, 0.6))
		pickup.setup(item, int(drop.get("count", 1)), content)
		pickup.picked.connect(_on_item_picked)

func _on_item_picked(display_name: String, count: int) -> void:
	item_picked.emit(display_name, count)

## HUD 交互提示：附近有可搜刮的箱子时返回提示文本。
func get_interaction_hint() -> String:
	if not raid_active or player == null:
		return ""
	var best_dist := INF
	for child in container_root.get_children():
		if child is LootContainer:
			var c: LootContainer = child as LootContainer
			if c.is_opened:
				continue
			var dist: float = c.global_position.distance_to(player.global_position)
			if dist < best_dist:
				best_dist = dist
	if best_dist < INTERACT_DISTANCE:
		return "按 E 搜刮物资箱"
	return ""

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# 撤离点悬浮箭头动画
	if _extract_arrow and is_instance_valid(_extract_arrow):
		_extract_arrow.rotate_y(delta * 1.5)
		_extract_arrow.position.y = 1.7 + sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 0.12
	if not raid_active or player == null:
		return
	if extracted:
		return
	_handle_interaction()
	_handle_extraction(delta)

func _handle_interaction() -> void:
	var interact: GUIDEAction = inputs.get_action("interact")
	if interact == null or not interact.is_triggered():
		return
	var best_container: LootContainer = null
	var best_dist := INF
	for child in container_root.get_children():
		if child is LootContainer:
			var c: LootContainer = child as LootContainer
			if c.is_opened:
				continue
			var dist: float = c.global_position.distance_to(player.global_position)
			if dist < INTERACT_DISTANCE and dist < best_dist:
				best_dist = dist
				best_container = c
	if best_container:
		best_container.open(player, spawn_loot_at)

func _handle_extraction(delta: float) -> void:
	var inside := false
	if extract_area:
		for body in extract_area.get_overlapping_bodies():
			if body == player:
				inside = true
				break
	if inside:
		extraction_timer += delta
	else:
		extraction_timer = maxf(extraction_timer - delta * 2.0, 0.0)
	extraction_progress_changed.emit(extraction_timer / EXTRACTION_TIME)
	if extraction_timer >= EXTRACTION_TIME:
		_extract()

func _extract() -> void:
	extracted = true
	raid_active = false
	player.set_controls_enabled(false)
	var valuable := player.inventory.get_total_value(content) if player.inventory else 0
	raid_extracted.emit(valuable)

func _on_player_died() -> void:
	raid_active = false
	extracted = true
	player.set_controls_enabled(false)
	raid_failed.emit()

func get_extraction_progress() -> float:
	return extraction_timer / EXTRACTION_TIME
