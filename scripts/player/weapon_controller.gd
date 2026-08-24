class_name WeaponController
extends Node

const GameSfx = preload("res://scripts/audio/game_sfx.gd")
## 武器控制器：射击、换弹、切枪、近战、枪械配件（改枪）生效。

signal ammo_changed(mag: int, reserve: int)
signal weapon_changed(display_name: String)
signal fired
signal hit_enemy(amount: float, died: bool)
signal item_used(display_name: String, detail: String)
signal no_usable_item

var player: PlayerController
var actions: Dictionary = {}
var content: ContentManager

var weapons: Array[WeaponData] = []
var current_index := 0
var installed: Dictionary = {}  # weapon_id -> {slot: attachment_id}
var mags: Dictionary = {}  # weapon_id -> current_mag
var reserves: Dictionary = {}  # ammo_type -> reserve count

var _cooldown := 0.0
var _reload_time_left := 0.0
var _reloading := false
var _viewmodel_rig: Node3D = null
var _viewmodel_model: Node3D = null
var _muzzle_flash: MeshInstance3D = null
var _muzzle_light: OmniLight3D = null
var _muzzle_pos := Vector3.ZERO
var _muzzle_timer := 0.0
var _bob_time := 0.0
var _recoil := 0.0
var _viewmodel_scale := 1.0
var _viewmodel_size := Vector3.ZERO
var _shot_stream: AudioStream = null
var _hit_stream: AudioStream = null
var _reload_start_stream: AudioStream = null
var _reload_done_stream: AudioStream = null

## DOOM 风格视图模型参数：参考 DOOM 截图（武器略偏右居中、枪口指向准星、带摆动/后坐力）
const VIEWMODEL_BASE_POS := Vector3(0.10, -0.235, -0.5)
const VIEWMODEL_BASE_ROT_DEG := Vector3(2.0, 16.0, 0.0)
const VIEWMODEL_TARGET_LENGTH := 0.55
const VIEWMODEL_MODEL_YAW_DEG := 0.0  # 该 Kenney blaster 枪口为 -Z，无需翻转
const BOB_FREQ := 8.0
const BOB_AMP_X := 0.014
const BOB_AMP_Y := 0.010
const RECOIL_KICK_DEG := 6.0
const RECOIL_PUSH := 0.06
const RECOIL_RECOVER_SPEED := 8.0
const MUZZLE_FLASH_TIME := 0.055
const SHOT_SOUND_PATH := "res://assets/kenney/impact-sounds/Audio/impactGeneric_light_000.ogg"
const HIT_SOUND_PATH := "res://assets/kenney/impact-sounds/Audio/impactMetal_light_000.ogg"
const RELOAD_START_SOUND_PATH := "res://assets/kenney/impact-sounds/Audio/impactMetal_medium_000.ogg"
const RELOAD_DONE_SOUND_PATH := "res://assets/kenney/impact-sounds/Audio/impactMetal_heavy_001.ogg"
## 局内强化临时倍率。
var damage_multiplier := 1.0
var reload_time_multiplier := 1.0

func setup(p_player: PlayerController, p_actions: Dictionary, p_content: ContentManager) -> void:
	player = p_player
	actions = p_actions
	content = p_content
	_add_starting_weapons()
	_load_sfx()
	_update_weapon_model()
	ammo_changed.emit(get_mag(), get_reserve())
	weapon_changed.emit(get_weapon().display_name if get_weapon() else "")

func _add_starting_weapons() -> void:
	var main = content.get_weapon("raid:blaster_a")
	if main:
		_add_weapon(main)
	var secondary = content.get_weapon("raid:blaster_c")
	if secondary:
		_add_weapon(secondary)
	var start = content.get_weapon("raid:blaster_a")
	if start:
		_add_weapon(start)

func _add_weapon(w: WeaponData) -> void:
	if w == null or weapons.has(w):
		return
	weapons.append(w)
	mags[w.id] = w.magazine_size
	if not reserves.has(w.ammo_type):
		reserves[w.ammo_type] = w.reserve_ammo

func add_weapon_override(w: WeaponData) -> void:
	if w == null:
		return
	if not weapons.has(w):
		weapons.append(w)
		mags[w.id] = w.magazine_size
	if not reserves.has(w.ammo_type):
		reserves[w.ammo_type] = w.reserve_ammo
	_update_weapon_model()
	weapon_changed.emit(w.display_name)
	ammo_changed.emit(get_mag(), get_reserve())

