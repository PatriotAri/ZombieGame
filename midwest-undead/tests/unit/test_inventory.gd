extends GutTest
## A sample test: items/inventory.gd, the bag of item counts the player and
## every container own. Copy this file to start a new one (see HOW_TO_TEST.md).

const Inventory := preload("res://items/inventory.gd")


func test_remove_takes_only_what_there_is() -> void:
	var bag := Inventory.new()
	bag.add("pistol_ammo", 5)
	assert_eq(bag.remove("pistol_ammo", 8), 5, "only 5 to take")
	assert_false(bag.has("pistol_ammo"), "nothing left")
	assert_true(bag.is_empty())


func test_save_round_trip_skips_unknown_items() -> void:
	var bag := Inventory.new()
	bag.add("canned_food", 2)
	var saved := bag.to_dict()
	saved["no_such_item"] = 3 # an item removed from the game since the save
	var loaded := Inventory.new()
	loaded.from_dict(saved)
	assert_eq(loaded.count("canned_food"), 2)
	assert_false(loaded.has("no_such_item"))
