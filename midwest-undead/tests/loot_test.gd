extends SceneTree
## Loot tables (items/loot/): every item a table can roll is a real item, with
## amounts that make sense; the same seed fills a container the same way; a
## container's fixed items are always in it; "none" adds nothing else.
const Loot := preload("res://world/loot.gd")
const LootSpot := preload("res://items/loot_spot.gd")
const GameData := preload("res://core/game_data.gd")
var f := 0
var fails := 0

func check(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func roll(table_name: String, seed_value: int, fixed := {}) -> Dictionary:
	var spot := LootSpot.new()
	spot.loot_table = table_name
	for id in fixed:
		spot.fixed_items[id] = fixed[id]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	Loot.fill([spot], rng)
	var got: Dictionary = spot.inventory.to_dict()
	spot.free()
	return got

func _process(_d: float) -> bool:
	f += 1
	if f < 3:
		return false
	var names := Loot.table_names()
	check(names.size() >= 3 and not "none" in names, "tables: %s (\"none\" is no table: just the fixed items)" % [names])
	for table_name in names:
		var table := Loot.table(table_name)
		var bad := []
		for r: LootRoll in table.rolls:
			if r.chance < 0.0 or r.chance > 1.0:
				bad.append("chance %.2f" % r.chance)
			for pick: LootPick in r.items:
				if not GameData.has_item(pick.item):
					bad.append("unknown item \"%s\"" % pick.item)
				if pick.min_amount < 1 or pick.max_amount < pick.min_amount:
					bad.append("%s: %d-%d" % [pick.item, pick.min_amount, pick.max_amount])
		check(bad.is_empty(), "%s: every roll is a real item, sensible amounts %s" % [table_name, bad if not bad.is_empty() else ""])
		var same := true
		for s in 50:
			if roll(table_name, s) != roll(table_name, s):
				same = false
		check(same, "%s: the same seed fills it the same way" % table_name)
	var fixed := roll("none", 7, {"planks": 3})
	check(fixed == {"planks": 3}, "\"none\": just its fixed items %s" % [fixed])
	var with_fixed := roll(names[0], 7, {"planks": 3})
	check(int(with_fixed.get("planks", 0)) >= 3, "a table's container keeps its fixed items too %s" % [with_fixed])
	print("FAILS: %d" % fails)
	return true
