extends SceneTree
## Doors: a building's door sits in its doorway (the hinge on the wall), one
## that starts open stands open, and a save remembers it shut (in place) after
## a load. Saves go by save ids (core/save_ids.gd): a door broken, saved, its
## building renamed on the map, loaded: still broken. On a test map with one
## shop (tests/support/test_map.gd).
const SaveGame := preload("res://core/save_game.gd")
const Door := preload("res://world/door.gd")
const TestMap := preload("res://tests/support/test_map.gd")

var main: Node
var test_map: PackedScene
var f := 0
var fails := 0
var door_id := ""


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	preload("res://tests/support/test_saves.gd").use() # never your own saves
	var map := TestMap.begin()
	var shop := TestMap.building(map, "Shop", Vector3(40, 0, 40))
	for op in shop.openings:
		if op and op.kind == "door":
			op.start_open = true
	test_map = TestMap.finish(map)
	_start()


func _start() -> void:
	main = load("res://world/main.tscn").instantiate()
	main.map_scene = test_map
	root.add_child(main)


func shop_door() -> Door:
	return main.doors.filter(func(d: Node) -> bool: return String(d.get_meta("town_id")).begins_with(TestMap.under(main, "Buildings/Shop")))[0]


func _physics_process(_d: float) -> bool:
	f += 1
	match f:
		5:
			for z in main.zombies: z.set_physics_process(false); z.global_position = Vector3(-900, 0, 900)
			var door := shop_door()
			check(door.is_open, "a door set to start open stands open")
			var shop: Node3D = main.town.get_node("Buildings/Shop")
			var local: Vector3 = shop.global_transform.affine_inverse() * door.closed_transform().origin
			check(absf(local.x - 0.1) < 0.01 and absf(local.z - (TestMap.front_door_z(shop) - 0.8)) < 0.01,
					"the shop door's hinge is in its doorway (%s)" % local)
			door.set_open(false, false)
			door_id = door.get_meta("town_id")
			main.save_game(SaveGame.new_path())
			SaveGame.pending_load = SaveGame.read(SaveGame.latest())
			root.remove_child(main) # like a scene change: the old game is gone first
			main.free()
			_start()
		30:
			var door: Door = main.doors.filter(func(d: Node) -> bool: return d.get_meta("town_id") == door_id)[0]
			var closed := door.closed_transform()
			check(not door.is_open and door.global_transform.origin.distance_to(closed.origin) < 0.01 \
					and door.global_basis.x.dot(closed.basis.x) > 0.999, "loaded: the start-open door is shut, in place")
			check(door_id.begins_with("#"), "it went by its building's save id (%s)" % door_id)
			door.bash(9999.0)
			check(door.is_broken, "broken")
			main.save_game(SaveGame.new_path())
			# The building renamed on the map (its save id kept, as in the editor), then the save loaded.
			var renamed: Node = test_map.instantiate()
			renamed.get_node("Buildings/Shop").name = "GeneralStore"
			test_map = PackedScene.new()
			test_map.pack(renamed)
			renamed.free()
			SaveGame.pending_load = SaveGame.read(SaveGame.latest())
			root.remove_child(main)
			main.free()
			_start()
		55:
			var door: Door = main.doors.filter(func(d: Node) -> bool:
					return String(d.get_meta("town_id")).begins_with(TestMap.under(main, "Buildings/GeneralStore")))[0]
			check(door.is_broken, "the building renamed on the map: its door still broken after the load (%s)" % door.get_meta("town_id"))
			print("FAILS: %d" % fails)
			return true
	return false
