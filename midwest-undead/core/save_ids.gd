extends RefCounted
## How a save finds things on the map again. Never instanced.
##
## Everything on the map whose state is saved (a container, a door, a window,
## a spawn point, a mine, salvageable furniture) carries a short random ID,
## its "save_id" (node metadata). The Map Tools plugin gives one to anything
## that needs it each time a scene is saved in the editor (assign()); renaming
## or moving the thing keeps it. Ctrl+D copies it, so a copy gets a new one the
## next time the scene is saved.
##
## What a save file uses is the thing's key (key_of()): its ID, after the IDs
## of the scenes it sits in. A container in a house scene placed twice on the
## map is "<this house>/<the container>" in each, so they stay apart.
##
## Doors and windows a building makes from its settings aren't in any scene,
## so they have no ID of their own: their key is the building's, plus where
## they are under it ("<the building>/Door3"). Change the building's openings
## and that can name a different door, so their saved state also records
## where they were, and is only put back on one still within POSITION_SLACK
## of it (still_there()).

const META := &"save_id"
## Where a thing's key is kept once the game has loaded the map
## (world/game_map.gd), and whether it was made in the game (is_made_in_game():
## the map moves doors out of the map scene, which makes them look it).
const KEY := &"save_key"
const MADE_IN_GAME := &"save_made_in_game"
const POSITION_SLACK := 0.5 # meters

const LootSpot := preload("res://items/loot_spot.gd")
const Door := preload("res://world/door.gd")
const WindowPane := preload("res://world/window_pane.gd")
const SpawnPoint := preload("res://world/markers/spawn_point.gd")

const ID_LENGTH := 6
const ID_LETTERS := "abcdefghjkmnpqrstuvwxyz23456789" # no 0/o, 1/l/i to mix up


## Whether node's state is saved by its key.
static func is_saveable(node: Node) -> bool:
	return node is LootSpot or node is Door or node is WindowPane or node is SpawnPoint \
			or node is KitMine or node.has_meta("salvage_label")


## Gives an ID to everything in the scene under root that needs one and has
## none, or shares one with something earlier in the scene (a Ctrl+D copy).
## Returns how many it gave. Called on every scene the editor saves.
static func assign(root: Node) -> int:
	var nodes := root.find_children("*", "", true, false)
	# What needs one: everything saveable that's saved in this scene file, and
	# what holds saveable things that aren't (a scene placed here, or a
	# building's doors and windows): their keys go through its ID.
	var needing := {}
	for node in nodes:
		if is_saveable(node):
			var holder := node
			while holder != root and holder.owner != root:
				holder = holder.get_parent()
			if holder != root:
				needing[holder] = true
	var taken := {}
	var given := 0
	for node in nodes:
		if not needing.has(node):
			continue
		var id := str(node.get_meta(META, ""))
		if id == "" or taken.has(id):
			id = new_id(taken)
			node.set_meta(META, id)
			given += 1
		taken[id] = true
	return given


## A fresh ID that isn't in taken.
static func new_id(taken: Dictionary) -> String:
	while true:
		var id := ""
		for i in ID_LENGTH:
			id += ID_LETTERS[randi() % ID_LETTERS.length()]
		if not taken.has(id):
			return id
	return ""


## What a save file calls node, top being the map's root: "" if it can't be
## told apart (no ID: the scene it's in hasn't been saved in the editor since).
static func key_of(node: Node, top: Node) -> String:
	if node == top:
		return ""
	if node.owner == null: # made in the game (a building's doors and windows)
		var anchor := node.get_parent()
		while anchor != null and anchor != top and anchor.owner == null:
			anchor = anchor.get_parent()
		if anchor == null or anchor == top:
			return ""
		var anchor_key := key_of(anchor, top)
		return "" if anchor_key == "" else anchor_key + "/" + str(anchor.get_path_to(node))
	var key := str(node.get_meta(META, ""))
	if key == "":
		return ""
	var scene := node.owner
	while scene != null and scene != top:
		var id := str(scene.get_meta(META, ""))
		if id == "":
			return ""
		key = id + "/" + key
		scene = scene.owner
	return key


## Whether node's key could name a different one of its building's doors or
## windows after the building's openings change (see the top of this file).
static func is_made_in_game(node: Node) -> bool:
	return bool(node.get_meta(MADE_IN_GAME, node.owner == null))


## Where node is for still_there(): a door where it is when shut (an open
## one has swung or slid away).
static func where(node: Node3D) -> Vector3:
	return (node as Door).closed_transform().origin if node is Door else node.global_position


## For a door or window made in the game: whether it's where its saved state
## says it was (saved_at: where() then, as [x, y, z]). Anything else is always
## still there.
static func still_there(node: Node3D, saved_at: Variant) -> bool:
	if not is_made_in_game(node):
		return true
	if not saved_at is Array or (saved_at as Array).size() != 3:
		return false
	var at := Vector3(float(saved_at[0]), float(saved_at[1]), float(saved_at[2]))
	return where(node).distance_to(at) <= POSITION_SLACK
