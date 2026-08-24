class_name Enemy
extends CharacterBody3D

const GameSfx = preload("res://scripts/audio/game_sfx.gd")
## 基础敌人 AI：近战冲锋或远程投射物攻击。
## 修正：glTF 前向 +Z 对玩家朝向；GLB 骨骼动画（idle/walk/sprint/attack/die）播放；模型归一化到真实身高。

signal died(enemy: Enemy)
signal damaged

const MODEL_TARGET_HEIGHT := 1.8
const DIE_DELAY := 0.8
## 手部骨骼名（Kenney Mini Characters 单臂骨骼：肩→手）
const RIGHT_HAND_BONE := "arm-right"
## 骨骼跟随更新优先级：晚于 AnimationPlayer（0）读取当帧姿态
const WEAPON_FOLLOW_PRIORITY := 64
const ENEMY_SHOT_SOUND_PATH := "res://assets/kenney/impact-sounds/Audio/impactGeneric_light_002.ogg"
const ENEMY_HURT_SOUND_PATH := "res://assets/kenney/impact-sounds/Audio/impactBell_heavy_002.ogg"

var data: EnemyData
var player: PlayerController
var content: ContentManager
var loot_callback: Callable = Callable()

var hp := 50.0
var _attack_cooldown := 0.0
var _attack_anim_time := 0.0
var _is_dying := false
var _anim_player: AnimationPlayer = null
## 场景结构：ModelRoot（运行时注入敌人模型）与 WeaponAnchor（武器挂点，可人工设计）
var _model_root: Node3D = null
var _weapon_anchor: Node3D = null
var _enemy_shot_stream: AudioStream = null
var _enemy_hurt_stream: AudioStream = null
## 武器骨骼跟随状态
var _skel: Skeleton3D = null
var _arm_bone_idx := -1
var _grip_local := Vector3.ZERO
var _muzzle_marker: Marker3D = null
## 武器锚点模式：false = 自动跟随右手（默认，含缩放/朝向归一化）；
## true = 完全使用场景 WeaponAnchor 的人工摆位（用于精细设计 / 缩放微调）。
@export var weapon_anchor_manual := false

func _ready() -> void:
	_model_root = get_node_or_null("ModelRoot")
	_weapon_anchor = get_node_or_null("ModelRoot/WeaponAnchor")

func setup(p_data: EnemyData, p_player: PlayerController, p_content: ContentManager) -> void:
	data = p_data
	player = p_player
	content = p_content
	hp = data.max_hp
	collision_layer = 4
	collision_mask = 1 | 2
	_load_sfx()
	_build_model()

func set_loot_callback(callback: Callable) -> void:
	loot_callback = callback

func _build_model() -> void:
	if _model_root == null:
		return
	# 兵种场景（enemy_runner/shooter/brute.tscn）已预置模型时优先复用，
	# 这样编辑器里人工调整过的模型/武器不会被运行时覆盖。
	var model := _get_scene_model()
	if model == null and data and not data.model_path.is_empty():
		var packed = load(data.model_path)
		if packed is PackedScene:
			model = packed.instantiate() as Node3D
			if model:
				_model_root.add_child(model)
				_fit_model(model)
	if model != null:
		# 武器挂点必须在动画开始前读取“静止姿态”的骨骼数据
		if data and not data.weapon_model_path.is_empty():
			_attach_weapon(model)
		_setup_animation_player(model)
	if player:
		_face_player()

## 场景中已预置的角色模型（ModelRoot 下除武器锚点外的第一个 Node3D）
func _get_scene_model() -> Node3D:
	for c in _model_root.get_children():
		if c is Node3D and c != _weapon_anchor:
			return c as Node3D
	return null

## 将 GLB 归一化到玩家级身高，脚底贴地，X/Z 居中（模型原点不一定在脚底）。
func _fit_model(model: Node3D) -> void:
	var aabb := _collect_model_aabb(model)
	if aabb.size.y <= 0.0001:
		return
	var target_height := (data.model_height if data else MODEL_TARGET_HEIGHT)
	target_height *= (data.scale if data else 1.0)
	var s := target_height / aabb.size.y
	var center := aabb.get_center()
	model.scale = Vector3.ONE * s
	model.position = Vector3(-center.x * s, -aabb.position.y * s, -center.z * s)

func _collect_model_aabb(root: Node3D) -> AABB:
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

func _setup_animation_player(model: Node3D) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim_player = players[0] as AnimationPlayer
	if _anim_player == null:
		return
	if _anim_player.has_animation("static"):
		_anim_player.play("static")
	elif _anim_player.has_animation("idle"):
		_play_loop("idle")

func _play_loop(anim_name: String) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	if _anim_player.current_animation == anim_name and _anim_player.is_playing():
		return
	var anim := _anim_player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR
	_anim_player.play(anim_name)

func _play_once(anim_name: String) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	_anim_player.play(anim_name)

