extends GutTest
## Saving a game and loading it into a fresh one, on a small map made here: a
## house (that makes its own door and window) and a supply crate. Then the
## same save on the map changed: the crate renamed and moved, or the house's
## door moved along its wall.

const MainScene := preload("res://world/main.tscn")
const SupplyCrate := preload("res://world/kit/furniture/supply_crate.tscn")
const SaveGame := preload("res://core/save_game.gd")
const SaveIds := preload("res://core/save_ids.gd")
const TEMP := "user://test_saving.json" # (outside the saves folder: never in the list)

var _games: Array[Node] = []


func after_each() -> void:
	for game in _games:
		game.queue_free()
	_games.clear()
	DirAccess.remove_absolute(TEMP)


## The map: door_offset moves the house's door along its wall; shed puts the
## crate in a node of that name; crate_name renames it.
func _map(door_offset := -2.0, shed := "", crate_name := "Crate") -> PackedScene:
	var root := Node3D.new()
	root.name = "Map"
	var house := KitBuilding.new()
	house.name = "House"
	house.position = Vector3(20, 0, 0)
	var door := KitOpening.new()
	door.kind = "door"
	door.offset = door_offset
	door.bottom = 0.0
	door.top = 2.2
	var window := KitOpening.new()
	window.kind = "window"
	window.offset = 2.0
	house.openings = [door, window] as Array[KitOpening]
	root.add_child(house)
	house.owner = root
	house.set_meta(SaveIds.META, "house1")
	var parent: Node = root
	if shed != "":
		parent = Node3D.new()
		parent.name = shed
		root.add_child(parent)
		parent.owner = root
	var crate := SupplyCrate.instantiate()
	crate.name = crate_name
	crate.position = Vector3(10, 0, 5)
	parent.add_child(crate)
	crate.owner = root
	crate.set_meta(SaveIds.META, "crate1")
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _start(map: PackedScene) -> Node:
	var game := MainScene.instantiate()
	game.map_scene = map
	add_child(game)
	_games.append(game)
	return game


## Saves the game to a file, ends it, and reads the file back.
func _save_and_quit(game: Node) -> Dictionary:
	assert_true(game._save_game(TEMP), "saved")
	game.queue_free()
	_games.erase(game)
	await wait_process_frames(2)
	return SaveGame.read(TEMP)


func _door(game: Node) -> Node3D:
	for door: Node3D in game.map.doors:
		if str(door.get_meta(SaveIds.KEY, "")).begins_with("house1/"):
			return door
	return null


func _window_opening(game: Node) -> int:
	for i in game.fortifications.openings.size():
		if game.fortifications.openings[i]["kind"] == "window":
			return i
	return -1


## A game with things changed in it, saved and ended: the save.
func _played_and_saved(map: PackedScene) -> Dictionary:
	var game := _start(map)
	var crate: Node = game.map.loot_spots[0]
	crate.inventory.add("canned_food", 3)
	crate.open()
	_door(game).set_open(true, false)
	game.fortifications.board(_window_opening(game), true)
	game.day_night.day = 4
	game.player.give_item("pistol_ammo", 7)
	game.structures.build("fence", Transform3D(Basis.IDENTITY, Vector3(5, 0, -5)), null, true)
	return await _save_and_quit(game)


func test_the_save_finds_things_by_their_keys() -> void:
	var data: Dictionary = await _played_and_saved(_map())
	assert_eq(int(data.get("version")), SaveGame.VERSION)
	var things: Dictionary = data["things"]
	assert_true(things.has("crate1"), "the crate, by its ID")
	var door_keys := things.keys().filter(func(k: String) -> bool: return k.begins_with("house1/"))
	assert_eq(door_keys.size(), 1, "the house's door, by the house and its place in it")
	assert_true(things[door_keys[0]].has("at"), "made by the house: saved with where it was")
	assert_false(things["crate1"].has("at"), "placed on the map: found wherever it is")


func test_everything_comes_back() -> void:
	var data: Dictionary = await _played_and_saved(_map())
	var game := _start(_map())
	var ammo_before_load: int = game.player.inventory.count("pistol_ammo")
	var crate: Node = game.map.loot_spots[0]
	var food_before_load: int = crate.inventory.count("canned_food") # what a new game's crate has
	game._apply_save(data)
	assert_true(crate.opened)
	assert_eq(crate.inventory.count("canned_food"), food_before_load + 3)
	assert_true(_door(game).is_open)
	assert_true(game.fortifications.is_boarded(_window_opening(game)))
	assert_eq(game.day_night.day, 4)
	assert_eq(game.structures.pieces.size(), 1)
	assert_eq(game.player.inventory.count("pistol_ammo"), ammo_before_load + 7)


func test_a_renamed_and_moved_crate_keeps_its_state() -> void:
	var data: Dictionary = await _played_and_saved(_map())
	var game := _start(_map(-2.0, "Shed", "MovedCrate"))
	var crate: Node = game.map.loot_spots[0]
	var food_before_load: int = crate.inventory.count("canned_food")
	game._apply_save(data)
	assert_eq(str(crate.name), "MovedCrate")
	assert_true(crate.opened)
	assert_eq(crate.inventory.count("canned_food"), food_before_load + 3)


func test_a_door_moved_along_its_wall_starts_fresh_and_the_rest_comes_back() -> void:
	var data: Dictionary = await _played_and_saved(_map())
	var game := _start(_map(0.5))
	game._apply_save(data)
	assert_false(_door(game).is_open, "not where it was saved: its state is dropped")
	assert_true(game.fortifications.is_boarded(_window_opening(game)), "the window didn't move")
	assert_true(game.map.loot_spots[0].opened)
