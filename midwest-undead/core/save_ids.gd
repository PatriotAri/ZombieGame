extends RefCounted
## How a save finds things on the map again (containers, doors, windows,
## mines, spawn points...): by an id each keeps (in its metadata, "save_id"),
## so renaming one or moving it to another node in the editor doesn't lose
## what a save says about it. What a building or kit piece makes from its
## settings (its doors and windows) goes by the building's id plus its own
## name. Anything without an id goes by its path in the map, as before.
##
## Map Tools gives ids out whenever the map scene is saved in the editor
## (assign()), new ones to copies too. Never instanced.

const META := &"save_id"
const LootSpot := preload("res://items/loot_spot.gd")
const Door := preload("res://world/door.gd")
const WindowPane := preload("res://world/window_pane.gd")
const SpawnPoint := preload("res://world/markers/spawn_point.gd")


## Gives an id to everything in root's scene that a save might need, and a
## new one to any that shares one (a copy). Returns how many it gave out.
static func assign(root: Node) -> int:
	var seen := {}
	var given := 0
	for node in root.find_children("*", "", true, false):
		if node.owner != root or not _needs_id(node):
			continue
		var id := str(node.get_meta(META, ""))
		if id == "" or seen.has(id):
			id = _new_id(seen)
			node.set_meta(META, id)
			given += 1
		seen[id] = true
	return given


## The key a save keeps for node (a thing in the map scene town): "#id", or
## "#id/Name/..." under the nearest thing with an id, or its path from town.
static func key(node: Node, town: Node) -> String:
	var parts := PackedStringArray()
	var at := node
	while at != null and at != town:
		if at.has_meta(META):
			parts.insert(0, "#" + str(at.get_meta(META)))
			return "/".join(parts)
		parts.insert(0, str(at.name))
		at = at.get_parent()
	return "/".join(parts)


static func _needs_id(node: Node) -> bool:
	return node is LootSpot or node is Door or node is WindowPane or node is SpawnPoint or node is KitMine \
			or node.has_meta("salvage_label") or node.has_method("ensure_built")


static func _new_id(taken: Dictionary) -> String:
	var id := ""
	while id == "" or taken.has(id):
		id = "%08x" % (randi() & 0x7fffffff)
	return id
