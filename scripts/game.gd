class_name GameRoot
extends Node3D
## 主入口：负责全局状态、菜单/整备、局流程、音乐与元进度。

enum State { MENU, PLAYING, PAUSED, GUNSMITH, UPGRADE, RESULT }

var content: ContentManager
var inputs: GuideInputManager
var raid: RaidManager
var ui: GameUI
var music: MusicManager
var meta: MetaProgress

var state := State.MENU
var selected_weapon_id := ""
var pending_upgrades: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	content = ContentManager.new()
	add_child(content)
	content.load_all()

	inputs = GuideInputManager.new()
	add_child(inputs)

	raid = RaidManager.new()
	add_child(raid)
	raid.setup(content, inputs)

	ui = GameUI.new()
	add_child(ui)
	ui.start_pressed.connect(_start_raid)
	ui.gunsmith_pressed.connect(_open_gunsmith)
	ui.resume_pressed.connect(_resume)
	ui.back_to_menu_pressed.connect(_to_menu)
	ui.weapon_selected.connect(_on_weapon_selected)
	ui.attachment_selected.connect(_on_attachment_selected)

	music = MusicManager.new()
	add_child(music)

	meta = MetaProgress.load()
	raid.raid_extracted.connect(_on_raid_extracted)
	raid.raid_failed.connect(_on_raid_failed)
	raid.upgrade_offered.connect(_on_upgrade_offered)
	raid.item_picked.connect(_on_item_picked)
	ui.upgrade_chosen.connect(_on_upgrade_chosen)
	ui.upgrade_purchase_requested.connect(_on_upgrade_purchase_requested)

	_to_menu()
	if OS.get_environment("FPS_ROGUE_SMOKE") == "1":
		call_deferred("_smoke_auto_start")

func _smoke_auto_start() -> void:
	print("SMOKE CONTENT weapons=%d items=%d enemies=%d tables=%d upgrades=%d" % [
		content.weapons.size(), content.items.size(), content.enemies.size(), content.loot_tables.size(), content.upgrades.size()])
	_open_gunsmith()
	await get_tree().create_timer(0.3).timeout
	_to_menu()
	_start_raid()
	await get_tree().create_timer(2.0).timeout
	if raid.player == null:
		return
	print("SMOKE PLAYER Y=%.2f" % raid.player.global_position.y)
	# 冒烟：直接触发常见运行时路径
	raid.player.take_damage(5.0)
	raid.player.inventory.add_item("raid:apple", 1)
	raid.player.weapon_controller.add_ammo("cell", 10)
	raid.player.weapon_controller.start_reload()
	if raid.container_root:
		for child in raid.container_root.get_children():
			if child is LootContainer:
				child.open(raid.player, raid.spawn_loot_at)
				break
	raid._offer_upgrade()
	await get_tree().create_timer(0.5).timeout
	_on_upgrade_chosen(0)
	print("SMOKE RAID OK")

func _process(_delta: float) -> void:
	if state == State.PLAYING:
		var pause_action: GUIDEAction = inputs.get_action("pause")
		if pause_action and pause_action.is_triggered():
			_pause()
		if raid.player:
			var valuable := raid.player.inventory.get_total_value(content) if raid.player.inventory else 0
			ui.update_hud(raid.player, valuable, raid.get_extraction_progress(),
				_build_inventory_summary(), raid.get_interaction_hint())
	elif state == State.PAUSED:
		var pause_action: GUIDEAction = inputs.get_action("pause")
		if pause_action and pause_action.is_triggered():
			_resume()

## 背包摘要（食物/医疗优先），供 HUD 显示物品与可用性。
func _build_inventory_summary() -> String:
	if raid.player == null or raid.player.inventory == null:
		return ""
	var parts: Array[String] = []
	var others: Array[String] = []
	for item_id in raid.player.inventory.items.keys():
		var item: ItemData = content.get_item(String(item_id))
		if item == null:
			continue
		var count := int(raid.player.inventory.items[item_id])
		var text := "%s×%d" % [item.display_name, count]
		if item.category == "food" or item.category == "health":
			parts.append(text)
		else:
			others.append(text)
	parts.append_array(others)
	if parts.is_empty():
		return ""
	return "背包：%s  (F 使用食物/医疗)" % " ".join(parts)

func _on_item_picked(display_name: String, count: int) -> void:
	ui.show_toast("获得 %s ×%d" % [display_name, count])

func _on_item_used(display_name: String, detail: String) -> void:
	ui.show_toast("使用 %s：%s" % [display_name, detail])

func _to_menu() -> void:
	state = State.MENU
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if raid:
		raid.clear_raid()
	inputs.disable_gameplay()
	ui.show_menu_ui()
	ui.set_menu_credits(meta.credits, meta.research)
	music.play_menu()

