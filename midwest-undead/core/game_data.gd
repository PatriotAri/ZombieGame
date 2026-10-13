extends RefCounted
## Shared constants used by several scripts: physics layers and item definitions.
## Never instanced; other scripts preload it and read the constants.

# Collision layers are bit flags (1, 2, 4, 8...). Rays and bodies pick which
# layers they care about, e.g. zombie sight ignores other zombies.
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ZOMBIES := 4
const LAYER_ITEMS := 8
const LAYER_GLASS := 16 # windows: block bodies, but sight and bullets pass through
const LAYER_NPC := 32 # human NPCs (guards, traders, bandits...)
## Doorways and windows you can board up: invisible areas only the planks aim at.
const LAYER_OPENINGS := 64
## Seen only by the navigation bake, never by physics: stand-ins like the shut
## compound gate (see world/areas/police_station.gd).
const LAYER_NAV_ONLY := 128

# "use" is what the use button does while you hold the item. Items without one
# (ammo, batteries) can't be held; they just sit in your inventory.
const ITEMS := {
	"pistol": {"name": "Pistol", "color": Color(0.12, 0.12, 0.14), "size": Vector3(0.18, 0.1, 0.28), "use": "shoot"},
	"crowbar": {"name": "Crowbar", "color": Color(0.45, 0.12, 0.1), "size": Vector3(0.05, 0.05, 0.75), "use": "melee"},
	"pistol_ammo": {"name": "Pistol ammo", "color": Color(0.75, 0.6, 0.2), "size": Vector3(0.16, 0.1, 0.1)},
	"health_pack": {"name": "Health pack", "color": Color(0.9, 0.9, 0.88), "size": Vector3(0.32, 0.12, 0.24), "use": "heal"},
	# Food is eaten from your hands and staves off hunger. Batteries can't be held:
	# the flashlight swaps a set in by itself when its charge runs out.
	"canned_food": {"name": "Canned food", "color": Color(0.7, 0.25, 0.15), "size": Vector3(0.1, 0.14, 0.1), "use": "eat"},
	"batteries": {"name": "Batteries", "color": Color(0.2, 0.45, 0.25), "size": Vector3(0.12, 0.06, 0.08)},
	# Fortifying (see world/fortifications.gd). Hold one, aim, and use it to place it.
	"planks": {"name": "Planks", "color": Color(0.6, 0.47, 0.3), "size": Vector3(0.5, 0.06, 0.18), "use": "board"},
	# What planks become once they've been nailed up and pulled down again. They
	# board things up just the same, but they don't survive coming down twice.
	"used_planks": {"name": "Used planks", "color": Color(0.45, 0.38, 0.3), "size": Vector3(0.5, 0.06, 0.18), "use": "board"},
	"barricade": {"name": "Barricade", "color": Color(0.5, 0.38, 0.24), "size": Vector3(0.6, 0.35, 0.12), "use": "barricade"},
	# Building (see world/structures.gd), from the woodworker. Hold one and use it
	# while looking at the ground (or at scaffolding / a fence to add on).
	"scaffold": {"name": "Scaffolding", "color": Color(0.42, 0.43, 0.45), "size": Vector3(0.3, 0.06, 0.3), "use": "build"},
	"guard_post": {"name": "Guard post", "color": Color(0.4, 0.3, 0.19), "size": Vector3(0.22, 0.16, 0.22), "use": "build"},
	"fence": {"name": "Fence", "color": Color(0.55, 0.45, 0.3), "size": Vector3(0.34, 0.22, 0.04), "use": "build"},
	"fence_gate": {"name": "Fence gate", "color": Color(0.58, 0.45, 0.28), "size": Vector3(0.3, 0.22, 0.05), "use": "build"},
	"garden_plot": {"name": "Garden plot", "color": Color(0.35, 0.5, 0.25), "size": Vector3(0.3, 0.1, 0.22), "use": "build"},
	"ammo_bench": {"name": "Ammo bench", "color": Color(0.38, 0.36, 0.34), "size": Vector3(0.3, 0.16, 0.18), "use": "build"},
	# Materials the woodworker and machinist build with (core/recipes.gd). Found in
	# containers and lying around, sold by traders, or salvaged with the crowbar.
	"plywood": {"name": "Plywood", "color": Color(0.72, 0.6, 0.42), "size": Vector3(0.55, 0.03, 0.4)},
	"scrap_metal": {"name": "Scrap metal", "color": Color(0.5, 0.5, 0.52), "size": Vector3(0.3, 0.08, 0.2)},
}
# Order items appear in inventory lists.
const ITEM_ORDER := ["pistol", "crowbar", "pistol_ammo", "health_pack", "canned_food", "batteries", "planks", "used_planks", "barricade",
		"plywood", "scrap_metal", "scaffold", "guard_post", "fence", "fence_gate", "garden_plot", "ammo_bench"]


static func item_name(id: String) -> String:
	return ITEMS[id]["name"]


## What using this item does ("shoot", "melee", "heal", "eat", "board", "barricade"),
## or "" if it can't be held.
static func item_use(id: String) -> String:
	return ITEMS.get(id, {}).get("use", "")