func add_ammo(ammo_type: String, amount: int) -> void:
	if ammo_type.is_empty() or amount <= 0:
		return
	reserves[ammo_type] = int(reserves.get(ammo_type, 0)) + amount
	ammo_changed.emit(get_mag(), get_reserve())

func get_weapon() -> WeaponData:
	if weapons.is_empty():
		return null
	return weapons[current_index]

func get_mag() -> int:
	var w := get_weapon()
	if w == null:
		return 0
	return int(mags.get(w.id, 0))

func get_reserve() -> int:
	var w := get_weapon()
	if w == null:
		return 0
	return int(reserves.get(w.ammo_type, 0))

func get_effective_stats(w: WeaponData) -> Dictionary:
	var damage := w.damage
	var fire_rate := w.fire_rate
	var magazine_size := w.magazine_size
	var reserve_ammo := w.reserve_ammo
	var reload_time := w.reload_time
	var spread := w.spread_degrees
	var range := w.range
	for slot in w.attachment_slots:
		var attach_id = installed.get(w.id, {}).get(slot, "")
		var attach: AttachmentData = content.get_attachment(attach_id) if attach_id != "" else null
		if attach == null:
			continue
		damage = (damage + attach.damage_add) * attach.damage_mult
		fire_rate = (fire_rate + attach.fire_rate_add) * attach.fire_rate_mult
		magazine_size += attach.magazine_add
		reserve_ammo += attach.reserve_add
		reload_time *= attach.reload_time_mult
		spread *= attach.spread_mult
		range *= attach.range_mult
	return {
		"damage": damage,
		"fire_rate": fire_rate,
		"magazine_size": magazine_size,
		"reserve_ammo": reserve_ammo,
		"reload_time": reload_time,
		"spread": spread,
		"range": range,
	}

func install_attachment(weapon_id: String, attachment_id: String) -> bool:
	var attach: AttachmentData = content.get_attachment(attachment_id)
	if attach == null:
		return false
	if weapon_id not in installed:
		installed[weapon_id] = {}
	if attach.slot in installed[weapon_id]:
		# 覆盖
		installed[weapon_id][attach.slot] = attachment_id
	else:
		installed[weapon_id][attach.slot] = attachment_id
	# 更新弹匣以反映扩容
	var w = _find_weapon(weapon_id)
	if w:
		var stats := get_effective_stats(w)
		mags[weapon_id] = min(int(mags.get(weapon_id, w.magazine_size)), int(stats["magazine_size"]))
	ammo_changed.emit(get_mag(), get_reserve())
	return true

func uninstall_attachment(weapon_id: String, slot: String) -> void:
	if weapon_id in installed and installed[weapon_id].has(slot):
		installed[weapon_id].erase(slot)

func _find_weapon(id: String) -> WeaponData:
	for w in weapons:
		if w.id == id:
			return w
	return null

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_handle_reload(delta)
	_handle_switch()
	_handle_fire()
	_handle_melee()
	_handle_use_item()
	_update_viewmodel(delta)

func _handle_fire() -> void:
	if _reloading:
		return
	var w := get_weapon()
	if w == null:
		return
	var fire_action: GUIDEAction = actions.get("fire")
	if fire_action == null or not fire_action.is_triggered():
		return
	if _cooldown > 0.0:
		return
	var mag := get_mag()
	if mag <= 0:
		start_reload()
		return
	var stats := get_effective_stats(w)
	_cooldown = 1.0 / maxf(stats["fire_rate"], 0.1)
	mags[w.id] = mag - 1
	_fire_hitscan(w, stats)
	ammo_changed.emit(get_mag(), get_reserve())
	fired.emit()
	_trigger_recoil()
	if get_mag() == 0:
		start_reload()

func _fire_hitscan(w: WeaponData, stats: Dictionary) -> void:
	var cam := player.camera
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var spread := float(stats["spread"]) * PI / 180.0
	if spread > 0.0:
		dir = dir.rotated(cam.global_transform.basis.x, randf_range(-spread, spread))
		dir = dir.rotated(cam.global_transform.basis.y, randf_range(-spread, spread))
		dir = dir.normalized()
	var to := from + dir * float(stats["range"])
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 32, [player])
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider = result.get("collider")
	if collider and collider.has_method("take_damage"):
		var died: bool = collider.take_damage(float(stats["damage"]) * damage_multiplier, player)
		hit_enemy.emit(float(stats["damage"]) * damage_multiplier, died)
		GameSfx.play(_hit_stream, randf_range(1.0, 1.3), -4.0)
	_show_hit_effect(result)

