extends RefCounted
## What's in the containers when a new game starts. Never instanced: main.gd
## calls fill() once the town scene is loaded.
##
## Each container (items/loot_spot.gd) has fixed items, always in it, and a loot
## table, rolled fresh every new game. A table is a list of rolls; each roll
## happens with its chance and adds one of its items (picked evenly), a random
## amount between the two numbers. To change what a kind of container tends to
## hold, edit its table here; to add a table, add it here and to loot_spot.gd's
## loot_table list.

const LootSpot := preload("res://items/loot_spot.gd")

## Shelves, counters, cabinets, dressers, dumpsters, boxes.
const STANDARD := [
	{"chance": 0.4, "items": [["health_pack", 1, 1]]},
	{"chance": 0.35, "items": [["pistol_ammo", 3, 7]]},
	{"chance": 0.35, "items": [["canned_food", 1, 2], ["batteries", 1, 3]]},
	{"chance": 0.15, "items": [["planks", 1, 2]]},
	{"chance": 0.12, "items": [["plywood", 1, 2]]},
	{"chance": 0.1, "items": [["scrap_metal", 1, 2]]},
]
const TABLES := {
	"none": [],
	"standard": STANDARD,
	## Wrecked cars: more scrap metal.
	"car": [
		{"chance": 0.4, "items": [["health_pack", 1, 1]]},
		{"chance": 0.35, "items": [["pistol_ammo", 3, 7]]},
		{"chance": 0.35, "items": [["canned_food", 1, 2], ["batteries", 1, 3]]},
		{"chance": 0.15, "items": [["planks", 1, 2]]},
		{"chance": 0.12, "items": [["plywood", 1, 2]]},
		{"chance": 0.35, "items": [["scrap_metal", 1, 2]]},
	],
	## The grocery's shelves: food on top of the usual.
	"grocery": [
		{"chance": 1.0, "items": [["canned_food", 1, 2]]},
		{"chance": 0.4, "items": [["health_pack", 1, 1]]},
		{"chance": 0.35, "items": [["pistol_ammo", 3, 7]]},
		{"chance": 0.35, "items": [["canned_food", 1, 2], ["batteries", 1, 3]]},
		{"chance": 0.15, "items": [["planks", 1, 2]]},
		{"chance": 0.12, "items": [["plywood", 1, 2]]},
		{"chance": 0.1, "items": [["scrap_metal", 1, 2]]},
	],
	## The gas station's snack shelf: maybe some food on top of the usual.
	"snack": [
		{"chance": 0.6, "items": [["canned_food", 1, 2]]},
		{"chance": 0.4, "items": [["health_pack", 1, 1]]},
		{"chance": 0.35, "items": [["pistol_ammo", 3, 7]]},
		{"chance": 0.35, "items": [["canned_food", 1, 2], ["batteries", 1, 3]]},
		{"chance": 0.15, "items": [["planks", 1, 2]]},
		{"chance": 0.12, "items": [["plywood", 1, 2]]},
		{"chance": 0.1, "items": [["scrap_metal", 1, 2]]},
	],
}


## Every container's fixed items plus a roll on its table.
static func fill(spots: Array, rng: RandomNumberGenerator) -> void:
	for spot: LootSpot in spots:
		for id: String in spot.fixed_items:
			if spot.fixed_items[id] > 0:
				spot.inventory.add(id, spot.fixed_items[id])
		if not TABLES.has(spot.loot_table):
			push_warning("%s: no loot table called \"%s\" (world/loot.gd)" % [spot.name, spot.loot_table])
			continue
		for roll: Dictionary in TABLES[spot.loot_table]:
			if rng.randf() >= float(roll["chance"]):
				continue
			var options: Array = roll["items"]
			var pick: Array = options[rng.randi_range(0, options.size() - 1)]
			spot.inventory.add(pick[0], rng.randi_range(pick[1], pick[2]))
