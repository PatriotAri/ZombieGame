extends RefCounted
## What the woodworker and the machinist can make, and from what. Crafting is
## instant: bring the materials, pick the piece (ui/craft_menu.gd). Never instanced.
## "planks" in a recipe takes used planks too (those go first: they're worth less).

const WOODWORKER := [
	{"id": "scaffold", "needs": {"planks": 4}},
	{"id": "guard_post", "needs": {"planks": 4, "plywood": 2}},
	{"id": "fence", "needs": {"planks": 3, "plywood": 1}},
	{"id": "fence_gate", "needs": {"planks": 3, "plywood": 1, "scrap_metal": 1}},
	{"id": "garden_plot", "needs": {"planks": 4}},
	# A new base camp (world/camps.gd): tents, a table and the radio (the batteries).
	{"id": "camp_kit", "needs": {"planks": 12, "plywood": 6, "scrap_metal": 6, "batteries": 2}},
]
## The machinist makes these any time.
const MACHINIST_ANYTIME := [
	{"id": "sheet_metal", "needs": {"scrap_metal": 10}},
]
## The machinist needs the woodworker at the station to make these (for the frames).
const MACHINIST := [
	{"id": "ammo_bench", "needs": {"planks": 2, "plywood": 2, "scrap_metal": 4}},
	{"id": "shell_bench", "needs": {"planks": 2, "plywood": 2, "scrap_metal": 6}},
	{"id": "rifle_bench", "needs": {"planks": 2, "plywood": 3, "scrap_metal": 8}},
]


## How many of a recipe ingredient you have ("planks" counts used planks too).
static func have(inventory: RefCounted, item: String) -> int:
	if item == "planks":
		return inventory.call("count", "planks") + inventory.call("count", "used_planks")
	return inventory.call("count", item)


static func can_make(inventory: RefCounted, recipe: Dictionary) -> bool:
	var needs: Dictionary = recipe["needs"]
	for item: String in needs:
		if have(inventory, item) < int(needs[item]):
			return false
	return true


## Takes the materials out of the inventory (check can_make first).
static func take(inventory: RefCounted, recipe: Dictionary) -> void:
	var needs: Dictionary = recipe["needs"]
	for item: String in needs:
		var left := int(needs[item])
		if item == "planks":
			left -= int(inventory.call("remove", "used_planks", left))
		inventory.call("remove", item, left)
