class_name LootTableData
extends Resource
## 简单掉落表：entries 为 {item: String, weight: float, min: int, max: int}。

@export var id: String = ""
@export var entries: Array[Dictionary] = []

func roll() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var total_weight := 0.0
	for entry in entries:
		total_weight += float(entry.get("weight", 1.0))
	if total_weight <= 0.0:
		return result
	for entry in entries:
		var chance := float(entry.get("weight", 1.0)) / total_weight
		if randf() <= chance:
			var min_count: int = int(entry.get("min", 1))
			var max_count: int = int(entry.get("max", 1))
			if max_count < min_count:
				max_count = min_count
			result.append({
				"id": String(entry.get("item", "")),
				"count": randi_range(min_count, max_count),
			})
	return result
