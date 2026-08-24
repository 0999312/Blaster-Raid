class_name ContentManager
extends Node
## 启动时加载 JSON 内容，并注册到 mc_game_framework 的 RegistryManager。

const WEAPONS_PATH := "res://resources/content/weapons.json"
const ATTACHMENTS_PATH := "res://resources/content/attachments.json"
const ITEMS_PATH := "res://resources/content/items.json"
const ENEMIES_PATH := "res://resources/content/enemies.json"
const LOOT_TABLES_PATH := "res://resources/content/loot_tables.json"
const UPGRADES_PATH := "res://resources/content/upgrades.json"

var weapons: Dictionary = {}
var attachments: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}
var loot_tables: Dictionary = {}
var upgrades: Dictionary = {}

var _loaded := false

func _ready() -> void:
	load_all()

func is_loaded() -> bool:
	return _loaded

func load_all() -> void:
	if _loaded:
		return
	_register_registries()
	_load_weapons()
	_load_attachments()
	_load_items()
	_load_enemies()
	_load_loot_tables()
	_load_upgrades()
	_loaded = true

func get_weapon(id: String) -> WeaponData:
	return weapons.get(id, null)

func get_attachment(id: String) -> AttachmentData:
	return attachments.get(id, null)

func get_item(id: String) -> ItemData:
	return items.get(id, null)

func get_enemy(id: String) -> EnemyData:
	return enemies.get(id, null)

func get_loot_table(id: String) -> LootTableData:
	return loot_tables.get(id, null)

func get_upgrade(id: String) -> UpgradeData:
	return upgrades.get(id, null)

func _register_registries() -> void:
	_ensure_registry("weapon")
	_ensure_registry("attachment")
	_ensure_registry("item")
	_ensure_registry("enemy")
	_ensure_registry("loot_table")
	_ensure_registry("upgrade")

func _ensure_registry(type_name: String) -> void:
	if not RegistryManager.has_registry(type_name):
		RegistryManager.register_registry(type_name, RegistryBase.new())

func _load_weapons() -> void:
	var arr = _read_json_array(WEAPONS_PATH)
	var registry = RegistryManager.get_registry("weapon")
	for data in arr:
		var w := WeaponData.new()
		_apply_dict(w, data)
		_parse_exports_from_dict(w, data)
		weapons[w.id] = w
		if registry and ResourceLocation.is_valid(w.id):
			registry.register(ResourceLocation.from_string(w.id), w)

func _load_attachments() -> void:
	var arr = _read_json_array(ATTACHMENTS_PATH)
	var registry = RegistryManager.get_registry("attachment")
	for data in arr:
		var a := AttachmentData.new()
		_apply_dict(a, data)
		_parse_exports_from_dict(a, data)
		attachments[a.id] = a
		if registry and ResourceLocation.is_valid(a.id):
			registry.register(ResourceLocation.from_string(a.id), a)

func _load_items() -> void:
	var arr = _read_json_array(ITEMS_PATH)
	var registry = RegistryManager.get_registry("item")
	for data in arr:
		var it := ItemData.new()
		_apply_dict(it, data)
		_parse_exports_from_dict(it, data)
		items[it.id] = it
		if registry and ResourceLocation.is_valid(it.id):
			registry.register(ResourceLocation.from_string(it.id), it)

func _load_enemies() -> void:
	var arr = _read_json_array(ENEMIES_PATH)
	var registry = RegistryManager.get_registry("enemy")
	for data in arr:
		var e := EnemyData.new()
		# Vector3 字段先于 _apply_dict 解析（避免把 JSON 数组直接 set 给 Vector3 属性）
		if data.has("weapon_grip_offset") and data["weapon_grip_offset"] is Array:
			var off: Array = data["weapon_grip_offset"]
			if off.size() >= 3:
				e.weapon_grip_offset = Vector3(float(off[0]), float(off[1]), float(off[2]))
			data.erase("weapon_grip_offset")
		_apply_dict(e, data)
		_parse_exports_from_dict(e, data)
		if data.has("color") and data["color"] is String:
			e.color = Color.html(String(data["color"]))
		enemies[e.id] = e
		if registry and ResourceLocation.is_valid(e.id):
			registry.register(ResourceLocation.from_string(e.id), e)

func _load_loot_tables() -> void:
	var arr = _read_json_array(LOOT_TABLES_PATH)
	var registry = RegistryManager.get_registry("loot_table")
	for data in arr:
		var t := LootTableData.new()
		_apply_dict(t, data)
		if data.has("entries") and data["entries"] is Array:
			t.entries = []
			for entry in data["entries"]:
				t.entries.append(entry.duplicate())
		loot_tables[t.id] = t
		if registry and ResourceLocation.is_valid(t.id):
			registry.register(ResourceLocation.from_string(t.id), t)

func _load_upgrades() -> void:
	var arr = _read_json_array(UPGRADES_PATH)
	var registry = RegistryManager.get_registry("upgrade")
	for data in arr:
		var u := UpgradeData.new()
		_apply_dict(u, data)
		_parse_exports_from_dict(u, data)
		upgrades[u.id] = u
		if registry and ResourceLocation.is_valid(u.id):
			registry.register(ResourceLocation.from_string(u.id), u)

func _apply_dict(obj: Object, data: Dictionary) -> void:
	for key in data:
		if key in obj and key != "color":
			var prop = data[key]
			if prop is Array and obj.get(key) is Array:
				obj.set(key, prop.duplicate())
			else:
				obj.set(key, prop)

func _parse_exports_from_dict(obj: Resource, data: Dictionary) -> void:
	# 资源中未显式声明的额外 JSON 字段已由 _apply_dict 直接塞入；这里保留入口。
	pass

func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("ContentManager missing JSON: " + path)
		return []
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	push_warning("ContentManager JSON must contain array: " + path)
	return []
