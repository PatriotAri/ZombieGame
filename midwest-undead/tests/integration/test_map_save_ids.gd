extends GutTest
## The game's own map: everything a save has to find again has a key, and no
## two share one (core/save_ids.gd). If this fails, open the scene it names in
## the editor and save it: that gives out the missing or duplicated IDs.

const MainScene := preload("res://world/main.tscn")
const SaveIds := preload("res://core/save_ids.gd")


func test_every_saveable_thing_on_the_map_has_its_own_key() -> void:
	var game := MainScene.instantiate()
	var map: Node = game.map_scene.instantiate()
	game.free()
	for node in map.find_children("*", "", true, false): # the doors and windows buildings make
		if node.has_method("ensure_built"):
			node.call("ensure_built")
	var seen := {}
	for node in map.find_children("*", "", true, false):
		if not SaveIds.is_saveable(node):
			continue
		var key := SaveIds.key_of(node, map)
		var where := str(map.get_path_to(node))
		assert_ne(key, "", "%s has no save ID" % where)
		if key != "":
			assert_false(seen.has(key), "%s and %s share the key \"%s\"" % [seen.get(key), where, key])
			seen[key] = where
	map.free()