func _show_hit_effect(result: Dictionary) -> void:
	# 简单弹孔/命中闪点
	var decal := Node3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mesh.mesh = sphere
	decal.add_child(mesh)
	get_tree().current_scene.add_child(decal)
	decal.global_position = result.get("position", Vector3.ZERO)
	var tween := create_tween()
	tween.tween_property(decal, "scale", Vector3.ZERO, 0.18)
	tween.tween_callback(decal.queue_free)

func _handle_reload(delta: float) -> void:
	if _reloading:
		_reload_time_left -= delta
		if _reload_time_left <= 0.0:
			_finish_reload()
		return
	var reload_action: GUIDEAction = actions.get("reload")
	if reload_action and reload_action.is_triggered():
		start_reload()

func start_reload() -> void:
	var w := get_weapon()
	if w == null or _reloading:
		return
	var stats := get_effective_stats(w)
	var mag := get_mag()
	var reserve := get_reserve()
	if mag >= int(stats["magazine_size"]) or reserve <= 0:
		return
	_reloading = true
	_reload_time_left = float(stats["reload_time"]) * reload_time_multiplier
	GameSfx.play(_reload_start_stream, randf_range(0.9, 1.05), -4.0)

func _finish_reload() -> void:
	var w := get_weapon()
	if w == null:
		_reloading = false
		return
	var stats := get_effective_stats(w)
	var mag := get_mag()
	var reserve := get_reserve()
	var needed := int(stats["magazine_size"]) - mag
	var take := mini(needed, reserve)
	mags[w.id] = mag + take
	reserves[w.ammo_type] = reserve - take
	_reloading = false
	ammo_changed.emit(get_mag(), get_reserve())
	GameSfx.play(_reload_done_stream, randf_range(0.95, 1.1), -6.0)

func _handle_switch() -> void:
	if weapons.size() <= 1:
		return
	var next: GUIDEAction = actions.get("next_weapon")
	var prev: GUIDEAction = actions.get("prev_weapon")
	if next and next.is_triggered():
		current_index = (current_index + 1) % weapons.size()
		_on_weapon_switched()
	elif prev and prev.is_triggered():
		current_index = (current_index - 1 + weapons.size()) % weapons.size()
		_on_weapon_switched()

func _on_weapon_switched() -> void:
	_reloading = false
	_update_weapon_model()
	var w := get_weapon()
	weapon_changed.emit(w.display_name if w else "")
	ammo_changed.emit(get_mag(), get_reserve())

func _handle_melee() -> void:
	var melee_action: GUIDEAction = actions.get("melee")
	if melee_action == null or not melee_action.is_triggered():
		return
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 2.5
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 32, [player])
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var collider = result.get("collider")
		if collider and collider.has_method("take_damage"):
			collider.take_damage(25.0, player)

func _handle_use_item() -> void:
	var use_action: GUIDEAction = actions.get("use_item")
	if use_action == null or not use_action.is_triggered():
		return
	if player.inventory == null or player.survival == null:
		return
	# 优先医疗，再食物
	var health_id := player.inventory.find_first_health(content)
	if health_id != "":
		var item: ItemData = content.get_item(health_id)
		if item and player.inventory.remove_item(health_id, 1):
			player.heal(item.health_restore)
			player.eat(item.hunger_restore, 0.0)
			item_used.emit(item.display_name, "生命 +%d" % int(item.health_restore))
		return
	var food_id := player.inventory.find_first_food(content)
	if food_id != "":
		var item: ItemData = content.get_item(food_id)
		if item and player.inventory.remove_item(food_id, 1):
			player.eat(item.hunger_restore, item.health_restore)
			item_used.emit(item.display_name, "饱食 +%d" % int(item.hunger_restore))
		return
	no_usable_item.emit()

func _load_sfx() -> void:
	if ResourceLoader.exists(SHOT_SOUND_PATH):
		var res = load(SHOT_SOUND_PATH)
		if res is AudioStream:
			_shot_stream = res
	if ResourceLoader.exists(HIT_SOUND_PATH):
		var res = load(HIT_SOUND_PATH)
		if res is AudioStream:
			_hit_stream = res
	if ResourceLoader.exists(RELOAD_START_SOUND_PATH):
		var res = load(RELOAD_START_SOUND_PATH)
		if res is AudioStream:
			_reload_start_stream = res
	if ResourceLoader.exists(RELOAD_DONE_SOUND_PATH):
		var res = load(RELOAD_DONE_SOUND_PATH)
		if res is AudioStream:
			_reload_done_stream = res

