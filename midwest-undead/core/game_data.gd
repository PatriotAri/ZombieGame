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
}
# Order items appear in inventory lists.
const ITEM_ORDER := ["pistol", "crowbar", "pistol_ammo", "health_pack", "canned_food", "batteries"]


static func item_name(id: String) -> String:
	return ITEMS[id]["name"]


## What using this item does ("shoot", "melee", "heal", "eat"), or "" if it can't be held.
static func item_use(id: String) -> String:
	return ITEMS.get(id, {}).get("use", "")
