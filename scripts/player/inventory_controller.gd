class_name InventoryController
extends Node

signal changed

var items: Dictionary = {}  # item_id -> count
var attachments: Array[String] = []  # 持有的配件 id

func add_item(item_id: String, count: int = 1) -> void:
	if count <= 0:
		return
	items[item_id] = int(items.get(item_id, 0)) + count
	changed.emit()

func remove_item(item_id: String, count: int = 1) -> bool:
	var current := int(items.get(item_id, 0))
	if current < count:
		return false
	if current - count <= 0:
		items.erase(item_id)
	else:
		items[item_id] = current - count
	changed.emit()
	return true

func get_count(item_id: String) -> int:
	return int(items.get(item_id, 0))

func has_item(item_id: String) -> bool:
	return get_count(item_id) > 0

func add_attachment(attachment_id: String) -> void:
	if attachment_id not in attachments:
		attachments.append(attachment_id)
	changed.emit()

func remove_attachment(attachment_id: String) -> bool:
	var idx := attachments.find(attachment_id)
	if idx < 0:
		return false
	attachments.remove_at(idx)
	changed.emit()
	return true

func get_total_value(content: ContentManager) -> int:
	var total := 0
	for item_id in items.keys():
		var item: ItemData = content.get_item(String(item_id))
		if item:
			total += int(item.value) * int(items[item_id])
	return total

func find_first_food(content: ContentManager) -> String:
	for item_id in items.keys():
		var item: ItemData = content.get_item(String(item_id))
		if item and item.is_food():
			return String(item_id)
	return ""

func find_first_health(content: ContentManager) -> String:
	for item_id in items.keys():
		var item: ItemData = content.get_item(String(item_id))
		if item and item.is_health():
			return String(item_id)
	return ""

func all_item_ids() -> Array[String]:
	var result: Array[String] = []
	for key in items.keys():
		result.append(String(key))
	return result
