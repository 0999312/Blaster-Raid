extends Node
## 探测：① 拾取物模型路径能否加载 ② 敌人武器真实世界尺寸/标记位置。
## 运行：godot dev_temp/probe_items.tscn --path .

func _ready() -> void:
	_check_item_models()
	await _check_enemy_gun()
	get_tree().quit(0)

func _check_item_models() -> void:
	var base_dir := "res://assets/kenney/"
	var entries := [
		["food/Models/GLB format/apple.glb", "苹果"],
		["food/Models/GLB format/banana.glb", "香蕉"],
		["food/Models/GLB format/bread.glb", "面包"],
		["food/Models/GLB format/bottle-oil.glb", "医疗饮料"],
		["blaster/Models/GLB format/clip-small.glb", "能量弹匣"],
		["blaster/Models/GLB format/bullet-foam.glb", "泡沫霰弹"],
		["prototype/Models/GLB format/coin.glb", "金币"],
		["blaster/Models/GLB format/scope-small.glb", "瞄准镜"],
		["blaster/Models/GLB format/clip-large.glb", "扩容弹匣"],
		["blaster/Models/GLB format/blaster-a.glb", "blaster-a"],
		["blaster/Models/GLB format/silencer-larger.glb", "加长枪管"],
	]
	for e in entries:
		var r = load(base_dir + e[0])
		var ok := r is PackedScene
		print("ITEM-LOAD ", e[1], " | ", e[0], " => ", ("OK" if ok else "FAIL"), " type=", (r.get_class() if r != null else "null"))
		if ok:
			var scene := r as PackedScene
			var inst := scene.instantiate() as Node3D
			inst.free()

func _check_enemy_gun() -> void:
	var data := EnemyData.new()
	data.model_path = "res://assets/kenney/mini_characters/Models/GLB format/character-female-b.glb"
	data.ai_type = "ranged"
	data.model_height = 1.8
	data.weapon_model_path = "res://assets/kenney/blaster/Models/GLB format/blaster-a.glb"
	data.weapon_world_length = 0.55
	data.weapon_yaw_deg = 180.0
	var dummy := PlayerController.new()
	add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, 4.0)
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
	var enemy := enemy_scene.instantiate() as Enemy
	add_child(enemy)
	enemy.setup(data, dummy, null)
	enemy.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	if enemy._anim_player:
		enemy._anim_player.play("holding-both-shoot")
	for i in 24:
		await get_tree().process_frame
	# 测量武器网格世界尺寸
	var max_dim := 0.0
	for mi in enemy._weapon_anchor.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var aabb := m.get_aabb()
		var pts: Array[Vector3] = []
		for x in [aabb.position.x, aabb.end.x]:
			for y in [aabb.position.y, aabb.end.y]:
				for z in [aabb.position.z, aabb.end.z]:
					pts.append(m.global_transform * Vector3(x, y, z))
		for i in pts.size():
			for j in range(i + 1, pts.size()):
				max_dim = maxf(max_dim, pts[i].distance_to(pts[j]))
	print("GUN-CHECK maxDim=", max_dim, " (约 0.55-0.63 正常，含对角)")
	var holder := enemy._weapon_anchor.global_position
	var muzzle := enemy._muzzle_marker.global_position
	var fwd := (muzzle - holder).normalized()
	print("GUN-CHECK holder=", holder, " muzzle=", muzzle, " halfLen=", holder.distance_to(muzzle), " (期望约 0.275)")
	print("GUN-CHECK gunFwd=", fwd, " (敌人朝 +Z，期望 ≈ (0,0,1)，水平)")
	print("GUN-CHECK enemy yaw=", enemy.rotation.y, " hand世界点=", enemy._skel.global_transform * (enemy._skel.get_bone_global_pose(enemy._arm_bone_idx) * enemy._grip_local))
	# 近战武器（KayKit axe，Y 轴长柄）：验证自动模式下竖直随手
	var melee := EnemyData.new()
	melee.model_path = "res://assets/kenney/mini_characters/Models/GLB format/character-male-a.glb"
	melee.ai_type = "melee"
	melee.model_height = 1.8
	melee.weapon_model_path = "res://assets/kaykit/gltf/axe.gltf"
	melee.weapon_world_length = 0.55
	melee.weapon_yaw_deg = 0.0
	var enemy2 := enemy_scene.instantiate() as Enemy
	add_child(enemy2)
	enemy2.global_position = Vector3(2.0, 0.0, 0.0)
	enemy2.setup(melee, dummy, null)
	enemy2.set_physics_process(false)
	for i in 24:
		await get_tree().process_frame
	var ax_prop := enemy2._weapon_anchor.get_child(0) as Node3D
	var ax_aabb := AABB()
	var found := false
	for mi in ax_prop.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.get_aabb()
		var rel: Transform3D = ax_prop.global_transform.affine_inverse() * m.global_transform
		for x in [b.position.x, b.end.x]:
			for y in [b.position.y, b.end.y]:
				for z in [b.position.z, b.end.z]:
					var p: Vector3 = rel * Vector3(x, y, z)
					if not found:
						ax_aabb.position = p
						ax_aabb.size = Vector3.ZERO
						found = true
					ax_aabb = ax_aabb.expand(p)
	print("AXE-CHECK anchorPos=", enemy2._weapon_anchor.global_position,
		" aabb=", ax_aabb.size, " (Y 长轴 ~0.55 为竖直手持)",
		" axeWorldMaxY=", ax_aabb.end.y)
