extends RefCounted
## A bag of item counts, e.g. {"pistol_ammo": 12, "health_pack": 1}.
## The player and every searchable container each own one.

const GameData := preload("res://core/game_data.gd")

var _counts := {}


func count(id: String) -> int:
	return _counts.get(id, 0)


func has(id: String) -> bool:
	return count(id) > 0


func is_empty() -> bool:
	return _counts.is_empty()


func add(id: String, amount := 1) -> void:
	if amount > 0:
		_counts[id] = count(id) + amount


## Removes up to amount; returns how many were actually removed.
func remove(id: String, amount := 1) -> int:
	var taken := mini(amount, count(id))
	if taken <= 0:
		return 0
	var left := count(id) - taken
	if left == 0:
		_counts.erase(id)
	else:
		_counts[id] = left
	return taken


## A plain copy of the contents, e.g. {"pistol_ammo": 12}, for save files.
func to_dict() -> Dictionary:
	return _counts.duplicate()


## Replace the contents with a saved copy. Unknown item ids are skipped.
func from_dict(data: Dictionary) -> void:
	_counts.clear()
	for id in data:
		if GameData.ITEMS.has(id):
			add(id, int(data[id]))


## Item ids currently held, in display order.
func ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in GameData.ITEM_ORDER:
		if has(id):
			result.append(id)
	return result
