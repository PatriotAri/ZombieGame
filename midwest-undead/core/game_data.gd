extends RefCounted
## Shared by several scripts: physics layers, and looking up items (the files in
## items/data/). Never instanced; other scripts preload it.

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
## compound gate (CompoundFence/GateNavBlocker in world/town/districts/police_station.tscn).
const LAYER_NAV_ONLY := 128

# --- Items -----------------------------------------------------------------------
# Every file in items/data/ is an item (ItemData, or WeaponData for guns and
# melee weapons). They're read the first time anything asks.

const ITEMS_DIR := "res://items/data/"

static var _items := {} # id -> ItemData
static var _order: Array[String] = [] # every id, in inventory order


static func _load_items() -> void:
	if not _items.is_empty():
		return
	var found: Array[ItemData] = []
	for file in DirAccess.get_files_at(ITEMS_DIR):
		file = file.trim_suffix(".remap") # exported games list "x.tres.remap"
		if not file.ends_with(".tres"):
			continue
		var item := load(ITEMS_DIR + file) as ItemData
		if item == null or item.id == "":
			push_warning("%s isn't an item with an id: skipped." % (ITEMS_DIR + file))
			continue
		if _items.has(item.id):
			push_warning("Two items have the id \"%s\": %s is skipped." % [item.id, ITEMS_DIR + file])
			continue
		_items[item.id] = item
		found.append(item)
	found.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.order < b.order if a.order != b.order else a.id < b.id)
	for item in found:
		_order.append(item.id)


static func has_item(id: String) -> bool:
	_load_items()
	return _items.has(id)


## The item, or null if there's no such item.
static func item(id: String) -> ItemData:
	_load_items()
	return _items.get(id)


## A gun or melee weapon, or null if it isn't one.
static func weapon(id: String) -> WeaponData:
	return item(id) as WeaponData


## Every item id, in inventory order.
static func item_ids() -> Array[String]:
	_load_items()
	return _order


static func item_name(id: String) -> String:
	var it := item(id)
	return it.display_name if it else id


## What using this item does ("shoot", "melee", "heal", "eat", "board",
## "barricade", "build"), or "" if it can't be held.
static func item_use(id: String) -> String:
	var it := item(id)
	return it.use_kind() if it else ""
