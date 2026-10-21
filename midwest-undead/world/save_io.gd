extends RefCounted
## Saving and loading the game (main.gd's _save_game and _apply_save use it):
## the state of every Saveable in the game (components/saveable.gd), gathered
## into a Dictionary for core/save_game.gd, and put back on a freshly loaded
## game. What each saves is up to it; this only collects and hands out.
## Never instanced.
##
## A save holds {"sections": {name: state}, "things": {key: {"state": ...,
## "at": where it was, for doors and windows a building made}}}, plus what
## main.gd and save_game.gd add (the clock, the objective, the version...).

const SaveGame := preload("res://core/save_game.gd")
const SaveIds := preload("res://core/save_ids.gd")


## Everything to save, from the game under root (main.gd).
static func collect(root: Node) -> Dictionary:
	var sections := {}
	var things := {}
	for it in _all(root):
		var state: Variant = it.save_state.call()
		if not it.is_thing:
			if sections.has(it.key):
				push_error("Two Saveables are both saving the \"%s\" section." % it.key)
			sections[it.key] = state
			continue
		var entry := {"state": state}
		var host := it.get_parent() as Node3D
		if SaveIds.is_made_in_game(host):
			entry["at"] = SaveGame.vec_to_array(SaveIds.where(host))
		things[it.key] = entry
	return {"sections": sections, "things": things}


## Puts a save on top of the freshly loaded game under root, in load order
## (Saveable's constants). A thing whose saved state is missing, or that's no
## longer where it was saved (core/save_ids.gd), keeps its fresh state.
static func apply(root: Node, data: Dictionary) -> void:
	var sections: Dictionary = data.get("sections", {})
	var things: Dictionary = data.get("things", {})
	var steps := [] # [order, tie-break, what to run]
	for it in _all(root):
		if it.is_thing:
			var entry: Dictionary = things.get(it.key, {})
			if entry.has("state") and SaveIds.still_there(it.get_parent() as Node3D, entry.get("at")):
				steps.append([it.order, steps.size(), it.load_state.bind(entry["state"])])
		elif sections.has(it.key):
			steps.append([it.order, steps.size(), it.load_state.bind(sections[it.key])])
		if it.finish.is_valid():
			steps.append([it.finish_order, steps.size(), it.finish])
	steps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for step: Array in steps:
		(step[2] as Callable).call()


static func _all(root: Node) -> Array[Saveable]:
	var found: Array[Saveable] = []
	for node in root.get_tree().get_nodes_in_group(Saveable.GROUP):
		var it := node as Saveable
		if it and not it.get_parent().is_queued_for_deletion() and root.is_ancestor_of(it):
			found.append(it)
	return found