func _start_raid() -> void:
	var weapon_list: Array[WeaponData] = []
	for weapon_id in meta.owned_weapons:
		var w: WeaponData = content.get_weapon(String(weapon_id))
		if w:
			weapon_list.append(w)
	if weapon_list.is_empty():
		var fallback: WeaponData = content.get_weapon("raid:blaster_a")
		if fallback:
			weapon_list.append(fallback)

	var speed_mult := 1.0
	var max_health := 100.0
	var ammo_mult := 1.0
	for upgrade_id in meta.upgrade_levels.keys():
		var up: UpgradeData = content.get_upgrade(String(upgrade_id))
		if up == null:
			continue
		var level := meta.get_upgrade_level(String(upgrade_id))
		for effect in up.effects.keys():
			var value = float(up.effects[effect])
			match String(effect):
				"max_health":
					max_health += value * level
				"move_speed":
					speed_mult += value * level
				"ammo_capacity":
					ammo_mult += value * level

	# 弹药上限倍率简单应用在初始 reserve 上
	raid.start_raid(randi(), weapon_list, speed_mult, max_health, meta.installed_attachments)
	if raid.player and raid.player.weapon_controller:
		for ammo_type in raid.player.weapon_controller.reserves.keys():
			raid.player.weapon_controller.reserves[ammo_type] = int(float(raid.player.weapon_controller.reserves[ammo_type]) * ammo_mult)

	state = State.PLAYING
	ui.show_hud_ui()
	inputs.enable_gameplay()
	music.play_game()
	if raid.player and raid.player.weapon_controller:
		raid.player.weapon_controller.item_used.connect(_on_item_used)
		raid.player.weapon_controller.no_usable_item.connect(func() -> void:
			ui.show_toast("没有可用的食物/医疗品"))

func _pause() -> void:
	state = State.PAUSED
	get_tree().paused = true
	ui.show_pause_ui()
	if raid.player:
		raid.player.set_controls_enabled(false)

func _resume() -> void:
	state = State.PLAYING
	get_tree().paused = false
	ui.show_hud_ui()
	if raid.player:
		raid.player.set_controls_enabled(true)

func _open_gunsmith() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var weapon_list: Array[WeaponData] = []
	for weapon_id in meta.owned_weapons:
		var w: WeaponData = content.get_weapon(String(weapon_id))
		if w:
			weapon_list.append(w)
	if weapon_list.is_empty():
		return
	var upgrade_list: Array[UpgradeData] = []
	for up in content.upgrades.values():
		if up is UpgradeData:
			upgrade_list.append(up)
	selected_weapon_id = weapon_list[0].id
	state = State.GUNSMITH
	inputs.disable_gameplay()
	ui.open_gunsmith(weapon_list, meta.owned_attachments, meta.installed_attachments, content, upgrade_list, meta.upgrade_levels)

func _on_weapon_selected(weapon_id: String) -> void:
	selected_weapon_id = weapon_id

func _on_attachment_selected(attachment_id: String) -> void:
	if selected_weapon_id.is_empty():
		return
	var att: AttachmentData = content.get_attachment(attachment_id)
	if att == null or not meta.has_attachment(attachment_id):
		return
	meta.set_installed_attachment(selected_weapon_id, att.slot, attachment_id)
	# 刷新整备界面
	_open_gunsmith()

func _on_upgrade_offered(choices: Array[Dictionary]) -> void:
	pending_upgrades = choices
	state = State.UPGRADE
	if raid.player:
		raid.player.set_controls_enabled(false)
	ui.show_upgrade_choices(choices)

func _on_upgrade_chosen(index: int) -> void:
	if state != State.UPGRADE or index < 0 or index >= pending_upgrades.size():
		return
	var choice: Dictionary = pending_upgrades[index]
	_apply_upgrade(choice)
	pending_upgrades.clear()
	state = State.PLAYING
	ui.hide_upgrade_ui()
	ui.show_hud_ui()
	if raid.player:
		raid.player.set_controls_enabled(true)

func _apply_upgrade(choice: Dictionary) -> void:
	if raid.player == null:
		return
	var kind := String(choice.get("kind", ""))
	var value := float(choice.get("value", 0.0))
	match kind:
		"weapon_damage":
			raid.player.weapon_controller.damage_multiplier += value
		"reload_speed":
			raid.player.weapon_controller.reload_time_multiplier *= maxf(1.0 - value, 0.5)
		"move_speed":
			raid.player.move_speed_multiplier += value
		"max_health":
			raid.player.max_health += value
			raid.player.health = minf(raid.player.health + value, raid.player.max_health)
			raid.player.health_changed.emit(raid.player.health, raid.player.max_health)
		"loot":
			var ids := ["raid:apple", "raid:ammo_cell", "raid:bread", "raid:coin"]
			var drops: Array[Dictionary] = []
			for i in int(value):
				drops.append({"id": ids[randi_range(0, ids.size() - 1)], "count": 1})
			raid.spawn_loot_at(raid.player.global_position, drops)

func _on_upgrade_purchase_requested(upgrade_id: String) -> void:
	var up: UpgradeData = content.get_upgrade(upgrade_id)
	if up == null:
		return
	if meta.buy_upgrade(up):
		ui.set_menu_credits(meta.credits, meta.research)
		_open_gunsmith()

func _on_raid_extracted(valuable: int) -> void:
	if raid.player and raid.player.inventory:
		for item_id in raid.player.inventory.all_item_ids():
			var item: ItemData = content.get_item(item_id)
			if item and item.category == "attachment":
				meta.add_attachment(item_id)
	meta.add_credits(valuable)
	var research_gain := maxi(1, int(valuable * 0.5))
	meta.add_research(research_gain)
	meta.save()
	state = State.RESULT
	inputs.disable_gameplay()
	music.stop()
	ui.show_result_ui("撤离成功！", "战利品价值：%d\n信用点：+%d\n研究数据：+%d\n\n活着回来，就是赚。" % [valuable, valuable, research_gain])
	ui.set_menu_credits(meta.credits, meta.research)

func _on_raid_failed() -> void:
	meta.add_research(5)
	meta.save()
	state = State.RESULT
	inputs.disable_gameplay()
	music.stop()
	ui.show_result_ui("行动失败", "你倒在了废墟中……\n随身战利品已丢失，仅保留研究数据 +5。")
	ui.set_menu_credits(meta.credits, meta.research)