## 近战/远程敌人手持武器：实例化 data.weapon_model_path 到场景中的 WeaponAnchor 锚点。
## 锚点两种模式（见 @export）：
##   - 自动模式（默认）：程序从蒙皮数据找到右手骨骼手部位置，每帧把锚点放到手上，
##     朝向 = 敌人正前方（水平）；weapon_yaw_deg 只反映武器模型自身朝向（如 blaster 180°）。
##   - 手动模式：锚点完全由用户在 enemy.tscn 场景里人工设计（位置/旋转/缩放），
##     运行时不再修改锚点 —— 用来精细摆放近战武器、调缩放。
func _attach_weapon(model: Node3D) -> void:
	if _weapon_anchor == null:
		return
	var prop: Node3D = null
	# 场景预置武器（用户可手工调整大小/位置）→ 直接复用
	if _weapon_anchor.get_child_count() > 0:
		prop = _weapon_anchor.get_child(0) as Node3D
		if prop != null:
			for m in prop.find_children("Muzzle", "Marker3D", true, false):
				_muzzle_marker = m as Marker3D
				break
	if prop == null:
		if data == null or data.weapon_model_path.is_empty():
			return
		var packed = load(data.weapon_model_path)
		if packed == null or not (packed is PackedScene):
			return
		prop = packed.instantiate() as Node3D
		if prop == null:
			return
		_weapon_anchor.add_child(prop)
		prop.rotation_degrees = Vector3(0.0, data.weapon_yaw_deg, 0.0)
		var aabb := _collect_model_aabb(prop)
		if aabb.size.length_squared() > 0.0001:
			var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
			# 锚点世界变换使用正交基（无缩放），prop 直接按目标长度换算即可。
			var s := data.weapon_world_length / max_dim
			var center := aabb.get_center()
			prop.scale = Vector3.ONE * s
			prop.position = -s * center
			# 枪口标记（仅远程武器需要）：该 Kenney blaster 枪口朝 -Z。
			# marker 位于 prop 局部空间（未缩放），半长 = aabb.size.z / 2，不能再乘 s。
			var muzzle := Marker3D.new()
			muzzle.name = "Muzzle"
			muzzle.position = Vector3(0.0, 0.0, -aabb.size.z * 0.5)
			prop.add_child(muzzle)
			_muzzle_marker = muzzle
	if weapon_anchor_manual:
		return
	var skel := _find_skeleton(model)
	if skel != null:
		var arm_idx := skel.find_bone(RIGHT_HAND_BONE)
		if arm_idx >= 0:
			var hand_data := _calc_hand_data(skel, arm_idx)
			if not hand_data.is_empty():
				_skel = skel
				_arm_bone_idx = arm_idx
				_grip_local = hand_data["grip_local"]
				process_priority = WEAPON_FOLLOW_PRIORITY
				return
	# 兜底（无骨架/无手部数据）：锚点手前高度（约 0.8m，非头部）
	_weapon_anchor.position = Vector3(0.0, 0.8, 0.24)

func _find_skeleton(model: Node3D) -> Skeleton3D:
	for c in model.find_children("*", "Skeleton3D", true, false):
		return c as Skeleton3D
	return null

## 在静止姿态下计算手部握点（骨骼局部坐标）。读取时机必须是动画开始前（rest 姿态）。
## 枪的朝向不跟随手臂（Kenney 持枪动画手臂是斜向上抬起的），而是固定在敌人前向水平，
## 只在位置上“跟着手走”。
func _calc_hand_data(skel: Skeleton3D, bone_idx: int) -> Dictionary:
	var rest := skel.get_bone_global_pose(bone_idx)
	# 手臂末端 = 蒙皮顶点中该骨骼主导权重且离骨骼起点最远的点
	var best := rest.origin + rest.basis.y
	var best_d := -INF
	for mi in skel.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		for surf in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(surf)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if bones.size() < verts.size() * 4 or weights.size() < verts.size() * 4:
				continue
			for v in verts.size():
				var w_arm := 0.0
				var w_total := 0.0
				for j in 4:
					var b := bones[v * 4 + j]
					var w := weights[v * 4 + j]
					w_total += w
					if b == bone_idx:
						w_arm += w
				if w_total <= 0.0 or w_arm <= w_total * 0.5:
					continue
				var d := verts[v].distance_squared_to(rest.origin)
				if d > best_d:
					best_d = d
					best = verts[v]
	if best_d <= 0.0001:
		return {}
	# 握点取手末端内收 12%（不要顶在指尖）
	var grip := rest.origin.lerp(best, 0.88)
	var grip_local := rest.affine_inverse() * grip
	return {"grip_local": grip_local}

