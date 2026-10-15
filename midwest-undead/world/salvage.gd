extends Node
## Stripping things for building materials, with the crowbar: hold interact on a
## wrecked car for scrap metal, or on furniture (dressers, kitchen cabinets,
## counters, shelves, beds) for plywood. Each thing can only be stripped once.
## It's loud work. player.gd does the holding; this knows what gives what.
## Saved: which things have been stripped (by their place in the map scene, the
## "town_id" main.gd gives them).

const YIELDS := {
	"Car": ["scrap_metal", 3],
	"Dresser": ["plywood", 2],
	"Kitchen cabinet": ["plywood", 2],
	"Counter": ["plywood", 2],
	"Shelf": ["plywood", 2],
	"Grocery shelf": ["plywood", 2],
	"Bed": ["plywood", 1],
}
const TIME := 2.5 # seconds of holding interact
const NOISE := 18.0 # meters: tearing a car apart carries

var _targets: Array[Node3D] = [] # everything that can be stripped
var _stripped := {} # target -> true


func _ready() -> void:
	add_to_group("salvage")


## loot_spots: the map's containers; others: anything else on the map that has
## a "salvage_label" (a bed, so far): set it in the Inspector's Metadata section.
func setup(loot_spots: Array, others: Array) -> void:
	for spot: Node3D in loot_spots:
		if YIELDS.has(spot.get("label")):
			_targets.append(spot)
	for thing: Node3D in others:
		if YIELDS.has(_label(thing)):
			_targets.append(thing)


func _label(thing: Node3D) -> String:
	return thing.get_meta("salvage_label") if thing.has_meta("salvage_label") else str(thing.get("label"))


## [item, amount] you'd get from it, or [] if it can't be (or has been) stripped.
func yield_of(thing: Object) -> Array:
	var node := thing as Node3D
	if node == null or not node in _targets or _stripped.has(node):
		return []
	return YIELDS.get(_label(node), [])


## Strips it. Returns [item, amount].
func strip(thing: Node3D) -> Array:
	var got := yield_of(thing)
	if got.is_empty():
		return []
	_mark(thing)
	return got


func _mark(thing: Node3D) -> void:
	_stripped[thing] = true
	if thing.get("salvaged") != null:
		thing.set("salvaged", true)
		thing.set("label", str(thing.get("label")) + " (stripped)")
	elif thing.has_method("darken"): # a bed: just looks picked apart
		thing.call("darken", 0.4)


func save_state() -> Array:
	var data := []
	for thing in _targets:
		if _stripped.has(thing):
			data.append(str(thing.get_meta("town_id", "")))
	return data


func load_state(data: Array) -> void:
	for thing in _targets:
		if str(thing.get_meta("town_id", "")) in data and not _stripped.has(thing):
			_mark(thing)
