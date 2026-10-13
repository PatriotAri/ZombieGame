extends Node
## Stripping things for building materials, with the crowbar: hold interact on a
## wrecked car for scrap metal, or on furniture (dressers, kitchen cabinets,
## counters, shelves, beds) for plywood. Each thing can only be stripped once.
## It's loud work. player.gd does the holding; this knows what gives what.
## Saved: which things have been stripped (by their order in the town).

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

var _targets: Array[Node3D] = [] # everything that can be stripped, in town order
var _stripped := {} # target -> true


func _ready() -> void:
	add_to_group("salvage")


## loot_spots: main.gd's containers, in order; buildings: every Building.
func setup(loot_spots: Array, buildings: Array) -> void:
	for spot: Node3D in loot_spots:
		if YIELDS.has(spot.get("label")):
			_targets.append(spot)
	for b in buildings:
		var bed: Node3D = b.get("bed")
		if bed:
			_targets.append(bed)


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
	else: # a bed: just looks picked apart
		for mesh in thing.find_children("*", "MeshInstance3D", true, false):
			var mat := (mesh as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
			if mat:
				mat.albedo_color = mat.albedo_color.darkened(0.4)


func save_state() -> Array:
	var data := []
	for i in _targets.size():
		if _stripped.has(_targets[i]):
			data.append(i)
	return data


func load_state(data: Array) -> void:
	for i in data:
		if int(i) >= 0 and int(i) < _targets.size() and not _stripped.has(_targets[int(i)]):
			_mark(_targets[int(i)])