## 自动模式：每帧把锚点放到手部骨骼当前姿态的位置上，朝向保持“敌人正前方、水平”。
## 锚点引用自场景（manual 模式或手动摆好时本函数不生效）。
func _process(_delta: float) -> void:
	if get_tree().paused:
		return
	if weapon_anchor_manual or _weapon_anchor == null:
		return
	if _skel == null or _arm_bone_idx < 0:
		return
	var pose := _skel.get_bone_global_pose(_arm_bone_idx)
	var hand_world := _skel.global_transform * (pose * _grip_local)
	# 锚点基 = 敌人前向（水平）；武器模型自身朝向由 weapon_yaw_deg 已解决（prop 旋转）
	var body_basis := _model_root.global_transform.basis.orthonormalized()
	# 数据驱动的握持微调（EnemyData.weapon_grip_offset，默认零偏移）
	if data:
		hand_world += body_basis * data.weapon_grip_offset
	_weapon_anchor.global_transform = Transform3D(body_basis, hand_world)

func _build_collision() -> void:
	# 场景 enemy.tscn 已内置胶囊碰撞，保留该函数仅为兼容性兜底（旧代码调用已移除）
	pass

func _load_sfx() -> void:
	if ResourceLoader.exists(ENEMY_SHOT_SOUND_PATH):
		var res = load(ENEMY_SHOT_SOUND_PATH)
		if res is AudioStream:
			_enemy_shot_stream = res
	if ResourceLoader.exists(ENEMY_HURT_SOUND_PATH):
		var res = load(ENEMY_HURT_SOUND_PATH)
		if res is AudioStream:
			_enemy_hurt_stream = res

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if player == null or not is_instance_valid(player) or hp <= 0.0 or _is_dying:
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_attack_anim_time = maxf(_attack_anim_time - delta, 0.0)
	var can_see := _can_see_player()
	if not can_see:
		# 隔墙不索敌：不移动、不转向、不攻击
		velocity.x = move_toward(velocity.x, 0.0, data.speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, data.speed * 4.0 * delta)
		if _attack_anim_time <= 0.0:
			_play_loop("idle")
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var dir := to_player.normalized() if dist > 0.01 else Vector3.ZERO
	_face_player()

	if data.ai_type == "ranged":
		if dist > data.attack_range:
			velocity.x = dir.x * data.speed
			velocity.z = dir.z * data.speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, data.speed * 4.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, data.speed * 4.0 * delta)
			if _attack_cooldown <= 0.0:
				_attack_cooldown = data.attack_cooldown
				_shoot()
				_trigger_attack_animation("holding-both-shoot", 0.5)
	else:
		if dist > data.attack_range:
			velocity.x = dir.x * data.speed
			velocity.z = dir.z * data.speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, data.speed * 4.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, data.speed * 4.0 * delta)
			if _attack_cooldown <= 0.0:
				_attack_cooldown = data.attack_cooldown
				_melee()
				_trigger_attack_animation("attack-melee-right", 0.55)

	if _attack_anim_time <= 0.0:
		_update_movement_animation()

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()

func _update_movement_animation() -> void:
	if _anim_player == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.6:
		var base := data.speed if data else 3.0
		_play_loop("sprint" if speed > base * 0.8 else "walk")
	else:
		_play_loop("idle")

func _trigger_attack_animation(anim_name: String, block_time: float) -> void:
	_attack_anim_time = block_time
	_play_once(anim_name)

func _face_player() -> void:
	if player == null:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() <= 0.01:
		return
	var forward := "+z"
	if data and not data.model_forward.is_empty():
		forward = data.model_forward
	var yaw: float
	if forward == "-z":
		yaw = atan2(-to_player.x, -to_player.z)
	else:
		# glTF/该 Kenney 角色包前向为 +Z
		yaw = atan2(to_player.x, to_player.z)
	rotation.y = yaw

## 视线检测：仅当敌人与玩家之间没有墙（碰撞层 1）时才视为可见/可索敌。
func _can_see_player() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var from := global_position + Vector3(0.0, 1.2, 0.0)
	var to := player.global_position + Vector3(0.0, 1.2, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [self, player])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty()

func _melee() -> void:
	if player:
		player.take_damage(data.damage)

func _shoot() -> void:
	if player == null:
		return
	var origin := global_position + Vector3(0.0, 1.2, 0.0)
	if _muzzle_marker != null and is_instance_valid(_muzzle_marker):
		origin = _muzzle_marker.global_position
	var dir := (player.global_position + Vector3(0.0, 1.2, 0.0) - origin)
	dir = dir.normalized()
	var projectile := EnemyProjectile.new()
	get_parent().add_child(projectile)
	projectile.global_position = origin
	projectile.setup(dir, data.damage, data.projectile_speed)
	GameSfx.play(_enemy_shot_stream, randf_range(0.9, 1.05), -12.0)

func take_damage(amount: float, _source: Node = null) -> bool:
	if hp <= 0.0:
		return false
	hp -= amount
	damaged.emit()
	GameSfx.play(_enemy_hurt_stream, randf_range(1.0, 1.2), -8.0)
	if hp <= 0.0:
		_die()
		return true
	return false

func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	set_physics_process(false)
	_play_once("die")
	if loot_callback.is_valid():
		loot_callback.call(self)
	died.emit(self)
	get_tree().create_timer(DIE_DELAY, false).timeout.connect(_finish_die)

func _finish_die() -> void:
	if is_instance_valid(self):
		queue_free()
