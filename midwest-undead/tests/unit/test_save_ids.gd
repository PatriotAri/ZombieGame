extends GutTest
## core/save_ids.gd: who gets a save ID, and the keys saves find things by.

const SaveIds := preload("res://core/save_ids.gd")
const SupplyCrate := preload("res://world/kit/furniture/supply_crate.tscn")
const Door := preload("res://world/door.gd")


## A node saved in root's scene, under parent (root if null).
func _own(node: Node, root: Node, parent: Node = null) -> Node:
	(parent if parent else root).add_child(node)
	node.owner = root
	return node


func test_saveable_things_get_an_id_and_keep_it() -> void:
	var root: Node3D = autofree(Node3D.new())
	var crate := _own(SupplyCrate.instantiate(), root)
	var plain := _own(Node3D.new(), root)
	assert_eq(SaveIds.assign(root), 1)
	var id := str(crate.get_meta(SaveIds.META, ""))
	assert_eq(id.length(), SaveIds.ID_LENGTH)
	assert_false(plain.has_meta(SaveIds.META), "nothing saved in it")
	assert_eq(SaveIds.assign(root), 0, "already has one")
	assert_eq(crate.get_meta(SaveIds.META), id)


func test_a_copy_with_the_same_id_gets_a_new_one() -> void:
	var root: Node3D = autofree(Node3D.new())
	var first := _own(SupplyCrate.instantiate(), root)
	var copy := _own(SupplyCrate.instantiate(), root)
	first.set_meta(SaveIds.META, "aaaaaa")
	copy.set_meta(SaveIds.META, "aaaaaa") # what Ctrl+D does
	assert_eq(SaveIds.assign(root), 1)
	assert_eq(first.get_meta(SaveIds.META), "aaaaaa", "the first keeps it")
	assert_ne(copy.get_meta(SaveIds.META), "aaaaaa")


func test_moving_or_renaming_keeps_the_key() -> void:
	var root: Node3D = autofree(Node3D.new())
	var crate := _own(SupplyCrate.instantiate(), root)
	SaveIds.assign(root)
	var key := SaveIds.key_of(crate, root)
	var shed := _own(Node3D.new(), root)
	crate.owner = null # moved, as the editor does it: still saved in root's scene
	root.remove_child(crate)
	shed.add_child(crate)
	crate.owner = root
	crate.name = "MovedCrate"
	assert_eq(SaveIds.key_of(crate, root), key)


func test_the_same_scene_placed_twice_gives_two_keys() -> void:
	var house := Node3D.new()
	var inside := _own(SupplyCrate.instantiate(), house)
	SaveIds.assign(house)
	var inside_id := str(inside.get_meta(SaveIds.META))
	var house_scene := PackedScene.new()
	house_scene.pack(house)
	house.free()
	var root: Node3D = autofree(Node3D.new())
	var one := _own(house_scene.instantiate(), root)
	var two := _own(house_scene.instantiate(), root)
	assert_eq(SaveIds.assign(root), 2, "each house, for what's inside it")
	var key_one := SaveIds.key_of(one.get_child(0), root)
	var key_two := SaveIds.key_of(two.get_child(0), root)
	assert_ne(key_one, key_two)
	assert_eq(key_one, "%s/%s" % [one.get_meta(SaveIds.META), inside_id])


func test_a_door_made_in_the_game_goes_by_its_building_and_place() -> void:
	var root: Node3D = autofree(Node3D.new())
	var building := _own(Node3D.new(), root)
	var door := Door.new()
	door.name = "Door2"
	building.add_child(door) # not saved in the scene: made from the building's settings
	assert_eq(SaveIds.assign(root), 1, "the building, for its door")
	assert_eq(SaveIds.key_of(door, root), "%s/Door2" % building.get_meta(SaveIds.META))
	assert_true(SaveIds.is_made_in_game(door))


func test_no_id_no_key() -> void:
	var root: Node3D = autofree(Node3D.new())
	var crate := _own(SupplyCrate.instantiate(), root)
	assert_eq(SaveIds.key_of(crate, root), "")


func test_a_door_made_in_the_game_is_only_still_there_close_to_where_it_was() -> void:
	var root: Node3D = autofree(Node3D.new())
	add_child(root)
	var door: Node3D = Door.new()
	door.position = Vector3(10, 0, 5) # (before it's ready: that's where it's shut)
	root.add_child(door)
	assert_true(SaveIds.still_there(door, [10.2, 0.0, 5.0]))
	assert_false(SaveIds.still_there(door, [12.0, 0.0, 5.0]))
	assert_false(SaveIds.still_there(door, null), "saved without a place")
