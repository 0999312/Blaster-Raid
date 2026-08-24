class_name MetaProgress
extends RefCounted
## 局外元进度：信用点、研究数据、永久强化等级、已拥有配件/武器。

const SAVE_PATH := "user://fps_rogue_meta.cfg"

var credits := 0
var research := 0
var upgrade_levels: Dictionary = {}  # upgrade_id -> level
var owned_attachments: Array[String] = []
var owned_weapons: Array[String] = ["raid:blaster_a", "raid:blaster_c"]
var installed_attachments: Dictionary = {}  # weapon_id -> {slot: attachment_id}

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "credits", credits)
	cfg.set_value("meta", "research", research)
	cfg.set_value("meta", "upgrade_levels", upgrade_levels)
	cfg.set_value("meta", "owned_attachments", owned_attachments)
	cfg.set_value("meta", "owned_weapons", owned_weapons)
	cfg.set_value("meta", "installed_attachments", installed_attachments)
	cfg.save(SAVE_PATH)

static func load() -> MetaProgress:
	var p := MetaProgress.new()
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return p
	p.credits = int(cfg.get_value("meta", "credits", 0))
	p.research = int(cfg.get_value("meta", "research", 0))
	p.upgrade_levels = cfg.get_value("meta", "upgrade_levels", {})
	var atts = cfg.get_value("meta", "owned_attachments", [])
	if atts is Array:
		p.owned_attachments = atts.duplicate()
	var guns = cfg.get_value("meta", "owned_weapons", ["raid:blaster_a", "raid:blaster_c"])
	if guns is Array:
		p.owned_weapons = guns.duplicate()
	var installed = cfg.get_value("meta", "installed_attachments", {})
	if installed is Dictionary:
		p.installed_attachments = installed.duplicate(true)
	return p

func get_upgrade_level(id: String) -> int:
	return int(upgrade_levels.get(id, 0))

func can_buy(upgrade: UpgradeData) -> bool:
	var level := get_upgrade_level(upgrade.id)
	if level >= upgrade.max_level:
		return false
	return credits >= get_upgrade_cost(upgrade)

func get_upgrade_cost(upgrade: UpgradeData) -> int:
	var level := get_upgrade_level(upgrade.id)
	return int(upgrade.cost_base * (level + 1))

func buy_upgrade(upgrade: UpgradeData) -> bool:
	if not can_buy(upgrade):
		return false
	credits -= get_upgrade_cost(upgrade)
	upgrade_levels[upgrade.id] = get_upgrade_level(upgrade.id) + 1
	save()
	return true

func add_credits(amount: int) -> void:
	credits += amount
	save()

func add_research(amount: int) -> void:
	research += amount
	save()

func add_attachment(id: String) -> void:
	if id not in owned_attachments:
		owned_attachments.append(id)
		save()

func has_attachment(id: String) -> bool:
	return id in owned_attachments

func set_installed_attachment(weapon_id: String, slot: String, attachment_id: String) -> void:
	if weapon_id not in installed_attachments:
		installed_attachments[weapon_id] = {}
	installed_attachments[weapon_id][slot] = attachment_id
	save()

func get_installed_attachments(weapon_id: String) -> Dictionary:
	return installed_attachments.get(weapon_id, {})
