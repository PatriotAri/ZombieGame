extends RefCounted
## What's in the containers when a new game starts. Never instanced: world/game_map.gd
## calls fill() once the map scene is loaded.
##
## Each container (items/loot_spot.gd) has fixed items, always in it, and a loot
## table, rolled fresh every new game. The tables are the files in items/loot/
## (LootTable; see HOW_TO_ADD.md): a list of rolls, each happening with its
## chance and adding one of its items (picked evenly), a random amount from its
## min to its max.

const LootSpot := preload("res://items/loot_spot.gd")
const DIR := "res://items/loot/"


## The table called table_name (its file's name), or null if there's none.
static func table(table_name: String) -> LootTable:
	var path := DIR + table_name + ".tres"
	return load(path) as LootTable if ResourceLoader.exists(path) else null


## Every table's name, for the container's Loot Table list.
static func table_names() -> PackedStringArray:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(DIR):
		file = file.trim_suffix(".remap") # exported games list "x.tres.remap"
		if file.ends_with(".tres"):
			names.append(file.get_basename())
	return names


## Every container's fixed items plus a roll on its table.
static func fill(spots: Array, rng: RandomNumberGenerator) -> void:
	var tables := {} # name -> LootTable, loaded once
	for spot: LootSpot in spots:
		for id: String in spot.fixed_items:
			if spot.fixed_items[id] > 0:
				spot.inventory.add(id, spot.fixed_items[id])
		if spot.loot_table == "none" or spot.loot_table == "":
			continue
		if not tables.has(spot.loot_table):
			tables[spot.loot_table] = table(spot.loot_table)
			if tables[spot.loot_table] == null:
				push_warning("%s: no loot table called \"%s\" (items/loot/)" % [spot.name, spot.loot_table])
		var loot: LootTable = tables[spot.loot_table]
		if loot == null:
			continue
		for roll: LootRoll in loot.rolls:
			if roll.items.is_empty() or rng.randf() >= roll.chance:
				continue
			var pick: LootPick = roll.items[rng.randi_range(0, roll.items.size() - 1)]
			spot.inventory.add(pick.item, rng.randi_range(pick.min_amount, maxi(pick.max_amount, pick.min_amount)))
