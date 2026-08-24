extends Node
## 验证：远程敌人武器是否挂到右手骨骼并朝向敌人前向�?## 运行：godot --headless dev_temp/probe_weapon.tscn --path .

func _ready() -> void:
	var data := EnemyData.new()
	data.id = "probe:shooter"
	data.model_path = "res://assets/kenney/mini_characters/Models/GLB format/character-female-a.glb"
	data.max_hp = 45.0
	data.speed = 3.5
	data.damage = 10.0
	data.attack_range = 14.0
	data.attack_cooldown = 1.2
	data.projectile_speed = 20.0
	data.ai_type = "ranged"
	data.model_height = 1.8
	data.scale = 1.0

	var player := PlayerController.new()
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, 50.0)
	print("PROBE-W player pos=", player.global_position)

	var enemy: Enemy = (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(enemy)
	enemy.global_position = Vector3(0.0, 0.0, 0.0)
	print("PROBE-W after spawn enemy=", enemy.global_position, " player=", player.global_position)
	enemy.setup(data, player, null)
	print("PROBE-W after setup enemy=", enemy.global_position, " parent=", enemy.get_parent().name)
	for f in 6:
		await get_tree().process_frame
		print("PROBE-W frame ", f, " enemy=", enemy.global_position, " vel=", enemy.velocity,
			" onfloor=", enemy.is_on_floor(), " player=", player.global_position)
	print("PROBE-W modelRoot global=", enemy._model_root.global_transform)
	print("PROBE-W skel global=", enemy._skel.global_transform)
	var skel_space := enemy._skel.get_bone_global_pose(enemy._arm_bone_idx)
	print("PROBE-W boneGlobal(skel-space) origin=", skel_space.origin, " basisY=", skel_space.basis.y)
	print("PROBE-W holder parent=", enemy._weapon_anchor.get_parent().name,
		" holder local=", enemy._weapon_anchor.transform)
	print("PROBE-W skel=", enemy._skel != null, " holder=", enemy._weapon_anchor != null,
		" muzzle=", enemy._muzzle_marker != null)
	if enemy._weapon_anchor == null:
		print("PROBE-W FAIL: no weapon holder")
		get_tree().quit(2)
		return
	var hand_skel := enemy._skel.get_bone_global_pose(enemy._arm_bone_idx)
	var hand_world := enemy._skel.global_transform * (hand_skel * enemy._grip_local)
	var holder_pos := enemy._weapon_anchor.global_position
	print("PROBE-W rest holder=", holder_pos, " hand=", hand_world,
		" dist=", holder_pos.distance_to(hand_world))
	if enemy._anim_player:
		enemy._anim_player.play("holding-both-shoot")
	var muzzle_pos := Vector3.ZERO
	for i in 24:
		await get_tree().process_frame
		muzzle_pos = enemy._muzzle_marker.global_position
	holder_pos = enemy._weapon_anchor.global_position
	hand_world = enemy._skel.global_transform * (enemy._skel.get_bone_global_pose(enemy._arm_bone_idx) * enemy._grip_local)
	var fwd := (muzzle_pos - holder_pos).normalized()
	print("PROBE-W pose holder=", holder_pos, " hand=", hand_world,
		" dist=", holder_pos.distance_to(hand_world))
	print("PROBE-W muzzle=", muzzle_pos, " gunFwd=", fwd)
	print("PROBE-W fwd.z=", fwd.z, " (holding-both-shoot 时应基本朝玩�?+Z)")
	get_tree().quit(0)