func _update_weapon_model() -> void:
	if _viewmodel_rig:
		_viewmodel_rig.queue_free()
	_viewmodel_rig = null
	_viewmodel_model = null
	_muzzle_flash = null
	_muzzle_light = null
	_muzzle_timer = 0.0
	_recoil = 0.0
	var w := get_weapon()
	if w == null or w.model_path.is_empty():
		return
	var packed = load(w.model_path)
	if packed == null or not (packed is PackedScene):
		return
	var model: Node3D = packed.instantiate() as Node3D
	if model == null:
		return
	_viewmodel_rig = Node3D.new()
	_viewmodel_rig.name = "ViewmodelRig"
	player.camera.add_child(_viewmodel_rig)
	_viewmodel_rig.add_child(model)
	_viewmodel_model = model
	_fit_viewmodel(model)
	_build_muzzle_flash()

func _fit_viewmodel(model: Node3D) -> void:
	var aabb := _collect_viewmodel_aabb(model)
	if aabb.size.length_squared() <= 0.0001:
		return
	_viewmodel_size = aabb.size
	var max_dim := maxf(_viewmodel_size.x, maxf(_viewmodel_size.y, _viewmodel_size.z))
	_viewmodel_scale = VIEWMODEL_TARGET_LENGTH / max_dim
	var rot := Basis(Vector3.UP, deg_to_rad(VIEWMODEL_MODEL_YAW_DEG))
	var center := aabb.get_center()
	# 该 pack 的 blaster 枪口朝向 -Z，直接对齐相机 -Z（画面中央）
	model.position = -_viewmodel_scale * (rot * center)
	model.scale = Vector3.ONE * _viewmodel_scale
	model.rotation_degrees = Vector3(0.0, VIEWMODEL_MODEL_YAW_DEG, 0.0)

func _collect_viewmodel_aabb(root: Node3D) -> AABB:
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

func _build_muzzle_flash() -> void:
	if _viewmodel_rig == null:
		return
	_muzzle_pos = Vector3(0.0, 0.0, -_viewmodel_size.z * _viewmodel_scale * 0.5 - 0.02)
	_muzzle_flash = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.2)
	mat.emission_energy_multiplier = 3.0
	_muzzle_flash.mesh = sphere
	_muzzle_flash.position = _muzzle_pos
	_muzzle_flash.visible = false
	_viewmodel_rig.add_child(_muzzle_flash)
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.position = _muzzle_pos
	_muzzle_light.light_color = Color(1.0, 0.8, 0.3)
	_muzzle_light.omni_range = 1.8
	_muzzle_light.light_energy = 0.0
	_viewmodel_rig.add_child(_muzzle_light)

func _update_viewmodel(delta: float) -> void:
	if _viewmodel_rig == null:
		return
	_recoil = maxf(_recoil - RECOIL_RECOVER_SPEED * delta, 0.0)
	_muzzle_timer = maxf(_muzzle_timer - delta, 0.0)
	if _muzzle_timer <= 0.0:
		if _muzzle_flash:
			_muzzle_flash.visible = false
		if _muzzle_light:
			_muzzle_light.light_energy = 0.0
	var speed := player.velocity.length() if player else 0.0
	var speed_norm := clampf(speed / PlayerController.WALK_SPEED, 0.0, 1.2)
	if speed_norm > 0.05:
		_bob_time += delta * BOB_FREQ * (0.6 + speed_norm)
	var bob_x := sin(_bob_time * 2.0) * BOB_AMP_X * speed_norm
	var bob_y := -absf(sin(_bob_time * 4.0)) * BOB_AMP_Y * speed_norm
	var rec := _recoil * _recoil
	_viewmodel_rig.position = VIEWMODEL_BASE_POS + Vector3(bob_x, bob_y, RECOIL_PUSH * rec)
	_viewmodel_rig.rotation_degrees = VIEWMODEL_BASE_ROT_DEG + Vector3(RECOIL_KICK_DEG * rec, 0.0, -bob_x * 20.0)

func _trigger_recoil() -> void:
	GameSfx.play(_shot_stream, randf_range(0.95, 1.08), -6.0)
	_recoil = minf(_recoil + 1.0, 1.0)
	_muzzle_timer = MUZZLE_FLASH_TIME
	if _muzzle_flash:
		_muzzle_flash.visible = true
	if _muzzle_light:
		_muzzle_light.light_energy = 3.0
